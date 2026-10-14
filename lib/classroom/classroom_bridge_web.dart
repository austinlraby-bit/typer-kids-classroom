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
  final Map<String, dynamic> activity;

  const ClassroomSession({
    required this.studentId,
    required this.name,
    required this.emoji,
    required this.version,
    required this.snapshot,
    required this.pokemon,
    required this.activity,
  });
}

class ClassroomBridge {
  ClassroomBridge._() {
    html.window.onMessage.listen(_onMessage);
    html.window.onKeyDown.listen((event) {
      final key = event.key ?? '';
      if (event.repeat != true && (key.length == 1 || key == 'Backspace')) {
        _send({'type': 'typer-activity'});
      }
    });
  }

  static final instance = ClassroomBridge._();
  final _sessionCompleter = Completer<ClassroomSession?>();
  Timer? _saveTimer;
  Map<String, dynamic>? _pendingSnapshot;
  final Map<String, Completer<Map<String, dynamic>>> _requests = {};
  final Map<int, String> _spriteCache = {};
  final Map<int, Future<String?>> _spriteRequests = {};
  String? _studentId;
  Timer? _pokemonReplayTimer;
  void Function(Map<String, dynamic>)? onPokemonUpdate;
  void Function(Map<String, dynamic>)? onActivityUpdate;

  bool get requested => Uri.base.queryParameters['classroom'] == '1';

  Future<ClassroomSession?> waitForSession() async {
    if (!requested) return null;
    // The Apps Script host and the Flutter iframe load independently. Safari
    // on managed iPads can drop the first cross-frame message while the child
    // is still becoming active, so keep announcing readiness until the host's
    // session arrives instead of leaving the app blank forever.
    final readyTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _send({'type': 'typer-ready'}),
    );
    _send({'type': 'typer-ready'});
    try {
      return await _sessionCompleter.future;
    } finally {
      readyTimer.cancel();
    }
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
      if (message['type'] == 'sprite-response') {
        final requestId = '${message['requestId'] ?? ''}';
        final completer = _requests.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete({
            'ok': message['ok'] == true,
            'dataUrl': message['dataUrl'],
          });
        }
        return;
      }
      if (message['type'] == 'pokemon-update') {
        onPokemonUpdate?.call(
          (message['pokemon'] as Map?)?.cast<String, dynamic>() ?? {},
        );
        return;
      }
      if (message['type'] == 'activity-update') {
        onActivityUpdate?.call(
          (message['activity'] as Map?)?.cast<String, dynamic>() ?? {},
        );
        return;
      }
      if (message['type'] != 'classroom-session' ||
          _sessionCompleter.isCompleted) {
        return;
      }
      final student =
          (message['student'] as Map?)?.cast<String, dynamic>() ?? {};
      _studentId = '${student['id'] ?? ''}';
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
          activity:
              (message['activity'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
      );
      _send({'type': 'typer-session-ready'});
      Timer(const Duration(seconds: 1), _replayPendingPokemonClaims);
      _pokemonReplayTimer?.cancel();
      _pokemonReplayTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _replayPendingPokemonClaims(),
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
    int? preferredPokemonId,
  }) async {
    final payload = <String, dynamic>{'source': source, 'eventId': eventId};
    payload.addAll(
      {
        'lessonId': lessonId,
        'unit': unit,
        'preferredPokemonId': preferredPokemonId,
      }..removeWhere((_, value) => value == null),
    );
    if (preferredPokemonId != null) _storePendingPokemonClaim(payload);
    final result = await _request('pokemon-claim', payload);
    if (result['ok'] == true) _removePendingPokemonClaim(eventId);
    return result;
  }

  String? get _pendingPokemonKey {
    final id = _studentId;
    return id == null || id.isEmpty ? null : 'pokemon-pending:$id';
  }

  List<Map<String, dynamic>> _pendingPokemonClaims() {
    final key = _pendingPokemonKey;
    if (key == null) return [];
    try {
      final decoded = jsonDecode(html.window.localStorage[key] ?? '[]') as List;
      return decoded
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Catches shown immediately but not yet acknowledged by the classroom
  /// server. Reapplying them on startup prevents a refresh or brief outage
  /// from making an earned Pokémon disappear from the Pokédex.
  List<Map<String, dynamic>> pendingPokemonClaims() =>
      List<Map<String, dynamic>>.from(_pendingPokemonClaims());

  void _storePendingPokemonClaim(Map<String, dynamic> payload) {
    final key = _pendingPokemonKey;
    if (key == null) return;
    final claims = _pendingPokemonClaims()
      ..removeWhere((item) => item['eventId'] == payload['eventId'])
      ..add(Map<String, dynamic>.from(payload));
    html.window.localStorage[key] = jsonEncode(claims.take(50).toList());
  }

  void _removePendingPokemonClaim(String eventId) {
    final key = _pendingPokemonKey;
    if (key == null) return;
    final claims = _pendingPokemonClaims()
      ..removeWhere((item) => item['eventId'] == eventId);
    if (claims.isEmpty) {
      html.window.localStorage.remove(key);
    } else {
      html.window.localStorage[key] = jsonEncode(claims);
    }
  }

  Future<void> _replayPendingPokemonClaims() async {
    for (final claim in List<Map<String, dynamic>>.from(
      _pendingPokemonClaims(),
    )) {
      final result = await _request('pokemon-claim', claim);
      if (result['ok'] == true) {
        _removePendingPokemonClaim('${claim['eventId']}');
        final pokemon = (result['pokemon'] as Map?)?.cast<String, dynamic>();
        if (pokemon != null) onPokemonUpdate?.call(pokemon);
      }
    }
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

  Future<String?> spriteDataUrl(int id) {
    final cached = _spriteCache[id];
    if (cached != null) return Future.value(cached);
    return _spriteRequests.putIfAbsent(id, () => _loadSprite(id));
  }

  Future<String?> _loadSprite(int id) async {
    final result = await _request('pokemon-sprite', {'pokemonId': id});
    final dataUrl = result['dataUrl'];
    if (result['ok'] == true && dataUrl is String && dataUrl.isNotEmpty) {
      _spriteCache[id] = dataUrl;
      _spriteRequests.remove(id);
      return dataUrl;
    }
    _spriteRequests.remove(id);
    return null;
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
      const Duration(seconds: 12),
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
