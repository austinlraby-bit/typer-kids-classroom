import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/sound_manager.dart';
import '../core/theme/app_colors.dart';
import '../data/practice_generator.dart';
import '../models/lesson.dart';
import '../providers/progress_provider.dart';
import '../providers/typing_provider.dart';
import '../widgets/finger_guide.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/quit_dialog.dart';
import '../widgets/stat_tiles.dart';
import '../widgets/typing_display.dart';

/// The main typing practice screen where kids do the actual typing exercises
class TypingScreen extends StatefulWidget {
  final Lesson lesson;

  const TypingScreen({super.key, required this.lesson});

  @override
  State<TypingScreen> createState() => _TypingScreenState();
}

class _TypingScreenState extends State<TypingScreen> {
  static const _homeRowCheck = 'asdfjkl;';

  late TypingProvider _typingProvider;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _introFocusNode = FocusNode();
  final _sfx = SoundManager();
  bool _showIntro = true;
  bool _showHomeRowCheck = false;
  int _homeRowPosition = 0;
  bool _homeRowMistake = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _typingProvider = TypingProvider();
    _typingProvider.startLesson(widget.lesson);

    // Track that user started this lesson (dynamic practice lessons aren't
    // part of the curriculum flow, so they can't be "resumed")
    if (widget.lesson.id != PracticeGenerator.trickyKeysLessonId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ProgressProvider>(
            context,
            listen: false,
          ).setLastLesson(widget.lesson.id);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _introFocusNode.dispose();
    _typingProvider.dispose();
    super.dispose();
  }

  void _startLesson() {
    setState(() {
      _showIntro = false;
      _showHomeRowCheck = false;
      _homeRowPosition = 0;
      _homeRowMistake = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleIntroKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _startLesson();
    } else if (key == LogicalKeyboardKey.escape) {
      context.pop();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _showQuitDialog();
      return;
    }

    if (_showHomeRowCheck) {
      _handleHomeRowKey(event);
      return;
    }

    if (_typingProvider.isFinished) return;
    if (_typingProvider.isPaused) return;
    if (_isTransitioning) return; // Ignore input during exercise transition

    final key = event.character;
    if (key != null && key.isNotEmpty) {
      final correct = _typingProvider.onKeyPressed(key);
      if (correct == true) {
        _sfx.playKeystroke();
      } else if (correct == false) {
        _sfx.playIncorrect();
      }

      // If exercise complete but not last, auto advance after a brief moment
      if (_typingProvider.isExerciseComplete && !_typingProvider.isFinished) {
        _isTransitioning = true;
        _typingProvider.pause();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _typingProvider.nextExercise();
            setState(() {
              _showHomeRowCheck = false;
              _homeRowPosition = 0;
              _homeRowMistake = false;
              _isTransitioning = false;
            });
            _typingProvider.resume();
            _focusNode.requestFocus();
          }
        });
      }

