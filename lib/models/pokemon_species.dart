class PokemonSpecies {
  final int id;
  final String name;
  final int generation;
  final String region;
  final String spriteUrl;
  final bool legendary;
  final bool mythical;
  final int? evolvesFrom;
  final int evolutionChain;

  const PokemonSpecies({
    required this.id,
    required this.name,
    required this.generation,
    required this.region,
    required this.spriteUrl,
    required this.legendary,
    required this.mythical,
    required this.evolvesFrom,
    required this.evolutionChain,
  });

  factory PokemonSpecies.fromJson(Map<String, dynamic> j) => PokemonSpecies(
    id: (j['id'] as num).toInt(),
    name: '${j['name']}',
    generation: (j['generation'] as num).toInt(),
    region: '${j['region']}',
    spriteUrl: '${j['spriteUrl']}',
    legendary: j['legendary'] == true,
    mythical: j['mythical'] == true,
    evolvesFrom: (j['evolvesFrom'] as num?)?.toInt(),
    evolutionChain: (j['evolutionChain'] as num).toInt(),
  );
}
