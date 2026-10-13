import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../data/keyboard_data.dart';

/// A visual on-screen keyboard that highlights active keys and shows
/// color-coded finger zones to help kids learn proper finger placement.
class KeyboardWidget extends StatelessWidget {
  /// The key that should currently be pressed (highlighted)
  final String? activeKey;

  /// Keys that were pressed correctly (shown green)
  final Set<String> correctKeys;

  /// Keys that were pressed incorrectly (shown red)
  final Set<String> incorrectKeys;

  /// Whether to show finger color zones
  final bool showFingerColors;

  /// Size of each key in pixels. Scales the entire keyboard.
  final double keySize;
  final bool showHandOverlay;

  const KeyboardWidget({
    super.key,
    this.activeKey,
    this.correctKeys = const {},
    this.incorrectKeys = const {},
    this.showFingerColors = true,
    this.keySize = 40,
    this.showHandOverlay = false,
  });

  double get _gap => (keySize * 0.05).clamp(2, 4);
  double get _fontSize => (keySize * 0.35).clamp(10, 22);
  double get _borderRadius => (keySize * 0.2).clamp(6, 14);
  double get _padding => (keySize * 0.3).clamp(8, 20);

  @override
  Widget build(BuildContext context) {
    final keyboard = Container(
      padding: EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Number row
          _buildRow(KeyboardData.keyboardRows[0]),
          SizedBox(height: _gap),
          // Top row (QWERTY)
          Padding(
            padding: EdgeInsets.only(left: keySize * 0.5),
            child: _buildRow(KeyboardData.keyboardRows[1]),
          ),
          SizedBox(height: _gap),
          // Home row (ASDF)
          Padding(
            padding: EdgeInsets.only(left: keySize * 0.8),
            child: _buildRow(KeyboardData.keyboardRows[2]),
          ),
          SizedBox(height: _gap),
          // Bottom row (ZXCV)
          Padding(
            padding: EdgeInsets.only(left: keySize * 1.25),
            child: _buildRow(KeyboardData.keyboardRows[3]),
          ),
          SizedBox(height: _gap),
          // Space bar
          _buildSpaceBar(),
        ],
      ),
    );
    if (!showHandOverlay) return keyboard;
    return Stack(
      alignment: Alignment.center,
      children: [
        keyboard,
        Positioned.fill(
          child: IgnorePointer(
            child: _LayeredGloveOverlay(
              keySize: keySize,
              gap: _gap,
              padding: _padding,
              activeKey: activeKey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    final isActive =
        activeKey != null &&
        KeyboardData.baseKey(activeKey!) == key.toLowerCase();
    final isCorrect = correctKeys.contains(key.toLowerCase());
    final isIncorrect = incorrectKeys.contains(key.toLowerCase());
    final isHomeRow = KeyboardData.homeRowKeys.contains(key.toLowerCase());

    Color bgColor;
    if (isActive) {
      bgColor = AppColors.secondary;
    } else if (isCorrect) {
      bgColor = AppColors.correct.withValues(alpha: 0.7);
    } else if (isIncorrect) {
      bgColor = AppColors.incorrect.withValues(alpha: 0.7);
    } else if (showFingerColors) {
      bgColor = KeyboardData.colorForKey(key).withValues(alpha: 0.4);
    } else {
      bgColor = Colors.white;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: keySize,
      height: keySize,
      margin: EdgeInsets.all(_gap),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(
          color: isActive
              ? AppColors.secondary
              : isHomeRow
              ? AppColors.primaryDark.withValues(alpha: 0.5)
              : Colors.grey.shade400,
          width: isActive
              ? 2.5
              : isHomeRow
              ? 2
              : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          KeyboardData.displayLabel(key),
          style: GoogleFonts.robotoMono(
            fontSize: _fontSize,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceBar() {
    final isActive = activeKey == ' ';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: keySize * 6.5,
      height: keySize,
      margin: EdgeInsets.all(_gap),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.secondary
            : showFingerColors
            ? AppColors.fingerThumb.withValues(alpha: 0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(
          color: isActive ? AppColors.secondary : Colors.grey.shade400,
          width: isActive ? 2.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          'SPACE',
          style: GoogleFonts.robotoMono(
            fontSize: _fontSize * 0.85,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _LayeredGloveOverlay extends StatelessWidget {
  final double keySize;
  final double gap;
  final double padding;
  final String? activeKey;

  const _LayeredGloveOverlay({
    required this.keySize,
    required this.gap,
    required this.padding,
    required this.activeKey,
  });

  static const _homeKeys = <String, String>{
    'left-pinky': 'a',
    'left-ring': 's',
    'left-middle': 'd',
    'left-index': 'f',
    'right-index': 'j',
    'right-middle': 'k',
    'right-ring': 'l',
    'right-pinky': ';',
  };

  double _rowY(int row) {
    final rowHeight = keySize + gap * 2;
    return padding + row * (rowHeight + gap) + gap + keySize / 2;
  }

  Offset _keyCenter(Size size, String rawKey) {
    final key = KeyboardData.baseKey(rawKey);
    if (key == ' ') return Offset(size.width / 2, _rowY(4));
    for (var row = 0; row < 4; row++) {
      final keys = KeyboardData.keyboardRows[row];
      final index = keys.indexOf(key);
      if (index < 0) continue;
      final indent = switch (row) {
        1 => keySize * 0.5,
        2 => keySize * 0.8,
        3 => keySize * 1.25,
        _ => 0.0,
      };
      final unit = keySize + gap * 2;
      final rowWidth = keys.length * unit + indent;
      final left = (size.width - rowWidth) / 2 + indent;
      return Offset(left + gap + keySize / 2 + index * unit, _rowY(row));
    }
    return Offset(size.width / 2, _rowY(2));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final activeFinger = activeKey == null
            ? null
            : KeyboardData.keyToFinger[KeyboardData.baseKey(activeKey!)];
        final fingers = <Widget>[];
        for (final entry in _homeKeys.entries) {
          final home = _keyCenter(size, entry.value);
          final active = activeFinger == entry.key && activeKey != null;
          final target = active ? _keyCenter(size, activeKey!) : home;
          final base = Offset(home.dx, _rowY(2) + keySize * 1.28);
          fingers.add(_finger(base: base, tip: target, active: active));
        }
        if (activeFinger == 'thumb') {
          final target = _keyCenter(size, ' ');
          fingers.add(
            _finger(
              base: Offset(size.width / 2 - keySize * 0.75, _rowY(3)),
              tip: target - Offset(keySize * 0.45, 0),
              active: true,
            ),
          );
        }
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ...fingers,
              Positioned(
                left: size.width / 2 - keySize * 5.0,
                top: _rowY(2) + keySize * 0.95,
                width: keySize * 10,
                height: keySize * 5,
                child: Opacity(
                  opacity: 0.24,
                  child: Image.asset(
                    'assets/images/typing_glove_palms.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _finger({
    required Offset base,
    required Offset tip,
    required bool active,
  }) {
    final delta = tip - base;
    final length = delta.distance + keySize * 0.16;
    final angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    final width = keySize * (active ? 0.48 : 0.38);
    return Positioned(
      left: base.dx - width / 2,
      top: base.dy - length,
      width: width,
      height: length,
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: active ? 0.52 : 0.18,
          child: Image.asset(
            'assets/images/typing_glove_finger.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
