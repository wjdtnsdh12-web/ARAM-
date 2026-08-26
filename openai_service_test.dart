import 'dart:convert';

import 'package:aram_ai_analyzer/models.dart';
import 'package:aram_ai_analyzer/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends a Responses API request and parses structured output', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': jsonEncode({
                    'summary': '좋은 경기였어.',
                    'facts': ['딜 비중이 높아.'],
                    'inferences': ['후방 딜링이 안정적이었을 가능성이 있어.'],
                    'strengths': ['높은 피해 기여'],
                    'improvements': ['데스 관리'],
                    'nextActions': ['교전 전 사거리 확인'],
                    'confidence': '보통',
                  }),
                },
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final feedback = await OpenAiClient(
      'sk-test-key',
      model: 'gpt-5.6-luna',
      client: client,
    ).analyze(_analysis());

    expect(captured.url.toString(), 'https://api.openai.com/v1/responses');
    expect(captured.headers['Authorization'], 'Bearer sk-test-key');
    final requestBody = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(requestBody['model'], 'gpt-5.6-luna');
    expect(requestBody['store'], isFalse);
    expect(
      ((requestBody['text'] as Map)['format'] as Map)['type'],
      'json_schema',
    );
    expect(feedback.summary, '좋은 경기였어.');
    expect(feedback.nextActions, ['교전 전 사거리 확인']);
  });
}

MatchAnalysis _analysis() => const MatchAnalysis(
      matchId: 'KR_1',
      durationSeconds: 1200,
      gameCreation: 0,
      selectedPuuid: 'me',
      players: [
        PlayerMetrics(
          puuid: 'me',
          riotId: 'Soon Oh#KR1',
          champion: 'Caitlyn',
          teamId: 100,
          win: true,
          kills: 10,
          deaths: 5,
          assists: 20,
          damage: 30000,
          damageTaken: 10000,
          gold: 12000,
          healing: 500,
          shielding: 0,
          ccTime: 10,
          kda: 6,
          killParticipation: 75,
          damageShare: 30,
          damagePerMinute: 1500,
          damageTakenPerMinute: 500,
          damagePerGold: 2.5,
        ),
      ],
    );
