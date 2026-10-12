import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../classroom/classroom_bridge.dart';
import '../data/lesson_curriculum_selector.dart';
import '../models/lesson.dart';
import '../models/typing_stats.dart';
import '../models/pokemon_species.dart';
import '../providers/pokemon_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/shortcut_badge.dart';
import '../widgets/star_rating.dart';
import '../widgets/pokemon_sprite.dart';

/// Celebration screen shown after completing a lesson
class ResultsScreen extends StatefulWidget {
  final Lesson lesson;
  final TypingStats stats;

  const ResultsScreen({super.key, required this.lesson, required this.stats});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _slideController;
  late AnimationController _encounterController;
  late Animation<Offset> _slideAnimation;
  final FocusNode _focusNode = FocusNode();
  final List<PokemonSpecies> _caught = [];
  bool _checkingRewards = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _encounterController = AnimationController(
      duration: const Duration(milliseconds: 850),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
      if (widget.stats.starRating >= 3) {
        _confettiController.play();
      }
    });

    // Request focus after animations settle for keyboard shortcuts
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _focusNode.requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimRewards());
  }

  Future<void> _claimRewards() async {
    if (_passed != true || !mounted) return;
    final provider = context.read<PokemonProvider>();
    final completed = context.read<ProgressProvider>().completedLessons;
    final lessonPart = widget.lesson.id.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final lessonEvent = 'lesson_$lessonPart';
    final unit = completed > 0 && completed % 10 == 0 ? completed ~/ 10 : 0;
    final unitEvent = 'unit_reward_$unit';
    final band = widget.stats.accuracy.floor() ~/ 3;
    final accuracyEvent = 'accuracy_${lessonPart}_$band';
    final priorAccuracy = provider.accuracyRecords[widget.lesson.id] ?? 0;
    final wantsLesson = !provider.claimedRewards.contains(lessonEvent);
    final wantsUnit = unit > 0 && !provider.claimedRewards.contains(unitEvent);
    final wantsAccuracy =
        widget.stats.accuracy.floor() >= 80 &&
        widget.stats.accuracy.floor() >= priorAccuracy + 3 &&
        !provider.claimedRewards.contains(accuracyEvent);
    if (!wantsLesson && !wantsUnit && !wantsAccuracy) return;

    setState(() => _checkingRewards = true);
    _encounterController.repeat();
    try {
      if (wantsLesson) {
        final lessonCatch = await provider.claim(
          source: 'lesson',
          eventId: lessonEvent,
          lessonId: widget.lesson.id,
        );
        if (lessonCatch != null) {
          _caught.add(lessonCatch);
          unawaited(ClassroomBridge.instance.spriteDataUrl(lessonCatch.id));
        }
      }
      if (wantsUnit) {
        final unitCatch = await provider.claim(
          source: 'unit',
          eventId: unitEvent,
          unit: unit,
        );
        if (unitCatch != null) {
          _caught.add(unitCatch);
          unawaited(ClassroomBridge.instance.spriteDataUrl(unitCatch.id));
        }
      }
      if (wantsAccuracy) {
        final accuracyCatch = await provider.claim(
          source: 'accuracy',
          eventId: accuracyEvent,
          lessonId: widget.lesson.id,
        );
        if (accuracyCatch != null) {
          _caught.add(accuracyCatch);
          unawaited(ClassroomBridge.instance.spriteDataUrl(accuracyCatch.id));
        }
      }
    } finally {
      if (mounted) {
        _encounterController.stop();
        setState(() => _checkingRewards = false);
      }
    }
    if (!mounted) return;
    if (_caught.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) await _showEncounterDialog(List.of(_caught));
    } else if (provider.error != null &&
        provider.error!.contains('timed out')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The encounter could not connect. Your catch is saved—complete this lesson again to recover the reveal.',
          ),
        ),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_checkingRewards) return;
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.keyN) {
      _goNextLesson();
    } else if (key == LogicalKeyboardKey.keyR) {
      _retryLesson();
    } else if (key == LogicalKeyboardKey.escape) {
      context.pop();
    }
  }

  /// The next lesson to offer — only when this one was passed (a failed
  /// attempt leaves the next lesson locked).
  Lesson? get _nextLesson {
    if (_passed == false) return null;
    return LessonCurriculum.nextLesson(widget.lesson.id);
  }

  void _goNextLesson() {
    final nextLesson = _nextLesson;
    if (nextLesson != null) {
      context.pushReplacement('/lesson/${nextLesson.id}');
    }
  }

  void _retryLesson() {
    context.pushReplacement('/lesson/${widget.lesson.id}');
  }

  /// Whether this attempt met the lesson's passing accuracy.
  /// Null for dynamic practice lessons that aren't part of the curriculum.
  bool? get _passed {
    if (LessonCurriculum.byId(widget.lesson.id) == null) return null;
    return widget.stats.accuracy >= widget.lesson.passingAccuracy;
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _slideController.dispose();
    _encounterController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape = constraints.maxWidth > 860;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 40 : 24,
                      vertical: isLandscape ? 12 : 24,
                    ),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _slideController,
                        child: isLandscape
                            ? _buildLandscapeResults(context)
                            : Column(
                                children: [
                                  const SizedBox(height: 20),
                                  _buildEmoji(),
                                  const SizedBox(height: 16),
                                  _buildTitle(),
                                  const SizedBox(height: 8),
                                  _buildEncouragement(),
                                  if (_passed != null) ...[
                                    const SizedBox(height: 12),
                                    _buildPassBanner(),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildStars(),
                                  const SizedBox(height: 32),
                                  _buildStatsGrid(),
                                  const SizedBox(height: 32),
                                  _buildActionButtons(context),
                                  const SizedBox(height: 20),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.accent,
                  AppColors.starFilled,
                  AppColors.primaryLight,
                  AppColors.accentLight,
                ],
                numberOfParticles: 30,
                gravity: 0.2,
              ),
            ),
            if (_checkingRewards) _buildEncounterLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeResults(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: celebration + stats
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildEmoji(),
              const SizedBox(height: 8),
              _buildTitle(),
              const SizedBox(height: 6),
              _buildEncouragement(),
              if (_passed != null) ...[
                const SizedBox(height: 10),
                _buildPassBanner(),
              ],
              const SizedBox(height: 12),
              _buildStars(),
              const SizedBox(height: 16),
              _buildStatsGrid(),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right: action buttons
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildActionButtons(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEmoji() {
    final emoji = switch (widget.stats.starRating) {
      5 => '🏆',
      4 => '🌟',
      3 => '🎉',
      2 => '👏',
      _ => '💪',
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Text(emoji, style: const TextStyle(fontSize: 80)),
        );
      },
    );
  }

  Widget _buildEncounterLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA152238),
        child: Center(
          child: Card(
            elevation: 18,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RotationTransition(
                    turns: _encounterController,
                    child: const _Pokeball(size: 84),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'A wild Pokémon is nearby…',
                    style: GoogleFonts.fredoka(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preparing your encounter!',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEncounterDialog(List<PokemonSpecies> catches) {
    final plural = catches.length > 1;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFFFFFBEC),
        title: Text(
          'Gotcha! 🎉',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 14,
                children: catches
                    .map(
                      (pokemon) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PokemonSprite(pokemon.id, size: 112),
                          Text(
                            pokemon.name,
                            style: GoogleFonts.fredoka(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                plural
                    ? 'These Pokémon joined your classroom team!'
                    : '${catches.first.name} joined your classroom team!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(Icons.explore_rounded, color: Colors.white),
            label: Text(
              'Continue Adventure',
              style: GoogleFonts.fredoka(fontSize: 18, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    final title = switch (widget.stats.starRating) {
      5 => 'PERFECT!',
      4 => 'AWESOME!',
      3 => 'GREAT JOB!',
      2 => 'GOOD TRY!',
      _ => 'KEEP GOING!',
    };

    return Text(
      title,
      style: GoogleFonts.fredoka(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildEncouragement() {
    return Text(
      widget.stats.encouragementMessage,
      style: GoogleFonts.nunito(fontSize: 18, color: AppColors.textSecondary),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStars() {
    return StarRating(rating: widget.stats.starRating, size: 48, animate: true);
  }

  Widget _buildPassBanner() {
    final passed = _passed!;
    final color = passed ? AppColors.correct : AppColors.warning;
    final message = passed
        ? 'Lesson passed! The next one is unlocked. 🎈'
        : 'Reach ${widget.lesson.passingAccuracy}% accuracy to pass — try again!';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.lesson.title,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _ResultStat(
                  emoji: '🎯',
                  label: 'Accuracy',
                  value: '${widget.stats.accuracy.toStringAsFixed(1)}%',
                  color: widget.stats.accuracy >= 90
                      ? AppColors.correct
                      : widget.stats.accuracy >= 70
                      ? AppColors.warning
                      : AppColors.incorrect,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ResultStat(
                  emoji: '⚡',
                  label: 'Speed',
                  value: '${widget.stats.wpm.toStringAsFixed(0)} WPM',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultStat(
                  emoji: '⏱️',
                  label: 'Time',
                  value: _formatDuration(widget.stats.elapsed),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ResultStat(
                  emoji: '✅',
                  label: 'Correct',
                  value:
                      '${widget.stats.correctCharacters}/${widget.stats.totalCharacters}',
                  color: AppColors.correct,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final nextLesson = _nextLesson;

    return Column(
      children: [
        // Next lesson (primary action)
        if (nextLesson != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _goNextLesson(),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Next: ${nextLesson.emoji} ${nextLesson.title}',
                        style: GoogleFonts.fredoka(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShortcutBadge('Enter', light: true),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        // Try again
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _retryLesson(),
            icon: const Icon(Icons.replay_rounded, color: Colors.white),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Try Again',
                  style: GoogleFonts.fredoka(fontSize: 20, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ShortcutBadge('R', light: true),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              context.pop();
            },
            icon: const Icon(Icons.home_rounded),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Back', style: GoogleFonts.fredoka(fontSize: 20)),
                const SizedBox(width: 8),
                ShortcutBadge('Esc'),
              ],
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ResultStat extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pokeball extends StatelessWidget {
  final double size;

  const _Pokeball({required this.size});

  @override
  Widget build(BuildContext context) {
    final border = size * 0.075;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFF152238), width: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: size / 2, color: AppColors.primary),
          ),
          Container(height: border * 1.15, color: const Color(0xFF152238)),
          Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF152238),
                width: border * 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
