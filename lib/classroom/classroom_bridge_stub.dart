class ClassroomSession {
  final String studentId;
  final String name;
  final String emoji;
  final int version;
  final Map<String, dynamic> snapshot;

  const ClassroomSession({
    required this.studentId,
    required this.name,
    required this.emoji,
    required this.version,
    required this.snapshot,
  });
}

class ClassroomBridge {
  ClassroomBridge._();
  static final instance = ClassroomBridge._();

  bool get requested => false;
  Future<ClassroomSession?> waitForSession() async => null;
  void queueSave(Map<String, dynamic> snapshot) {}
  void setActivity(String activity) {}
  void logout() {}
}
