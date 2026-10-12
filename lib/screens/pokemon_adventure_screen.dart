import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_species.dart';
import '../providers/pokemon_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/profile_provider.dart';

class PokemonAdventureScreen extends StatelessWidget {
  const PokemonAdventureScreen({super.key});
  static const regions = [
    'Kanto',
    'Johto',
    'Hoenn',
    'Sinnoh',
    'Unova',
    'Kalos',
    'Alola',
    'Galar',
    'Paldea',
  ];
  @override
  Widget build(BuildContext context) {
    final pokemon = context.watch<PokemonProvider>(),
        progress = context.watch<ProgressProvider>();
    final unlocked = pokemon.unlockedRegions(progress.completedLessons);
    final companion = pokemon.byId(pokemon.companionId);
    return Scaffold(
      appBar: AppBar(title: const Text('Pokémon Adventure')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF223A67),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Sprite(companion, size: 76),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.watch<ProfileProvider>().activeProfile?.name ?? 'Trainer'}’s Trainer Card',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${pokemon.caught.length}/1025 caught  •  $unlocked regions',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: pokemon.unclaimedEncounters > 0 && !pokemon.busy
                      ? () async {
                          final caught = await pokemon.claim(
                            source: 'practice',
                            eventId:
                                'practice_${DateTime.now().microsecondsSinceEpoch}',
                          );
                          if (context.mounted && caught != null) {
                            _caughtDialog(context, caught);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.catching_pokemon),
                  label: Text(
                    pokemon.unclaimedEncounters > 0
                        ? 'Start encounter (${pokemon.unclaimedEncounters})'
                        : '${pokemon.practiceSeconds ~/ 60}/${pokemon.practiceMinutes} practice min',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  regions.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        i < unlocked ? regions[i] : '🔒 ${regions[i]}',
                      ),
                      selected: pokemon.selectedRegion == i,
                      onSelected: i < unlocked
                          ? (v) {
                              if (v) pokemon.selectRegion(i);
                            }
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (pokemon.error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                pokemon.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(child: _PokedexGrid(region: pokemon.selectedRegion)),
        ],
      ),
    );
  }

  static void _caughtDialog(BuildContext context, PokemonSpecies p) =>
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Gotcha! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Sprite(p, size: 150),
              Text(
                '${p.name} was added to your Pokédex!',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(fontSize: 22),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
}

class _PokedexGrid extends StatelessWidget {
  final int region;
  const _PokedexGrid({required this.region});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PokemonProvider>();
    final list = provider.catalog
        .where((p) => p.generation == region + 1)
        .toList();
    final caught = list.where((p) => provider.caught.containsKey(p.id)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${PokemonAdventureScreen.regions[region]} Pokédex',
                style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$caught/${list.length} • ${list.isEmpty ? 0 : (caught * 100 / list.length).round()}%',
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: .86,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i], has = provider.caught.containsKey(p.id);
              return InkWell(
                onTap: has ? () => provider.selectCompanion(p.id) : null,
                child: Card(
                  color: has ? Colors.white : const Color(0xFFE5E8EE),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        has
                            ? _Sprite(p, size: 76)
                            : const Icon(
                                Icons.help_outline,
                                size: 62,
                                color: Colors.black26,
                              ),
                        Text(
                          '#${p.id.toString().padLeft(4, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          has ? p.name : '???',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (provider.companionId == p.id)
                          const Text(
                            '★ Companion',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Sprite extends StatelessWidget {
  final PokemonSpecies? p;
  final double size;
  const _Sprite(this.p, {required this.size});
  @override
  Widget build(BuildContext context) => p == null
      ? SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.catching_pokemon, color: Colors.white54),
        )
      : Image.network(
          p!.spriteUrl,
          width: size,
          height: size,
          filterQuality: FilterQuality.none,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: size,
            height: size,
            child: const Icon(Icons.catching_pokemon),
          ),
        );
}
