import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/shortcut_badge.dart';
import '../../widgets/pokemon_sprite.dart';

/// Menu screen listing available typing games.
class GameMenuScreen extends StatefulWidget {
  const GameMenuScreen({super.key});

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> {
  final FocusNode _focusNode = FocusNode();

  static const _requirements = <String, (String, String)>{
    '/games/defend-temple': ('hr-05', 'Home Row Party!'),
    '/games/falling-words': ('hr-08', 'Home Row Master!'),
    '/games/word-bubbles': ('tr-03', 'T and Y in the Middle'),
    '/games/speed-chase': ('tr-06', 'Top Row Review'),
    '/games/key-critters': ('br-03', 'X and . (Period)'),
    '/games/story-sprint': ('br-06', 'Bottom Row Review'),
  };

  void _openGame(String route) {
    final requirement = _requirements[route]!;
    final unlocked = context
        .read<ProgressProvider>()
        .getProgress(requirement.$1)
        .completed;
    if (unlocked) {
      context.push(route);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Finish “${requirement.$2}” to unlock this game.'),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      context.pop();
    } else if (key == LogicalKeyboardKey.digit1) {
      _openGame('/games/defend-temple');
    } else if (key == LogicalKeyboardKey.digit2) {
      _openGame('/games/falling-words');
    } else if (key == LogicalKeyboardKey.digit3) {
      _openGame('/games/word-bubbles');
    } else if (key == LogicalKeyboardKey.digit4) {
      _openGame('/games/speed-chase');
    } else if (key == LogicalKeyboardKey.digit5) {
      _openGame('/games/key-critters');
    } else if (key == LogicalKeyboardKey.digit6) {
      _openGame('/games/story-sprint');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progress = context.watch<ProgressProvider>();
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;
              final isWide = screenW > 600;
              final isTall = screenH > 700;
              final useGrid = screenW > 860;

              final hPad = isWide ? 40.0 : 20.0;
              final vPad = isTall ? 32.0 : 16.0;
              final maxW = useGrid
                  ? 900.0
                  : isWide
                  ? 620.0
                  : screenW;
              final headerFontSize = isWide ? 36.0 : 28.0;
              final emojiSize = isTall ? 56.0 : 40.0;
              final sectionGap = isTall ? 32.0 : 18.0;
              final cardGap = isTall ? 14.0 : 10.0;

              final gameCards = <Widget>[
                _GameCard(
                  pokemonId: 113,
                  title: 'Pokémon Center Guard',
                  description:
                      'Guide mischievous Pokémon away from the Center!',
                  shortcut: '1',
                  color: const Color(0xFF8B0000),
                  compact: !isTall,
                  unlockLesson: 'Home Row Party!',
                  unlocked: progress.getProgress('hr-05').completed,
                  onTap: () => _openGame('/games/defend-temple'),
                ),
                _GameCard(
                  pokemonId: 25,
                  title: 'Poké Ball Rescue',
                  description: 'Type the words before they reach the bottom!',
                  shortcut: '2',
                  color: AppColors.primary,
                  compact: !isTall,
                  unlockLesson: 'Home Row Master!',
                  unlocked: progress.getProgress('hr-08').completed,
                  onTap: () => _openGame('/games/falling-words'),
                ),
                _GameCard(
                  pokemonId: 7,
                  title: 'Squirtle’s Bubble Challenge',
                  description: 'Pop the floating bubbles by typing the words!',
                  shortcut: '3',
                  color: const Color(0xFF26C6DA),
                  compact: !isTall,
                  unlockLesson: 'T and Y in the Middle',
                  unlocked: progress.getProgress('tr-03').completed,
                  onTap: () => _openGame('/games/word-bubbles'),
                ),
                _GameCard(
                  pokemonId: 78,
                  title: 'Rapidash Race',
                  description: 'Help Rapidash keep pace with Ponyta!',
                  shortcut: '4',
                  color: const Color(0xFFE53935),
                  compact: !isTall,
                  unlockLesson: 'Top Row Review',
                  unlocked: progress.getProgress('tr-06').completed,
                  onTap: () => _openGame('/games/speed-chase'),
                ),
                _GameCard(
                  pokemonId: 50,
                  title: 'Diglett’s Digging Game',
                  description: 'Press each key before Diglett burrows away!',
                  shortcut: '5',
                  color: const Color(0xFF43A047),
                  compact: !isTall,
                  unlockLesson: 'X and . (Period)',
                  unlocked: progress.getProgress('br-03').completed,
                  onTap: () => _openGame('/games/key-critters'),
                ),
                _GameCard(
                  pokemonId: 133,
                  title: 'Pokémon Dash',
                  description: 'Help Eevee dash along the adventure trail!',
                  shortcut: '6',
                  color: const Color(0xFFFB8C00),
                  compact: !isTall,
                  unlockLesson: 'Bottom Row Review',
                  unlocked: progress.getProgress('br-06').completed,
                  onTap: () => _openGame('/games/story-sprint'),
                ),
              ];

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: vPad,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Column(
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Back',
                                  style: GoogleFonts.fredoka(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                ShortcutBadge('Esc'),
                              ],
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(height: isTall ? 12 : 6),
                        // Header
                        PokemonSprite(25, size: emojiSize + 18),
                        SizedBox(height: isTall ? 8 : 4),
                        Text(
                          'Pokémon Training Grounds',
                          style: GoogleFonts.fredoka(
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose a training activity!',
                          style: GoogleFonts.nunito(
                            fontSize: isWide ? 16.0 : 14.0,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        // ── Game cards ──
                        if (useGrid) ...[
                          // Two cards per row
                          for (var i = 0; i < gameCards.length; i += 2) ...[
                            if (i > 0) SizedBox(height: cardGap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: gameCards[i]),
                                SizedBox(width: cardGap),
                                Expanded(
                                  child: i + 1 < gameCards.length
                                      ? gameCards[i + 1]
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          // Vertical list
                          for (var i = 0; i < gameCards.length; i++) ...[
                            gameCards[i],
                            if (i < gameCards.length - 1)
                              SizedBox(height: cardGap),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final int pokemonId;
  final String title;
  final String description;
  final String shortcut;
  final Color color;
  final bool compact;
  final bool unlocked;
  final String unlockLesson;
  final VoidCallback onTap;

  const _GameCard({
    required this.pokemonId,
    required this.title,
    required this.description,
    required this.shortcut,
    required this.color,
    this.compact = false,
    required this.unlocked,
    required this.unlockLesson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 14.0 : 20.0;
    final emojiSize = compact ? 32.0 : 40.0;
    final titleSize = compact ? 18.0 : 22.0;
    final descSize = compact ? 12.0 : 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              PokemonSprite(pokemonId, size: emojiSize + 18),
              SizedBox(width: compact ? 10 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.fredoka(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlocked
                          ? description
                          : '🔒 Finish “$unlockLesson” to unlock',
                      style: GoogleFonts.nunito(
                        fontSize: descSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (unlocked)
                ShortcutBadge(shortcut)
              else
                const Icon(Icons.lock_rounded),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
