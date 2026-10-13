import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
          child: IgnorePointer(child: _SvgHandOverlay(activeKey: activeKey)),
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

class _SvgHandOverlay extends StatefulWidget {
  final String? activeKey;

  const _SvgHandOverlay({required this.activeKey});

  @override
  State<_SvgHandOverlay> createState() => _SvgHandOverlayState();
}

class _SvgHandOverlayState extends State<_SvgHandOverlay> {
  late final Future<String> _source = rootBundle.loadString(
    'assets/images/vkeyboardhand_hand.svg',
  );

  static const _poseNames = <String, String>{
    ' ': 'space',
    '`': 'tilda',
    '-': 'minus',
    '=': 'equal',
    '[': 'left-center-bracket',
    ']': 'right-center-bracket',
    '\\': 'backslash',
    ';': 'semicolon',
    "'": 'single-quote',
    ',': 'comma',
    '.': 'dot',
    '/': 'slash',
  };

  String _showGroup(String source, String id) {
    return source.replaceFirst(
      '<g id="$id" style="display: none"',
      '<g id="$id" style="display: inline"',
    );
  }

  String _pose(String source) {
    var result = _showGroup(source, 'hand-neutral-left');
    result = _showGroup(result, 'hand-neutral-right');
    final raw = widget.activeKey;
    if (raw == null || raw.isEmpty) return result;
    final key = KeyboardData.baseKey(raw);
    final pose = _poseNames[key] ?? key.toLowerCase();
    return _showGroup(result, 'hand-$pose');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _source,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  height: width * 380 / 716.3,
                  child: SvgPicture.string(
                    _pose(snapshot.data!),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
