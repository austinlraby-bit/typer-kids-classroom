import 'dart:convert';

import 'package:flutter/material.dart';

import '../classroom/classroom_bridge.dart';

/// Loads artwork only while the authenticated classroom app is running.
/// No sprite files are packaged in or redistributed by this repository.
class PokemonSprite extends StatefulWidget {
  final int id;
  final double size;

  const PokemonSprite(this.id, {super.key, this.size = 64});

  @override
  State<PokemonSprite> createState() => _PokemonSpriteState();
}

class _PokemonSpriteState extends State<PokemonSprite> {
  late Future<String?> _sprite;

  @override
  void initState() {
    super.initState();
    _sprite = ClassroomBridge.instance.spriteDataUrl(widget.id);
  }

  @override
  void didUpdateWidget(covariant PokemonSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _sprite = ClassroomBridge.instance.spriteDataUrl(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<String?>(
        future: _sprite,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final dataUrl = snapshot.data;
          if (dataUrl == null) {
            return const Icon(Icons.catching_pokemon, color: Colors.redAccent);
          }
          return Image.memory(
            base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1)),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.catching_pokemon, color: Colors.redAccent),
          );
        },
      ),
    );
  }
}
