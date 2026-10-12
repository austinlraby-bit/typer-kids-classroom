import 'package:flutter/material.dart';

/// Loads artwork only while the authenticated classroom app is running.
/// No sprite files are packaged in or redistributed by this repository.
class PokemonSprite extends StatelessWidget {
  final int id;
  final double size;

  const PokemonSprite(this.id, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.catching_pokemon, color: Colors.redAccent),
      ),
    );
  }
}
