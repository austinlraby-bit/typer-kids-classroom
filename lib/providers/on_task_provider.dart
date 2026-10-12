import 'package:flutter/foundation.dart';

import '../classroom/classroom_bridge.dart';

class OnTaskProvider extends ChangeNotifier {
  int weeklySeconds;
  int weeklyGoalMinutes;

  OnTaskProvider(Map<String, dynamic> initial)
    : weeklySeconds = (initial['weeklySeconds'] as num?)?.toInt() ?? 0,
      weeklyGoalMinutes =
          (initial['weeklyGoalMinutes'] as num?)?.toInt() ?? 30 {
    ClassroomBridge.instance.onActivityUpdate = _apply;
  }

  void _apply(Map<String, dynamic> value) {
    weeklySeconds = (value['weeklySeconds'] as num?)?.toInt() ?? weeklySeconds;
    weeklyGoalMinutes =
        (value['weeklyGoalMinutes'] as num?)?.toInt() ?? weeklyGoalMinutes;
    notifyListeners();
  }
}
