import 'dart:async';

import 'package:flutter/foundation.dart';
import '../classroom/classroom_bridge.dart';
import '../data/pokemon_catalog.dart';
import '../models/pokemon_species.dart';

class PokemonProvider extends ChangeNotifier {
  PokemonProvider(Map<String, dynamic> state) {
    _apply(state);
    ClassroomBridge.instance.onPokemonUpdate = (value) {
      // Activity-time updates can have been loaded by the host just before an
      // encounter finished. Never let that older snapshot make a Pokémon
      // disappear from the student's freshly updated Pokédex.
      _apply(value, preserveLocalCollection: true);
      notifyListeners();
    };
  }
  Map<int, DateTime> caught = {};
  Set<String> claimedRewards = {};
  Map<String, int> accuracyRecords = {};
  int selectedRegion = 0,
      companionId = 0,
      practiceSeconds = 0,
      unclaimedEncounters = 0;
  List<int> thresholds = const [0, 15, 35, 60, 90, 120, 150, 185, 220];
  int practiceMinutes = 10;
  List<PokemonSpecies> catalog = const [];
  bool busy = false;
  String? error;
  final Set<String> _pendingClaims = {};
  final Set<String> _claimingEvents = {};

  Future<void> load() async {
    catalog = await PokemonCatalog.load();
    notifyListeners();
  }

  PokemonSpecies? byId(int id) {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  int unlockedRegions(int completed) =>
      thresholds.where((n) => completed >= n).length;

  Future<PokemonSpecies?> claim({
    required String source,
    required String eventId,
    String? lessonId,
    int? unit,
  }) async {
    // The server is idempotent too, but blocking here prevents a second
    // optimistic Pokémon from briefly appearing after double taps/retries.
    if (claimedRewards.contains(eventId) || !_claimingEvents.add(eventId)) {
      return null;
    }
    try {
      final optimistic = _chooseOptimistic(source, eventId, unit);
      if (optimistic != null) {
        caught[optimistic.id] = DateTime.now();
        claimedRewards.add(eventId);
        if (companionId == 0) companionId = optimistic.id;
        error = null;
        notifyListeners();
        unawaited(
          _retryClaimQuietly(
            source: source,
            eventId: eventId,
            lessonId: lessonId,
            unit: unit,
            preferredPokemonId: optimistic.id,
          ),
        );
        return optimistic;
      }

      busy = true;
      error = null;
      notifyListeners();
      final r = await ClassroomBridge.instance.claimPokemon(
        source: source,
        eventId: eventId,
        lessonId: lessonId,
        unit: unit,
      );
      busy = false;
      if (r['ok'] != true) {
        final message = '${r['error'] ?? 'Could not start the encounter.'}';
        if (_isTemporaryClaimError(message)) {
          error = null;
          unawaited(
            _retryClaimQuietly(
              source: source,
              eventId: eventId,
              lessonId: lessonId,
              unit: unit,
            ),
          );
        } else {
          error = message;
        }
        notifyListeners();
        return null;
      }
      _apply((r['pokemon'] as Map?)?.cast<String, dynamic>() ?? {});
      final id = (r['caughtId'] as num?)?.toInt();
      notifyListeners();
      return id == null ? null : byId(id);
    } finally {
      _claimingEvents.remove(eventId);
    }
  }

  PokemonSpecies? _chooseOptimistic(String source, String eventId, int? unit) {
    final special = source == 'unit' && (unit ?? 0) % 3 == 0;
    var choices = catalog
        .where(
          (pokemon) =>
              pokemon.generation == selectedRegion + 1 &&
              !caught.containsKey(pokemon.id) &&
              (special
                  ? pokemon.legendary || pokemon.mythical
                  : !pokemon.legendary && !pokemon.mythical),
        )
        .toList(growable: false);
    if (choices.isEmpty && special) {
      choices = catalog
          .where(
            (pokemon) =>
                pokemon.generation == selectedRegion + 1 &&
                !caught.containsKey(pokemon.id) &&
                !pokemon.legendary &&
                !pokemon.mythical,
          )
          .toList(growable: false);
    }
    if (choices.isEmpty) return null;
    var hash = 0;
    for (final unit in eventId.codeUnits) {
      hash = ((hash * 37) + unit) & 0x7fffffff;
    }
    return choices[hash % choices.length];
  }

  bool _isTemporaryClaimError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('busy') ||
        lower.contains('timed out') ||
        lower.contains('connection');
  }

  Future<void> _retryClaimQuietly({
    required String source,
    required String eventId,
    String? lessonId,
    int? unit,
    int? preferredPokemonId,
  }) async {
    if (!_pendingClaims.add(eventId)) return;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        await Future<void>.delayed(
          Duration(seconds: (2 + attempt).clamp(2, 8)),
        );
        final result = await ClassroomBridge.instance.claimPokemon(
          source: source,
          eventId: eventId,
          lessonId: lessonId,
          unit: unit,
          preferredPokemonId: preferredPokemonId,
        );
        if (result['ok'] == true) {
          _apply((result['pokemon'] as Map?)?.cast<String, dynamic>() ?? {});
          notifyListeners();
          return;
        }
        final message = '${result['error'] ?? ''}';
        if (!_isTemporaryClaimError(message)) return;
      }
    } finally {
      _pendingClaims.remove(eventId);
    }
  }

  Future<void> selectRegion(int value) async {
    final r = await ClassroomBridge.instance.updatePokemonPreferences(
      selectedRegion: value,
    );
    if (r['ok'] == true) {
      _apply((r['pokemon'] as Map).cast<String, dynamic>());
      notifyListeners();
    }
  }

  Future<void> selectCompanion(int value) async {
    final r = await ClassroomBridge.instance.updatePokemonPreferences(
      companionId: value,
    );
    if (r['ok'] == true) {
      _apply((r['pokemon'] as Map).cast<String, dynamic>());
      notifyListeners();
    }
  }

  void _apply(Map<String, dynamic> s, {bool preserveLocalCollection = false}) {
    final raw = (s['caught'] as Map?) ?? {};
    final incomingCaught = <int, DateTime>{
      for (final e in raw.entries)
        int.parse('${e.key}'): DateTime.fromMillisecondsSinceEpoch(
          ((e.value as num?)?.toInt() ?? 0) * 1000,
        ),
    };
    caught = preserveLocalCollection
        ? (<int, DateTime>{...caught, ...incomingCaught})
        : incomingCaught;
    final incomingRewards = <String>{
      for (final item in (s['transactions'] as List?) ?? const [])
        if (item is String)
          item
        else if (item is Map && item['id'] != null)
          '${item['id']}',
    };
    claimedRewards = preserveLocalCollection
        ? (<String>{...claimedRewards, ...incomingRewards})
        : incomingRewards;
    accuracyRecords = {
      for (final entry in ((s['accuracyRecords'] as Map?) ?? {}).entries)
        '${entry.key}': (entry.value as num?)?.toInt() ?? 0,
    };
    selectedRegion = (s['selectedRegion'] as num?)?.toInt() ?? 0;
    companionId = (s['companionId'] as num?)?.toInt() ?? 0;
    practiceSeconds = (s['practiceSeconds'] as num?)?.toInt() ?? 0;
    unclaimedEncounters = (s['unclaimedEncounters'] as num?)?.toInt() ?? 0;
    thresholds =
        (s['thresholds'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        thresholds;
    practiceMinutes = (s['practiceMinutes'] as num?)?.toInt() ?? 10;
  }
}
