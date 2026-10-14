import 'package:flutter/foundation.dart';

import '../classroom/classroom_bridge.dart';

class OnTaskProvider extends ChangeNotifier {
  int weeklySeconds;
  int weeklyGoalMinutes;
  List<Map<String, dynamic>> leaderboard;
  int currentRank;

  OnTaskProvider(Map<String, dynamic> initial)
    : weeklySeconds = (initial['weeklySeconds'] as num?)?.toInt() ?? 0,
      weeklyGoalMinutes = (initial['weeklyGoalMinutes'] as num?)?.toInt() ?? 30,
      leaderboard = _rows(initial),
      currentRank =
          ((initial['leaderboard'] as Map?)?['currentRank'] as num?)?.toInt() ??
          0 {
    ClassroomBridge.instance.onActivityUpdate = _apply;
  }

  void _apply(Map<String, dynamic> value) {
    weeklySeconds = (value['weeklySeconds'] as num?)?.toInt() ?? weeklySeconds;
    weeklyGoalMinutes =
        (value['weeklyGoalMinutes'] as num?)?.toInt() ?? weeklyGoalMinutes;
    leaderboard = _rows(value);
    currentRank =
        ((value['leaderboard'] as Map?)?['currentRank'] as num?)?.toInt() ??
        currentRank;
    notifyListeners();
  }

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> value) =>
      (((value['leaderboard'] as Map?)?['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
}
