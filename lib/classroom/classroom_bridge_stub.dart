class ClassroomSession {
  final String studentId;
  final String name;
  final String emoji;
  final int version;
  final Map<String, dynamic> snapshot;
  final Map<String, dynamic> pokemon;
  final Map<String, dynamic> activity;

  const ClassroomSession({
    required this.studentId,
    required this.name,
    required this.emoji,
    required this.version,
    required this.snapshot,
    required this.pokemon,
    this.activity = const {},
  });
}

class ClassroomBridge {
  ClassroomBridge._();
  static final instance = ClassroomBridge._();
  void Function(Map<String, dynamic>)? onActivityUpdate;

  bool get requested => false;
  void Function(Map<String, dynamic>)? onPokemonUpdate;
  Future<ClassroomSession?> waitForSession() async => null;
  void queueSave(Map<String, dynamic> snapshot) {}
  void setActivity(String activity) {}
  void logout() {}
  Future<Map<String, dynamic>> claimPokemon({
    required String source,
    required String eventId,
    String? lessonId,
    int? unit,
  }) async => {'ok': false};
  Future<Map<String, dynamic>> updatePokemonPreferences({
    int? selectedRegion,
    int? companionId,
  }) async => {'ok': false};
  Future<String?> spriteDataUrl(int id) async => null;
}
