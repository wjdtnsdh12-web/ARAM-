import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'metrics.dart';
import 'models.dart';
import 'services.dart';

void main() => runApp(const AramApp());

class AramApp extends StatelessWidget {
  const AramApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ARAM AI Analyzer',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff6c7cff),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xff0d1017),
          cardTheme: const CardThemeData(
            color: Color(0xff171b25),
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _secrets = SecretStore();
  final _cache = AppCache();
  final _name = TextEditingController();
  final _tag = TextEditingController(text: 'KR1');
  String _riotKey = '';
  String _openAiKey = '';
  String _model = 'gpt-5.6-luna';
  bool _loading = false;
  List<MatchAnalysis> _matches = const [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final riot = await _secrets.read('riot_api_key');
    final openAi = await _secrets.read('openai_api_key');
    final model = await _secrets.read('openai_model');
    if (!mounted) return;
    setState(() {
      _riotKey = riot;
      _openAiKey = openAi;
      if (model.isNotEmpty) _model = model;
    });
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _search() async {
    if (_name.text.trim().isEmpty || _tag.text.trim().isEmpty) {
      _error('Riot ID와 태그를 입력해줘.');
      return;
    }
    setState(() => _loading = true);
    try {
      final client = RiotApiClient(_riotKey);
      final account = await client.account(_name.text, _tag.text);
      final puuid = account['puuid'].toString();
      final ids = await client.aramMatchIds(puuid, 10);
      final matches = <MatchAnalysis>[];
      for (final id in ids) {
        matches.add(calculateMatchMetrics(await client.match(id), puuid));
      }
      if (mounted) setState(() => _matches = matches);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<_SettingsResult>(
      MaterialPageRoute(builder: (_) => SettingsScreen(
        riotKey: _riotKey, openAiKey: _openAiKey, model: _model, cache: _cache,
      )),
    );
    if (result != null && mounted) {
      setState(() {
        _riotKey = result.riotKey;
        _openAiKey = result.openAiKey;
        _model = result.model;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚔ ARAM AI Analyzer', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('칼바람 통계와 AI 코칭', style: TextStyle(fontSize: 12, color: Colors.white60)),
          ]),
          actions: [IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings))],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(children: [
              Expanded(child: TextField(controller: _name, decoration: const InputDecoration(
                labelText: 'Riot ID', border: OutlineInputBorder(), isDense: true,
              ))),
              const SizedBox(width: 8),
              SizedBox(width: 90, child: TextField(controller: _tag, decoration: const InputDecoration(
                labelText: '태그', prefixText: '#', border: OutlineInputBorder(), isDense: true,
              ))),
              const SizedBox(width: 8),
              FilledButton(onPressed: _loading ? null : _search, child: const Icon(Icons.search)),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _matches.isEmpty
              ? _EmptyState(hasKey: _riotKey.isNotEmpty, openSettings: _openSettings)
              : RefreshIndicator(
                  onRefresh: _search,
                  child: ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (_, index) => MatchCard(
                      analysis: _matches[index],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchDetailScreen(
                          analysis: _matches[index], openAiKey: _openAiKey,
                          model: _model, cache: _cache,
                        ),
                      )),
                    ),
                  ),
                )),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasKey, required this.openSettings});
  final bool hasKey;
  final VoidCallback openSettings;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sports_esports, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(hasKey ? 'Riot ID를 검색해봐.' : '먼저 API 키를 설정해줘.',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (!hasKey) OutlinedButton(onPressed: openSettings, child: const Text('설정 열기')),
        ]),
      ));
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.analysis, required this.onTap});
  final MatchAnalysis analysis;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = analysis.selectedPlayer;
    final color = p.win ? Colors.tealAccent : Colors.redAccent;
    final date = DateFormat('MM.dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(analysis.gameCreation),
    );
    return Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 5, height: 62, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p.win ? '승리' : '패배', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Text(p.champion, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 7),
          Text('${p.kdaLine}  ·  KDA ${p.kda.toStringAsFixed(2)}  ·  딜 ${NumberFormat.decimalPattern().format(p.damage)}'),
          const SizedBox(height: 4),
          Text('${analysis.durationSeconds ~/ 60}분 ${analysis.durationSeconds % 60}초  ·  $date',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right),
      ]),
    )));
  }
}

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.analysis, required this.openAiKey,
    required this.model, required this.cache});
  final MatchAnalysis analysis;
  final String openAiKey;
  final String model;
  final AppCache cache;
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  AiFeedback? _feedback;
  bool _loading = false;
  @override
  void initState() { super.initState(); _loadCache(); }
  Future<void> _loadCache() async {
    final value = await widget.cache.readFeedback(widget.analysis.matchId, widget.analysis.selectedPuuid);
    if (mounted) setState(() => _feedback = value);
  }
  Future<void> _analyze() async {
    setState(() => _loading = true);
    try {
      final value = await OpenAiClient(widget.openAiKey, model: widget.model)
          .analyze(widget.analysis);
      await widget.cache.writeFeedback(widget.analysis.matchId, widget.analysis.selectedPuuid, value);
      if (mounted) setState(() => _feedback = value);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final p = widget.analysis.selectedPlayer;
    final sorted = [...widget.analysis.players]..sort((a, b) {
      final team = a.teamId.compareTo(b.teamId); return team != 0 ? team : b.damage.compareTo(a.damage);
    });
    return Scaffold(
      appBar: AppBar(title: Text('${p.champion} · ${p.win ? '승리' : '패배'}')),
      body: ListView(children: [
        _HeroMetrics(player: p),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('10인 상세 지표', style: Theme.of(context).textTheme.titleLarge)),
        ...sorted.map((player) => PlayerTile(player: player, selected: player.puuid == p.puuid)),
        Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(
          onPressed: _loading ? null : _analyze,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'AI 분석 중...' : _feedback == null ? 'AI 피드백 생성' : 'AI 피드백 다시 생성'),
        )),
        if (_loading) const LinearProgressIndicator(),
        if (_feedback != null) FeedbackView(feedback: _feedback!),
        const SizedBox(height: 30),
      ]),
    );
  }
}

