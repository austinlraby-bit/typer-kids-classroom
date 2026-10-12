// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ClassroomSession {
  final String studentId;
  final String name;
  final String emoji;
  final int version;
  final Map<String, dynamic> snapshot;
  final Map<String, dynamic> pokemon;

  const ClassroomSession({
    required this.studentId,
    required this.name,
    required this.emoji,
    required this.version,
    required this.snapshot,
    required this.pokemon,
  });
}

class ClassroomBridge {
  ClassroomBridge._() {
    html.window.onMessage.listen(_onMessage);
    html.window.onKeyDown.listen((_) => _send({'type': 'typer-activity'}));
  }

  static final instance = ClassroomBridge._();
  final _sessionCompleter = Completer<ClassroomSession?>();
  Timer? _saveTimer;
  Map<String, dynamic>? _pendingSnapshot;
  final Map<String, Completer<Map<String, dynamic>>> _requests = {};
  void Function(Map<String, dynamic>)? onPokemonUpdate;

  bool get requested => Uri.base.queryParameters['classroom'] == '1';

  Future<ClassroomSession?> waitForSession() async {
    if (!requested) return null;
    _send({'type': 'typer-ready'});
    return _sessionCompleter.future;
  }

  void _onMessage(html.MessageEvent event) {
    if (!requested || event.data is! String) return;
    final origin = event.origin;
    if (!origin.contains('script.google.com') &&
        !origin.contains('googleusercontent.com') &&
        origin != html.window.location.origin) {
      return;
    }
    try {
      final message = jsonDecode(event.data as String) as Map<String, dynamic>;
      if (message['type'] == 'pokemon-response') {
        final requestId = '${message['requestId'] ?? ''}';
        final completer = _requests.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(
            (message['result'] as Map?)?.cast<String, dynamic>() ?? {},
          );
        }
        return;
      }
      if (message['type'] == 'pokemon-update') {
        onPokemonUpdate?.call(
          (message['pokemon'] as Map?)?.cast<String, dynamic>() ?? {},
        );
        return;
      }
      if (message['type'] != 'classroom-session' ||
          _sessionCompleter.isCompleted) {
        return;
      }
      final student =
          (message['student'] as Map?)?.cast<String, dynamic>() ?? {};
      final progress =
          (message['progress'] as Map?)?.cast<String, dynamic>() ?? {};
      final profile =
          (progress['profile'] as Map?)?.cast<String, dynamic>() ?? {};
      final snapshot =
          (profile['typerKids'] as Map?)?.cast<String, dynamic>() ?? {};
      _sessionCompleter.complete(
        ClassroomSession(
          studentId: '${student['id'] ?? ''}',
          name: '${student['name'] ?? 'Student'}',
          emoji: '${profile['avatar'] ?? '⚡'}',
          version: (progress['version'] as num?)?.toInt() ?? 0,
          snapshot: snapshot,
          pokemon: (message['pokemon'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
      );
    } catch (_) {
      // Ignore unrelated messages from the host page.
    }
  }

  void queueSave(Map<String, dynamic> snapshot) {
    if (!requested) return;
    _pendingSnapshot = snapshot;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      final pending = _pendingSnapshot;
      if (pending == null) return;
      _pendingSnapshot = null;
      _send({'type': 'typer-save', 'snapshot': pending});
    });
  }

  void setActivity(String activity) {
    if (requested) _send({'type': 'typer-context', 'activity': activity});
  }

  void logout() {
    if (requested) _send({'type': 'typer-logout'});
  }

  Future<Map<String, dynamic>> claimPokemon({
    required String source,
    required String eventId,
    String? lessonId,
    int? unit,
  }) {
    final payload = <String, dynamic>{'source': source, 'eventId': eventId};
    payload.addAll(
      {'lessonId': lessonId, 'unit': unit}
        ..removeWhere((_, value) => value == null),
    );
    return _request('pokemon-claim', payload);
  }

  Future<Map<String, dynamic>> updatePokemonPreferences({
    int? selectedRegion,
    int? companionId,
  }) {
    final payload = <String, dynamic>{
      'selectedRegion': selectedRegion,
      'companionId': companionId,
    }..removeWhere((_, value) => value == null);
    return _request('pokemon-preferences', payload);
  }

  Future<Map<String, dynamic>> _request(
    String type,
    Map<String, dynamic> payload,
  ) {
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}_${_requests.length}';
    final completer = Completer<Map<String, dynamic>>();
    _requests[requestId] = completer;
    _send({'type': type, 'requestId': requestId, ...payload});
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _requests.remove(requestId);
        return {
          'ok': false,
          'error': 'The classroom connection timed out. Please try again.',
        };
      },
    );
  }

  void _send(Map<String, dynamic> message) {
    html.window.parent?.postMessage(jsonEncode(message), '*');
  }
}
