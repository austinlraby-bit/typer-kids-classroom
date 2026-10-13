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
            child: CustomPaint(
              painter: _KeyboardHandsPainter(
                keySize: keySize,
                gap: _gap,
                padding: _padding,
                activeKey: activeKey,
              ),
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

class _KeyboardHandsPainter extends CustomPainter {
  final double keySize;
  final double gap;
  final double padding;
  final String? activeKey;

  const _KeyboardHandsPainter({
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

  Offset _keyCenter(Size size, String rawKey) {
    final key = KeyboardData.baseKey(rawKey);
    if (key == ' ') {
      return Offset(size.width / 2, _rowY(4));
    }
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

  double _rowY(int row) {
    final rowHeight = keySize + gap * 2;
    return padding + row * (rowHeight + gap) + gap + keySize / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final activeFinger = activeKey == null
        ? null
        : KeyboardData.keyToFinger[KeyboardData.baseKey(activeKey!)];
    final skin = const Color(0xFFFFC98C);
    final outline = const Color(0xFFB96F35);
    final activeColor = activeFinger == null
        ? AppColors.secondary
        : KeyboardData.fingerColor(activeFinger);

    final leftHome = [_keyCenter(size, 'a'), _keyCenter(size, 'f')];
    final rightHome = [_keyCenter(size, 'j'), _keyCenter(size, ';')];
    final baseY = _rowY(3) + keySize * 0.92;
    final palmY = math.min(
      size.height + keySize * 0.18,
      baseY + keySize * 0.78,
    );
    final leftPalmX = (leftHome.first.dx + leftHome.last.dx) / 2;
    final rightPalmX = (rightHome.first.dx + rightHome.last.dx) / 2;
    _drawPalm(
      canvas,
      Offset(leftPalmX, palmY),
      keySize * 4.45,
      keySize * 1.85,
      skin,
      outline,
    );
    _drawPalm(
      canvas,
      Offset(rightPalmX, palmY),
      keySize * 4.45,
      keySize * 1.85,
      skin,
      outline,
    );

    final entries = _homeKeys.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final home = _keyCenter(size, entry.value);
      final isActive = activeFinger == entry.key;
      final target = isActive && activeKey != null
          ? _keyCenter(size, activeKey!)
          : home;
      final base = Offset(home.dx, baseY);
      _drawFinger(
        canvas,
        base,
        target,
        keySize * (isActive ? 0.48 : 0.42),
        skin,
        outline,
        isActive ? activeColor : null,
      );
    }

    if (activeFinger == 'thumb') {
      final space = _keyCenter(size, ' ');
      _drawFinger(
        canvas,
        Offset(leftPalmX + keySize * 1.35, palmY - keySize * 0.42),
        space - Offset(keySize * 0.42, 0),
        keySize * 0.46,
        skin,
        outline,
        activeColor,
      );
    }
  }

  void _drawPalm(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color skin,
    Color outline,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(height * 0.38),
    );
    canvas.drawRRect(rect, Paint()..color = skin.withValues(alpha: 0.15));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = outline.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawFinger(
    Canvas canvas,
    Offset base,
    Offset tip,
    double width,
    Color skin,
    Color outline,
    Color? active,
  ) {
    final control = Offset((base.dx + tip.dx) / 2, (base.dy + tip.dy) / 2);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
    if (active != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = active.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = (active ?? skin).withValues(
          alpha: active == null ? 0.16 : 0.42,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = (active ?? outline).withValues(
          alpha: active == null ? 0.24 : 0.72,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _KeyboardHandsPainter oldDelegate) =>
      oldDelegate.activeKey != activeKey || oldDelegate.keySize != keySize;
}
