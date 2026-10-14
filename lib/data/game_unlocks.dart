import 'lesson_curriculum_selector.dart';

/// Curriculum milestones that unlock each game.
///
/// Keep only lesson IDs here. The visible lesson title is read from the active
/// curriculum so a renamed lesson can never leave stale lock text in the UI.
class GameUnlocks {
  GameUnlocks._();

  static const Map<String, String> lessonByRoute = {
    '/games/key-critters': 'neo-038', // Type S + Mix: home-row letters learned
    '/games/defend-temple': 'neo-052', // Type Z + Mix: alphabet introduced
    '/games/falling-words': 'neo-055', // first alphabet-group quest
    '/games/word-bubbles': 'neo-061', // A-I group quests complete
    '/games/speed-chase': 'neo-067', // A-O group quests complete
    '/games/story-sprint': 'neo-079', // all alphabet-group quests complete
  };

  static String lessonIdFor(String route) => lessonByRoute[route]!;

  static String lessonTitleFor(String route) =>
      LessonCurriculum.byId(lessonIdFor(route))!.title;
}
