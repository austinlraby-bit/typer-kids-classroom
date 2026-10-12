import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pokemon_species.dart';

class PokemonCatalog {
  PokemonCatalog._();
  static List<PokemonSpecies>? _cache;
  static Future<List<PokemonSpecies>> load() async {
    if (_cache != null) return _cache!;
    final raw =
        jsonDecode(
              await rootBundle.loadString('assets/data/pokemon_catalog.json'),
            )
            as List;
    return _cache = raw
        .map((e) => PokemonSpecies.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}
