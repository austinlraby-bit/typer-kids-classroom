import 'package:flutter_test/flutter_test.dart';
import 'package:typer_kids/classroom/classroom_bridge.dart';
import 'package:typer_kids/providers/pokemon_provider.dart';

void main() {
  test('stale activity update cannot remove a newly caught Pokemon', () {
    final provider = PokemonProvider({
      'caught': {'25': 100},
      'transactions': const [
        {'id': 'lesson_new', 'pokemonId': 25},
      ],
    });

    ClassroomBridge.instance.onPokemonUpdate?.call({
      'caught': {'1': 50},
      'transactions': const [
        {'id': 'lesson_old', 'pokemonId': 1},
      ],
    });

    expect(provider.caught.keys, containsAll(<int>[1, 25]));
    expect(
      provider.claimedRewards,
      containsAll(<String>['lesson_old', 'lesson_new']),
    );
  });
}
