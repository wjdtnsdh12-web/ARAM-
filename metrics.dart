import 'models.dart';

double _number(dynamic value) => value is num ? value.toDouble() : 0;
int _integer(dynamic value) => value is num ? value.toInt() : 0;
double _ratio(num numerator, num denominator) =>
    denominator == 0 ? 0 : numerator / denominator;
double _round(double value, int digits) {
  final factor = List.filled(digits, 10).fold<double>(1, (a, b) => a * b);
  return (value * factor).round() / factor;
}

MatchAnalysis calculateMatchMetrics(
  Map<String, dynamic> match,
  String selectedPuuid,
) {
  final metadata = Map<String, dynamic>.from(match['metadata'] as Map);
  final info = Map<String, dynamic>.from(match['info'] as Map);
  final rawPlayers = (info['participants'] as List)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList(growable: false);
  final duration = _integer(info['gameDuration']);
  final minutes = duration > 0 ? duration / 60 : 1 / 60;
  final teamKills = <int, int>{};
  final teamDamage = <int, int>{};

  for (final player in rawPlayers) {
    final team = _integer(player['teamId']);
    teamKills[team] = (teamKills[team] ?? 0) + _integer(player['kills']);
    teamDamage[team] =
        (teamDamage[team] ?? 0) + _integer(player['totalDamageDealtToChampions']);
  }

  final players = rawPlayers.map((player) {
    final team = _integer(player['teamId']);
    final kills = _integer(player['kills']);
    final deaths = _integer(player['deaths']);
    final assists = _integer(player['assists']);
    final damage = _integer(player['totalDamageDealtToChampions']);
    final damageTaken = _integer(player['totalDamageTaken']);
    final gold = _integer(player['goldEarned']);
    final name = (player['riotIdGameName'] ?? player['summonerName'] ?? 'Unknown').toString();
    final tag = player['riotIdTagline']?.toString();

    return PlayerMetrics(
      puuid: player['puuid'].toString(),
      riotId: tag == null || tag.isEmpty ? name : '$name#$tag',
      champion: player['championName']?.toString() ?? 'Unknown',
      teamId: team,
      win: player['win'] == true,
      kills: kills,
      deaths: deaths,
      assists: assists,
      damage: damage,
      damageTaken: damageTaken,
      gold: gold,
      healing: _integer(player['totalHeal']),
      shielding: _integer(player['totalDamageShieldedOnTeammates']),
      ccTime: _integer(player['timeCCingOthers']),
      kda: _round(_ratio(kills + assists, deaths == 0 ? 1 : deaths), 2),
      killParticipation:
          _round(_ratio(kills + assists, teamKills[team] ?? 0) * 100, 1),
      damageShare: _round(_ratio(damage, teamDamage[team] ?? 0) * 100, 1),
      damagePerMinute: _number(damage / minutes).roundToDouble(),
      damageTakenPerMinute: _number(damageTaken / minutes).roundToDouble(),
      damagePerGold: _round(_ratio(damage, gold), 2),
    );
  }).toList(growable: false);

  if (!players.any((player) => player.puuid == selectedPuuid)) {
    throw const FormatException('선택한 플레이어가 경기 데이터에 없어.');
  }
  return MatchAnalysis(
    matchId: metadata['matchId'].toString(),
    durationSeconds: duration,
    gameCreation: _integer(info['gameCreation']),
    players: players,
    selectedPuuid: selectedPuuid,
  );
}

List<String> performanceBadges(PlayerMetrics player) {
  final badges = <String>[];
  if (player.killParticipation >= 70) badges.add('높은 킬 관여');
  if (player.damageShare >= 25) badges.add('팀 핵심 딜러');
  if (player.kda >= 4) badges.add('안정적인 교전');
  if (player.damageTakenPerMinute >= 1500) badges.add('높은 피해 흡수');
  if (player.ccTime >= 30) badges.add('강한 CC 기여');
  if (player.shielding + player.healing >= 10000) badges.add('높은 유지력 기여');
  return badges;
}
