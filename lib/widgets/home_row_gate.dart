import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../providers/profile_provider.dart';
import 'finger_guide.dart';
import 'keyboard_widget.dart';

/// A brief, shared posture reminder shown roughly once every three activities.
class HomeRowGate extends StatefulWidget {
  final Widget child;
  final bool forceShow;
  final VoidCallback? onComplete;

  const HomeRowGate({
    super.key,
    required this.child,
    this.forceShow = false,
    this.onComplete,
  });

  static Future<bool> _isDue(BuildContext context) async {
    final profileId =
        context.read<ProfileProvider>().activeProfileId ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final key = 'profile_${profileId}_home_row_activity_launch_count';
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next == 1 || next % 3 == 0;
  }

  /// Runs the posture check, when due, immediately before typing begins.
  static Future<void> showIfDue(BuildContext context) async {
    if (!await _isDue(context) || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => HomeRowGate(
          forceShow: true,
          onComplete: () => Navigator.of(routeContext).pop(),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  State<HomeRowGate> createState() => _HomeRowGateState();
}

class _HomeRowGateState extends State<HomeRowGate> {
  static const _sequence = 'asdfjkl;';
  final _focusNode = FocusNode();
  bool? _showCheck;
  int _position = 0;
  bool _mistake = false;

  @override
  void initState() {
    super.initState();
    _decideWhetherToShow();
  }

  Future<void> _decideWhetherToShow() async {
    final shouldShow = widget.forceShow || await HomeRowGate._isDue(context);
    if (!mounted) return;
    setState(() => _showCheck = shouldShow);
    if (_showCheck == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final typed = event.character?.toLowerCase();
    if (typed == null || typed.isEmpty) return;
    if (typed != _sequence[_position]) {
      setState(() => _mistake = true);
      return;
    }
    final next = _position + 1;
    setState(() {
      _position = next;
      _mistake = false;
    });
    if (next == _sequence.length) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          setState(() => _showCheck = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCheck == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showCheck == false) return widget.child;

    final complete = _position >= _sequence.length;
    final currentKey = complete ? null : _sequence[_position];
    final completedKeys = _sequence.substring(0, _position).split('').toSet();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trainer Ready Check')),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: _focusNode.requestFocus,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pad = constraints.maxWidth > 800 ? 32.0 : 16.0;
                final compactHeight = constraints.maxHeight < 700;
                final keySize = ((constraints.maxWidth - pad * 2) / 15).clamp(
                  28.0,
                  64.0,
                );
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              complete
                                  ? 'Ready for adventure!'
                                  : 'Find home row',
                              style: GoogleFonts.fredoka(
                                fontSize: compactHeight ? 28 : 32,
                                fontWeight: FontWeight.w700,
                                color: complete
                                    ? AppColors.correct
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              complete
                                  ? 'Great finger placement!'
                                  : 'Rest your fingers on A S D F   J K L ;\nPress each highlighted key once.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: compactHeight ? 16 : 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 7,
                              children: List.generate(_sequence.length, (i) {
                                final done = i < _position;
                                final active = i == _position;
                                return Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: done
                                        ? AppColors.correct
                                        : active
                                        ? AppColors.secondary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: active
                                          ? AppColors.secondary
                                          : Colors.grey.shade300,
                                      width: active ? 3 : 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    done ? '✓' : _sequence[i].toUpperCase(),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: done || active
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 22,
                              child: _mistake
                                  ? Text(
                                      'Try the highlighted key.',
                                      style: GoogleFonts.nunito(
                                        color: AppColors.incorrect,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(height: compactHeight ? 18 : 12),
                          ],
                        ),
                      ),
                    ),
                    if (currentKey != null) FingerGuide(currentKey: currentKey),
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                      child: KeyboardWidget(
                        activeKey: currentKey,
                        correctKeys: completedKeys,
                        showFingerColors: true,
                        keySize: keySize,
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
}