class _HeroMetrics extends StatelessWidget {
  const _HeroMetrics({required this.player});
  final PlayerMetrics player;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(children: [
      Text(player.kdaLine, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _metric('킬 관여', '${player.killParticipation.toStringAsFixed(1)}%'),
        _metric('딜 비중', '${player.damageShare.toStringAsFixed(1)}%'),
        _metric('분당 딜', player.damagePerMinute.toStringAsFixed(0)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 7, children: performanceBadges(player).map((b) => Chip(label: Text(b))).toList()),
    ]),
  ));
  Widget _metric(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
  ]);
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({super.key, required this.player, required this.selected});
  final PlayerMetrics player;
  final bool selected;
  @override
  Widget build(BuildContext context) => Card(
    color: selected ? const Color(0xff26345f) : null,
    child: ExpansionTile(
      leading: CircleAvatar(child: Text(player.teamId == 100 ? 'B' : 'R')),
      title: Text('${player.champion}  ${player.kdaLine}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${player.riotId} · 딜 ${NumberFormat.compact().format(player.damage)}'),
      children: [Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 16), child: Wrap(
        spacing: 14, runSpacing: 8, children: [
          Text('KDA ${player.kda}'), Text('킬관여 ${player.killParticipation}%'),
          Text('딜 비중 ${player.damageShare}%'), Text('분당 딜 ${player.damagePerMinute.toInt()}'),
          Text('분당 받은 딜 ${player.damageTakenPerMinute.toInt()}'), Text('골드 ${player.gold}'),
        ],
      ))],
    ),
  );
}

class FeedbackView extends StatelessWidget {
  const FeedbackView({super.key, required this.feedback});
  final AiFeedback feedback;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('AI 경기 총평', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10), Text(feedback.summary),
      const SizedBox(height: 8), Text('신뢰도: ${feedback.confidence}', style: const TextStyle(color: Colors.white60)),
      _section('통계로 확인된 사실', feedback.facts),
      _section('통계 기반 추론', feedback.inferences),
      _section('잘한 점', feedback.strengths),
      _section('개선할 점', feedback.improvements),
      _section('다음 경기 행동 지침', feedback.nextActions),
      const Divider(),
      const Text('AI는 경기 영상을 본 것이 아니라 제공된 통계를 분석했어.', style: TextStyle(fontSize: 12, color: Colors.white54)),
    ]),
  ));
  Widget _section(String title, List<String> items) => Padding(
    padding: const EdgeInsets.only(top: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ...items.map((item) => Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $item'))),
    ]),
  );
}

class _SettingsResult {
  const _SettingsResult(this.riotKey, this.openAiKey, this.model);
  final String riotKey;
  final String openAiKey;
  final String model;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.riotKey, required this.openAiKey,
    required this.model, required this.cache});
  final String riotKey;
  final String openAiKey;
  final String model;
  final AppCache cache;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _riot = TextEditingController(text: widget.riotKey);
  late final TextEditingController _openAi = TextEditingController(text: widget.openAiKey);
  late String _model = widget.model;
  final _secrets = SecretStore();
  Future<void> _save() async {
    await _secrets.write('riot_api_key', _riot.text.trim());
    await _secrets.write('openai_api_key', _openAi.text.trim());
    await _secrets.write('openai_model', _model);
    if (mounted) {
      Navigator.pop(
        context,
        _SettingsResult(_riot.text.trim(), _openAi.text.trim(), _model),
      );
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: _riot, obscureText: true, decoration: const InputDecoration(
        labelText: 'Riot API Key', border: OutlineInputBorder(), helperText: '개발 키는 24시간마다 만료돼',
      )),
      const SizedBox(height: 16),
      TextField(controller: _openAi, obscureText: true, decoration: const InputDecoration(
        labelText: 'OpenAI API Key', border: OutlineInputBorder(), helperText: 'AI 피드백이 필요할 때만 입력',
      )),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: _model,
        items: const [
          DropdownMenuItem(value: 'gpt-5.6-luna', child: Text('GPT-5.6 Luna · 저렴하고 빠름')),
          DropdownMenuItem(value: 'gpt-5.6-terra', child: Text('GPT-5.6 Terra · 균형형')),
          DropdownMenuItem(value: 'gpt-5.6-sol', child: Text('GPT-5.6 Sol · 고품질')),
        ],
        onChanged: (value) => setState(() => _model = value ?? _model),
        decoration: const InputDecoration(labelText: 'AI 모델', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: const Text('안전하게 저장')),
      TextButton(onPressed: () async {
        await widget.cache.clear();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 캐시를 비웠어.')));
      }, child: const Text('AI 분석 캐시 초기화')),
      const Divider(height: 36),
      const Text('API 키는 Android 암호화 저장소에 보관돼. 앱을 다른 사람에게 전달하더라도 네 키는 APK에 포함되지 않아.'),
      const SizedBox(height: 16),
      const Text('이 앱은 Riot Games의 공식 제품이 아니며, AI 분석은 경기 영상이 아닌 API 통계에 기반해.',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]),
  );
}
