class PlayerMetrics {
  const PlayerMetrics({
    required this.puuid,
    required this.riotId,
    required this.champion,
    required this.teamId,
    required this.win,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.damage,
    required this.damageTaken,
    required this.gold,
    required this.healing,
    required this.shielding,
    required this.ccTime,
    required this.kda,
    required this.killParticipation,
    required this.damageShare,
    required this.damagePerMinute,
    required this.damageTakenPerMinute,
    required this.damagePerGold,
  });

  final String puuid;
  final String riotId;
  final String champion;
  final int teamId;
  final bool win;
  final int kills;
  final int deaths;
  final int assists;
  final int damage;
  final int damageTaken;
  final int gold;
  final int healing;
  final int shielding;
  final int ccTime;
  final double kda;
  final double killParticipation;
  final double damageShare;
  final double damagePerMinute;
  final double damageTakenPerMinute;
  final double damagePerGold;

  String get kdaLine => '$kills/$deaths/$assists';

  Map<String, Object> toAiJson() => {
        'riotId': riotId,
        'champion': champion,
        'teamId': teamId,
        'win': win,
        'kdaLine': kdaLine,
        'kdaRatio': kda,
        'killParticipationPercent': killParticipation,
        'damage': damage,
        'damageSharePercent': damageShare,
        'damagePerMinute': damagePerMinute,
        'damageTakenPerMinute': damageTakenPerMinute,
        'gold': gold,
        'damagePerGold': damagePerGold,
        'healing': healing,
        'shielding': shielding,
        'ccTime': ccTime,
      };
}

class MatchAnalysis {
  const MatchAnalysis({
    required this.matchId,
    required this.durationSeconds,
    required this.gameCreation,
    required this.players,
    required this.selectedPuuid,
  });

  final String matchId;
  final int durationSeconds;
  final int gameCreation;
  final List<PlayerMetrics> players;
  final String selectedPuuid;

  PlayerMetrics get selectedPlayer =>
      players.firstWhere((player) => player.puuid == selectedPuuid);
}

class AiFeedback {
  const AiFeedback({
    required this.summary,
    required this.facts,
    required this.inferences,
    required this.strengths,
    required this.improvements,
    required this.nextActions,
    required this.confidence,
  });

  final String summary;
  final List<String> facts;
  final List<String> inferences;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> nextActions;
  final String confidence;

  factory AiFeedback.fromJson(Map<String, dynamic> json) => AiFeedback(
        summary: json['summary']?.toString() ?? '',
        facts: _strings(json['facts']),
        inferences: _strings(json['inferences']),
        strengths: _strings(json['strengths']),
        improvements: _strings(json['improvements']),
        nextActions: _strings(json['nextActions']),
        confidence: json['confidence']?.toString() ?? '보통',
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'facts': facts,
        'inferences': inferences,
        'strengths': strengths,
        'improvements': improvements,
        'nextActions': nextActions,
        'confidence': confidence,
      };

  static List<String> _strings(dynamic value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];
}
