import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SecretStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<String> read(String key) async => await _storage.read(key: key) ?? '';
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class AppCache {
  Future<AiFeedback?> readFeedback(String matchId, String puuid) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('openai:$matchId:$puuid');
    if (value == null) return null;
    try {
      return AiFeedback.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> writeFeedback(
    String matchId,
    String puuid,
    AiFeedback feedback,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'openai:$matchId:$puuid',
      jsonEncode(feedback.toJson()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key.startsWith('ai:') || key.startsWith('openai:')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

class RiotApiClient {
  RiotApiClient(this.apiKey, {http.Client? client}) : client = client ?? http.Client();
  final String apiKey;
  final http.Client client;
  static const _base = 'https://asia.api.riotgames.com';

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    if (apiKey.trim().isEmpty) throw const ApiException('설정에서 Riot API 키를 입력해줘.');
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    var response = await client.get(uri, headers: {
      'X-Riot-Token': apiKey.trim(),
      'User-Agent': 'ARAM-AI-Analyzer-Android/0.1',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode == 429) {
      await Future<void>.delayed(const Duration(seconds: 2));
      response = await client.get(uri, headers: {'X-Riot-Token': apiKey.trim()});
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      const errors = {
        401: 'Riot API 키가 잘못됐어.',
        403: 'Riot API 키가 만료됐어. 개발자 포털에서 갱신해줘.',
        404: 'Riot ID나 경기 기록을 찾지 못했어.',
        429: 'API 호출 제한에 걸렸어. 잠시 뒤 다시 시도해줘.',
      };
      throw ApiException(errors[response.statusCode] ?? 'Riot API 오류 (${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<Map<String, dynamic>> account(String gameName, String tagLine) async =>
      Map<String, dynamic>.from(await _get(
        '/riot/account/v1/accounts/by-riot-id/${Uri.encodeComponent(gameName.trim())}/${Uri.encodeComponent(tagLine.trim())}',
      ) as Map);

  Future<List<String>> aramMatchIds(String puuid, int count) async =>
      (await _get('/lol/match/v5/matches/by-puuid/${Uri.encodeComponent(puuid)}/ids', {
        'queue': '450', 'start': '0', 'count': count.clamp(1, 20).toString(),
      }) as List).map((value) => value.toString()).toList(growable: false);

  Future<Map<String, dynamic>> match(String id) async =>
      Map<String, dynamic>.from(await _get('/lol/match/v5/matches/${Uri.encodeComponent(id)}') as Map);
}

class OpenAiClient {
  OpenAiClient(this.apiKey, {this.model = 'gpt-5.6-luna', http.Client? client})
      : client = client ?? http.Client();
  final String apiKey;
  final String model;
  final http.Client client;

  Future<AiFeedback> analyze(MatchAnalysis analysis) async {
    if (apiKey.trim().isEmpty) {
      throw const ApiException('설정에서 OpenAI API 키를 입력해줘.');
    }
    final player = analysis.selectedPlayer;
    final data = {
      'matchId': analysis.matchId,
      'durationMinutes': analysis.durationSeconds / 60,
      'selectedPlayer': player.toAiJson(),
      'allPlayers': analysis.players.map((p) => p.toAiJson()).toList(),
    };
    final schema = {
      'type': 'object',
      'properties': {
        for (final key in ['summary', 'confidence']) key: {'type': 'string'},
        for (final key in ['facts', 'inferences', 'strengths', 'improvements', 'nextActions'])
          key: {'type': 'array', 'items': {'type': 'string'}},
      },
      'required': ['summary', 'facts', 'inferences', 'strengths', 'improvements', 'nextActions', 'confidence'],
      'additionalProperties': false,
    };
    final uri = Uri.parse('https://api.openai.com/v1/responses');
    final response = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode({
        'model': model,
        'instructions': _prompt,
        'input': jsonEncode(data),
        'store': false,
        'reasoning': {'effort': 'none'},
        'max_output_tokens': 1800,
        'text': {
          'format': {
            'type': 'json_schema',
            'name': 'aram_match_feedback',
            'strict': true,
            'schema': schema,
          },
        },
      }),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw const ApiException('OpenAI API 키가 잘못됐거나 폐기됐어.');
      }
      if (response.statusCode == 403) {
        throw const ApiException('이 OpenAI 프로젝트에서 모델을 사용할 권한이 없어.');
      }
      if (response.statusCode == 429) {
        throw const ApiException('OpenAI 사용량·결제 한도에 걸렸어. Platform의 Billing과 Limits를 확인해줘.');
      }
      if (response.statusCode == 404) {
        throw ApiException('OpenAI 모델을 찾지 못했어. 모델 설정을 확인해줘. ($model)');
      }
      final detail = _errorMessage(response.body);
      throw ApiException('OpenAI API 오류 (${response.statusCode})${detail.isEmpty ? '' : ': $detail'}');
    }
    try {
      final root = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (root['status'] != 'completed') {
        throw const FormatException('응답 생성이 완료되지 않았어.');
      }
      final output = root['output'] as List;
      for (final itemValue in output) {
        final item = Map<String, dynamic>.from(itemValue as Map);
        if (item['type'] != 'message') continue;
        final content = item['content'] as List? ?? const [];
        for (final partValue in content) {
          final part = Map<String, dynamic>.from(partValue as Map);
          if (part['type'] == 'refusal') {
            throw ApiException('OpenAI가 이 분석 요청을 거절했어.');
          }
          if (part['type'] == 'output_text') {
            final text = part['text']?.toString() ?? '';
            return AiFeedback.fromJson(
              jsonDecode(text) as Map<String, dynamic>,
            );
          }
        }
      }
      throw const FormatException('출력 텍스트가 없어.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('OpenAI 분석 응답을 읽지 못했어.');
    }
  }

  static String _errorMessage(String body) {
    try {
      final root = jsonDecode(body) as Map<String, dynamic>;
      final error = root['error'];
      if (error is Map && error['message'] != null) {
        final message = error['message'].toString();
        return message.length > 180 ? '${message.substring(0, 180)}…' : message;
      }
    } catch (_) {
      // Fall through to an empty public error detail.
    }
    return '';
  }

  static const _prompt = '''너는 리그 오브 레전드 칼바람 나락 경기 분석 코치다.
제공된 통계만 사용하고 실제 경기 장면을 봤다고 주장하지 마라.
확인된 사실과 통계 기반 추론을 분리하라. KDA 하나만으로 판단하지 말고
딜 비중, 킬 관여율, 피해 흡수, 회복, 보호막, CC를 함께 고려하라.
다음 경기에서 바로 실행할 수 있는 조언을 지정된 한국어 JSON 형식으로 반환하라.''';
}
