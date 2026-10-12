import 'dart:math';

import 'word_lists.dart';

class StoryPassage {
  final String title;
  final String source;
  final String text;

  const StoryPassage({
    required this.title,
    required this.source,
    required this.text,
  });
}

/// Original, classroom-safe passages organized by typing difficulty.
class StoryContent {
  StoryContent._();

  static const _source = 'Original Typer Kids Story';

  static const List<StoryPassage> easy = [
    StoryPassage(
      title: 'The Blue Kite',
      source: _source,
      text:
          'Mia has a blue kite. A soft wind lifts it high. The kite dips, spins, and climbs. Mia holds the string with both hands. Her kite sails above the park.',
    ),
    StoryPassage(
      title: 'A Helpful Pup',
      source: _source,
      text:
          'Pip is a small brown dog. He sees a red ball by the gate. Pip picks it up and trots home. His tail wags all the way. What a helpful pup!',
    ),
    StoryPassage(
      title: 'Garden Day',
      source: _source,
      text:
          'We dig small holes in the soil. We plant one seed in each hole. Then we add a little water. Soon green leaves peek out. Our garden has begun to grow.',
    ),
    StoryPassage(
      title: 'The Lost Sock',
      source: _source,
      text:
          'One yellow sock sat on the chair. Its match was not in the drawer. Leo looked under the bed. There it was beside a toy train. The pair was together again.',
    ),
    StoryPassage(
      title: 'Rainy-Day Fort',
      source: _source,
      text:
          'Rain taps on the window. We build a fort with chairs and sheets. A lamp glows inside. We read books and eat apple slices. Our cozy fort feels like a tiny home.',
    ),
    StoryPassage(
      title: 'Duck Parade',
      source: _source,
      text:
          'A mother duck walks by the pond. Six little ducks follow in a line. They step over a stick and around a rock. Then they all splash into the cool water.',
    ),
    StoryPassage(
      title: 'The Big Sandwich',
      source: _source,
      text:
          'Noah makes lunch for a picnic. He adds cheese, tomato, and crisp lettuce. The sandwich is very tall. He cuts it into four parts so everyone can share.',
    ),
    StoryPassage(
      title: 'Moon Shapes',
      source: _source,
      text:
          'The moon looks round tonight. Last week it looked like a thin smile. We draw each shape in a notebook. The moon changes, but it is always the same moon.',
    ),
  ];

  static const List<StoryPassage> medium = [
    StoryPassage(
      title: 'The Library Map',
      source: _source,
      text:
          'Ava found a folded map inside a library book. It showed a winding trail between the shelves. She followed the tiny arrows past history, art, and science. At the end, a note read, "Your next adventure is any book you choose."',
    ),
    StoryPassage(
      title: 'Robot Recess',
      source: _source,
      text:
          'Our class built a robot from cardboard tubes and shiny paper. We programmed it to wave, turn, and play a cheerful tune. At recess, everyone formed a line to teach the robot a new dance move.',
    ),
    StoryPassage(
      title: 'The Tiny Weather Station',
      source: _source,
      text:
          'Ben placed a rain cup, a wind ribbon, and a thermometer by the garden. Each morning, he recorded what he saw. After one month, his chart showed that windy days often arrived before rain.',
    ),
    StoryPassage(
      title: 'A Surprise for Grandma',
      source: _source,
      text:
          'Lena mixed flour, sugar, and berries while her brother made a colorful card. They cleaned the kitchen before Grandma arrived. When the door opened, the room filled with smiles and the sweet smell of muffins.',
    ),
    StoryPassage(
      title: 'The Creek Cleanup',
      source: _source,
      text:
          'Our nature club met beside the creek on Saturday. Wearing gloves, we collected paper and empty bottles from the path. By noon, the water sparkled and the trail looked welcoming again.',
    ),
    StoryPassage(
      title: 'The Homemade Telescope',
      source: _source,
      text:
          'Kai joined two cardboard tubes and carefully added simple lenses. That evening, he pointed his telescope toward the bright moon. The view was a little fuzzy, but he could still see dark patches and glowing edges.',
    ),
    StoryPassage(
      title: 'Concert in the Kitchen',
      source: _source,
      text:
          'A wooden spoon became a drumstick, and an empty container became a drum. Soon, pots chimed and cups kept the beat. Our kitchen concert was noisy, joyful, and over just in time for dinner.',
    ),
    StoryPassage(
      title: 'The Seed Exchange',
      source: _source,
      text:
          'Each student brought a packet of seeds to school. We traded sunflowers, peas, marigolds, and beans. By spring, every windowsill held a different mix of bright leaves and hopeful buds.',
    ),
  ];

  static const List<StoryPassage> hard = [
    StoryPassage(
      title: 'The Midnight Meteor Shower',
      source: _source,
      text:
          'Although the backyard was chilly, Priya stayed wrapped in a blanket and watched the northern sky. At first, nothing moved; then a silver streak flashed above the trees. Within minutes, meteors appeared one after another, turning patience into wonder.',
    ),
    StoryPassage(
      title: 'Designing a Greener School',
      source: _source,
      text:
          'The student council studied how much paper, water, and electricity the school used each week. After comparing their notes, they proposed refill stations, recycling bins, and a lights-off reminder. Small choices, they explained, could create meaningful change.',
    ),
    StoryPassage(
      title: 'The Puzzle in the Attic',
      source: _source,
      text:
          'Inside a dusty wooden box, Mateo discovered dozens of painted tiles. No instructions were included, yet each tile had a curved line along its edge. By sorting colors and matching patterns, he slowly assembled a beautiful map of an imaginary island.',
    ),
    StoryPassage(
      title: 'A City for Pollinators',
      source: _source,
      text:
          'Butterflies and bees need safe places to rest and find food, even in busy neighborhoods. Residents planted native flowers in window boxes, gardens, and schoolyards. Together, these small spaces formed a colorful pathway across the city.',
    ),
    StoryPassage(
      title: 'The Young Inventors Fair',
      source: _source,
      text:
          'Teams arrived with clever machines made from gears, sensors, recycled materials, and plenty of imagination. One invention sorted pencils by color; another reminded houseplants when the soil was dry. Every project began with a problem and a curious question.',
    ),
    StoryPassage(
      title: 'Following the River',
      source: _source,
      text:
          'From a narrow mountain stream, the river gathered water and curved through forests, farms, and towns. Scientists sampled it at several locations, recording temperature and clarity. Their observations revealed how one connected waterway supported many communities.',
    ),
    StoryPassage(
      title: 'The Community Mural',
      source: _source,
      text:
          'Before anyone opened a paint can, neighbors shared ideas for the empty brick wall. Their final design combined local plants, familiar buildings, and portraits of community helpers. Over several weekends, separate sketches became one enormous, welcoming picture.',
    ),
    StoryPassage(
      title: 'Signals from the Sea',
      source: _source,
      text:
          'The research buoy measured waves, wind, and water temperature throughout the day. Each evening, it transmitted a compact report to scientists on shore. By studying those signals over time, the team could recognize patterns and improve coastal forecasts.',
    ),
  ];

  static List<StoryPassage> forDifficulty(ContentDifficulty d) => switch (d) {
    ContentDifficulty.easy => easy,
    ContentDifficulty.medium => medium,
    ContentDifficulty.hard => hard,
  };

  static final _random = Random();

  static StoryPassage randomPassage(ContentDifficulty d) {
    final list = forDifficulty(d);
    return list[_random.nextInt(list.length)];
  }
}