      // If lesson finished, navigate to results
      if (_typingProvider.isFinished) {
        _navigateToResults();
      }
    }
  }

  void _handleHomeRowKey(KeyEvent event) {
    final typed = event.character?.toLowerCase();
    if (typed == null || typed.isEmpty) return;

    final expected = _homeRowCheck[_homeRowPosition];
    if (typed != expected) {
      setState(() => _homeRowMistake = true);
      _sfx.playIncorrect();
      return;
    }

    _sfx.playKeystroke();
    final nextPosition = _homeRowPosition + 1;
    if (nextPosition == _homeRowCheck.length) {
      setState(() {
        _homeRowPosition = nextPosition;
        _homeRowMistake = false;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _showHomeRowCheck = false);
        _typingProvider.resume();
        _focusNode.requestFocus();
      });
    } else {
      setState(() {
        _homeRowPosition = nextPosition;
        _homeRowMistake = false;
      });
    }
  }

  Future<void> _navigateToResults() async {
    final stats = _typingProvider.stats;
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    await progressProvider.recordAttempt(widget.lesson, stats);
    _sfx.playCelebration();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.pushReplacement(
          '/lesson/${widget.lesson.id}/results',
          extra: (widget.lesson, stats),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return _buildIntroScreen();
    }

    return ListenableBuilder(
      listenable: _typingProvider,
      builder: (context, _) => _buildTypingScreen(),
    );
  }

  Widget _buildIntroScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: KeyboardListener(
        focusNode: _introFocusNode,
        autofocus: true,
        onKeyEvent: _handleIntroKeyEvent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.lesson.emoji,
                    style: const TextStyle(fontSize: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.lesson.title,
                    style: GoogleFonts.fredoka(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.lesson.description,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.lesson.funTip.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.secondaryLight.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.lesson.funTip,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.lesson.focusKeys.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildFocusKeysPreview(),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    '${widget.lesson.exercises.length} exercises',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 240,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _startLesson(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Let's Go!",
                            style: GoogleFonts.fredoka(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Enter',
                              style: GoogleFonts.robotoMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Go Back',
                          style: GoogleFonts.nunito(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            'Esc',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFocusKeysPreview() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: widget.lesson.focusKeys.map((key) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Center(
            child: Text(
              key.toUpperCase(),
              style: GoogleFonts.robotoMono(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypingScreen() {
    if (_showHomeRowCheck) return _buildHomeRowCheckScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.lesson.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showQuitDialog(),
        ),
        actions: [
          // Exercise progress
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_typingProvider.currentExerciseIndex + 1}/${_typingProvider.totalExercises}',
                style: GoogleFonts.fredoka(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Compute responsive sizes based on available space
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;

                // The keyboard is ~14.5 keys wide (13 keys + padding + offsets)
                // Calculate key size to fill available width with some margin
                final keyboardWidthKeys = 15.0; // effective key-width-units
                final horizontalPad = maxW > 800 ? 32.0 : 16.0;
                final availableWidth = maxW - horizontalPad * 2;
                final keySizeFromWidth = (availableWidth / keyboardWidthKeys)
                    .clamp(28.0, 64.0);

                // Also constrain by height: keyboard ~6 keys tall, plus stats + display + guides
                final keySizeFromHeight = ((maxH * 0.38) / 6).clamp(28.0, 64.0);

                final keySize = keySizeFromWidth < keySizeFromHeight
                    ? keySizeFromWidth
                    : keySizeFromHeight;

                // Text size scales with key size — generous for readability
                final textFontSize = (keySize * 0.9).clamp(22.0, 48.0);
                final isShort = maxH < 550;
                final vPad = isShort ? 4.0 : 8.0;

                return Column(
                  children: [
                    // Live stats bar
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPad,
                        vertical: vPad,
                      ),
                      child: _buildLiveStats(),
                    ),
                    SizedBox(height: isShort ? 2 : 8),
                    // Text to type — takes available remaining space
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPad,
                        ),
                        child: Center(
                          child: TypingDisplay(
                            text: _typingProvider.currentText,
                            charStates: _typingProvider.charStates,
                            cursorPosition: _typingProvider.cursorPosition,
                            fontSize: textFontSize,
                          ),
                        ),
                      ),
                    ),
                    // "Click here to type" prompt
                    if (!_focusNode.hasFocus)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildFocusPrompt(),
                      ),
                    // Keep the hand cue visually attached to the keyboard,
                    // like established typing tutors do.
                    if (!isShort)
                      FingerGuide(currentKey: _typingProvider.currentChar),
                    // Virtual keyboard — pinned to bottom
                    Padding(
                      padding: EdgeInsets.only(
                        left: horizontalPad,
                        right: horizontalPad,
                        bottom: isShort ? 4 : 12,
                      ),
                      child: Center(
                        child: KeyboardWidget(
                          activeKey: _typingProvider.currentChar,
                          showFingerColors: true,
                          keySize: keySize,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeRowCheckScreen() {
    final isComplete = _homeRowPosition >= _homeRowCheck.length;
    final currentKey = isComplete ? null : _homeRowCheck[_homeRowPosition];
    final completedKeys = _homeRowCheck
        .substring(0, _homeRowPosition.clamp(0, _homeRowCheck.length))
        .split('')
        .toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Home-Row Check'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showQuitDialog(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Exercise ${_typingProvider.currentExerciseIndex + 1}',
                style: GoogleFonts.fredoka(fontSize: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPad = constraints.maxWidth > 800 ? 32.0 : 16.0;
                final availableWidth = constraints.maxWidth - horizontalPad * 2;
                final keySize = (availableWidth / 15).clamp(28.0, 64.0);
                final compactHeight = constraints.maxHeight < 700;

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isComplete ? 'Ready to type!' : 'Find home row',
                                style: GoogleFonts.fredoka(
                                  fontSize: compactHeight ? 28 : 32,
                                  fontWeight: FontWeight.w700,
                                  color: isComplete
                                      ? AppColors.correct
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isComplete
                                    ? 'Great finger placement!'
                                    : 'Rest your fingers on A S D F   J K L ;\nThen press each highlighted key.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: compactHeight ? 16 : 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildHomeRowProgress(),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: _homeRowMistake
                                    ? Text(
                                        'Keep your fingers planted—press the highlighted key.',
                                        key: const ValueKey('mistake'),
                                        style: GoogleFonts.nunito(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.incorrect,
                                        ),
                                      )
                                    : const SizedBox(height: 22),
                              ),
                              SizedBox(height: compactHeight ? 18 : 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (currentKey != null) FingerGuide(currentKey: currentKey),
                    Padding(
                      padding: EdgeInsets.only(
                        left: horizontalPad,
                        right: horizontalPad,
                        bottom: 12,
                      ),
                      child: Center(
                        child: KeyboardWidget(
                          activeKey: currentKey,
                          correctKeys: completedKeys,
                          showFingerColors: true,
                          keySize: keySize,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeRowProgress() {
    return Wrap(
      spacing: 7,
      alignment: WrapAlignment.center,
      children: List.generate(_homeRowCheck.length, (index) {
        final done = index < _homeRowPosition;
        final active = index == _homeRowPosition;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: done
                ? AppColors.correct
                : active
                ? AppColors.secondary
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: done
                  ? AppColors.correct
                  : active
                  ? AppColors.secondary
                  : Colors.grey.shade300,
              width: active ? 3 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              done ? '✓' : _homeRowCheck[index].toUpperCase(),
              style: GoogleFonts.robotoMono(
                fontSize: done ? 22 : 20,
                fontWeight: FontWeight.w700,
                color: done || active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLiveStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          LiveStatItem(
            icon: Icons.timer_outlined,
            label: 'Time',
            value: _formatDuration(_typingProvider.elapsed),
            color: AppColors.primary,
          ),
          LiveStatItem(
            icon: Icons.speed_rounded,
            label: 'WPM',
            value: _typingProvider.liveWpm.toStringAsFixed(0),
            color: AppColors.secondary,
          ),
          LiveStatItem(
            icon: Icons.gps_fixed_rounded,
            label: 'Accuracy',
            value: '${_typingProvider.liveAccuracy.toStringAsFixed(0)}%',
            color: _typingProvider.liveAccuracy >= 90
                ? AppColors.correct
                : _typingProvider.liveAccuracy >= 70
                ? AppColors.warning
                : AppColors.incorrect,
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPrompt() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mouse_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Click here and start typing!',
            style: GoogleFonts.fredoka(
              fontSize: 16,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQuitDialog() {
    _typingProvider.pause();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => QuitDialog(
        title: 'Leave Lesson?',
        message: 'Your progress on this exercise will not be saved.',
        onStay: () => Navigator.of(dialogContext).pop(),
        onQuit: () {
          Navigator.of(dialogContext).pop();
          context.pop();
        },
      ),
    ).then((_) {
      // Restore focus to typing area after dialog closes
      if (mounted && !_showIntro) {
        _typingProvider.resume();
        _focusNode.requestFocus();
      }
    });
  }
}
