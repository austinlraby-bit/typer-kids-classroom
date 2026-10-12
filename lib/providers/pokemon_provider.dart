import 'package:flutter/foundation.dart';
import '../classroom/classroom_bridge.dart';
import '../data/pokemon_catalog.dart';
import '../models/pokemon_species.dart';

class PokemonProvider extends ChangeNotifier {
  PokemonProvider(Map<String, dynamic> state) {
    _apply(state);
    ClassroomBridge.instance.onPokemonUpdate = (value) {
      _apply(value);
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
      error = '${r['error'] ?? 'Could not start the encounter.'}';
      notifyListeners();
      return null;
    }
    _apply((r['pokemon'] as Map?)?.cast<String, dynamic>() ?? {});
    final id = (r['caughtId'] as num?)?.toInt();
    notifyListeners();
    return id == null ? null : byId(id);
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

  void _apply(Map<String, dynamic> s) {
    final raw = (s['caught'] as Map?) ?? {};
    caught = {
      for (final e in raw.entries)
        int.parse('${e.key}'): DateTime.fromMillisecondsSinceEpoch(
          ((e.value as num?)?.toInt() ?? 0) * 1000,
        ),
    };
    claimedRewards = {
      for (final item in (s['transactions'] as List?) ?? const [])
        if (item is String)
          item
        else if (item is Map && item['id'] != null)
          '${item['id']}',
    };
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
