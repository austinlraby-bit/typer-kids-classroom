import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/sound_manager.dart';
import 'core/theme/app_theme.dart';
import 'providers/profile_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/pokemon_provider.dart';
import 'classroom/classroom_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure imperative API calls (push, pushReplacement) update the browser URL
  GoRouter.optionURLReflectsImperativeAPIs = true;

  final classroom = ClassroomBridge.instance;
  final classroomSession = await classroom.waitForSession();

  // This build is intentionally classroom-only. The static host serves the
  // compiled shell, but students must enter through the protected Apps Script
  // doorway so a verified classroom session is present.
  if (classroomSession == null) {
    runApp(const ClassroomOnlyApp());
    return;
  }

  // Initialize providers before app starts
  final profileProvider = ProfileProvider();
  await profileProvider.initClassroom(
    id: classroomSession.studentId,
    name: classroomSession.name,
    emoji: classroomSession.emoji,
  );

  final progressProvider = ProgressProvider();
  // Load SharedPreferences instance, then load data for the active profile
  await progressProvider.init(
    profileId: profileProvider.activeProfileId ?? '',
    classroomSnapshot: classroomSession.snapshot,
    onClassroomChanged: classroom.queueSave,
  );

  // Restore the saved sound preference (defaults to on)
  final prefs = await SharedPreferences.getInstance();
  SoundManager().enabled = prefs.getBool(SoundManager.prefsKey) ?? true;

  final pokemonProvider = PokemonProvider(classroomSession.pokemon);
  await pokemonProvider.load();

  runApp(
    TyperKidsApp(
      profileProvider: profileProvider,
      progressProvider: progressProvider,
      pokemonProvider: pokemonProvider,
    ),
  );
}

class ClassroomOnlyApp extends StatelessWidget {
  const ClassroomOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔒', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 16),
                  Text(
                    'Classroom entrance required',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This private classroom activity only opens through your teacher’s protected link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TyperKidsApp extends StatelessWidget {
  final ProfileProvider profileProvider;
  final ProgressProvider progressProvider;
  final PokemonProvider pokemonProvider;

  const TyperKidsApp({
    super.key,
    required this.profileProvider,
    required this.progressProvider,
    required this.pokemonProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider.value(value: progressProvider),
        ChangeNotifierProvider.value(value: pokemonProvider),
      ],
      child: MaterialApp.router(
        title: 'Pokémon Typing Adventure',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: AppRouter.router(profileProvider),
      ),
    );
  }
}
