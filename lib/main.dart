import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/sound_manager.dart';
import 'core/theme/app_theme.dart';
import 'providers/profile_provider.dart';
import 'providers/progress_provider.dart';
import 'classroom/classroom_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure imperative API calls (push, pushReplacement) update the browser URL
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final classroom = ClassroomBridge.instance;
  final classroomSession = await classroom.waitForSession();

  // Initialize providers before app starts
  final profileProvider = ProfileProvider();
  if (classroomSession != null) {
    await profileProvider.initClassroom(
      id: classroomSession.studentId,
      name: classroomSession.name,
      emoji: classroomSession.emoji,
    );
  } else {
    await profileProvider.init();
  }

  final progressProvider = ProgressProvider();
  // Load SharedPreferences instance, then load data for the active profile
  await progressProvider.init(
    profileId: profileProvider.activeProfileId ?? '',
    classroomSnapshot: classroomSession?.snapshot,
    onClassroomChanged: classroomSession == null ? null : classroom.queueSave,
  );

  // Restore the saved sound preference (defaults to on)
  final prefs = await SharedPreferences.getInstance();
  SoundManager().enabled = prefs.getBool(SoundManager.prefsKey) ?? true;

  runApp(
    TyperKidsApp(
      profileProvider: profileProvider,
      progressProvider: progressProvider,
    ),
  );
}

class TyperKidsApp extends StatelessWidget {
  final ProfileProvider profileProvider;
  final ProgressProvider progressProvider;

  const TyperKidsApp({
    super.key,
    required this.profileProvider,
    required this.progressProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider.value(value: progressProvider),
      ],
      child: MaterialApp.router(
        title: 'Typer Kids',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: AppRouter.router(profileProvider),
      ),
    );
  }
}
