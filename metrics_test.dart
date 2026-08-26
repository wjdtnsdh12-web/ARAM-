import 'package:aram_ai_analyzer/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> player(String id, int team, int kills, int deaths,
    int assists, int damage) => {
  'puuid': id, 'teamId': team, 'kills': kills, 'deaths': deaths,
  'assists': assists, 'totalDamageDealtToChampions': damage,
  'totalDamageTaken': 10000, 'goldEarned': 10000, 'totalHeal': 1000,
  'totalDamageShieldedOnTeammates': 0, 'timeCCingOthers': 10,
  'championName': 'TestChamp', 'win': team == 100,
  'riotIdGameName': id, 'riotIdTagline': 'KR1',
};

void main() {
  test('calculates team-relative metrics', () {
    final match = {
      'metadata': {'matchId': 'KR_1'},
      'info': {
        'gameDuration': 1200,
        'gameCreation': 0,
        'participants': [
          player('me', 100, 10, 2, 5, 30000),
          player('ally', 100, 5, 5, 10, 10000),
          player('enemy1', 200, 5, 5, 5, 20000),
          player('enemy2', 200, 5, 5, 5, 20000),
        ],
      },
    };
    final me = calculateMatchMetrics(match, 'me').selectedPlayer;
    expect(me.kda, 7.5);
    expect(me.killParticipation, 100);
    expect(me.damageShare, 75);
    expect(me.damagePerMinute, 1500);
    expect(performanceBadges(me), contains('팀 핵심 딜러'));
  });
}
