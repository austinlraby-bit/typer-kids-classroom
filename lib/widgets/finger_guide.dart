import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../data/keyboard_data.dart';

/// Shows which finger to use for the current key, with a visual hand diagram
/// that highlights the correct finger above the keyboard.
class FingerGuide extends StatelessWidget {
  final String? currentKey;

  const FingerGuide({super.key, this.currentKey});

  @override
  Widget build(BuildContext context) {
    if (currentKey == null) return const SizedBox.shrink();

    final finger = KeyboardData.keyToFinger[currentKey!.toLowerCase()];
    if (finger == null) return const SizedBox.shrink();

    final fingerName = KeyboardData.fingerNameForKey(currentKey!);
    final fingerColor = KeyboardData.fingerColor(finger);
    final isLeft = finger.startsWith('left');
    final isThumb = finger == 'thumb';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hand diagram showing active finger
        SizedBox(
          height: 76,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HandDiagram(
                isLeft: true,
                activeFinger: isLeft ? finger : (isThumb ? 'thumb' : null),
              ),
              const SizedBox(width: 8),
              _HandDiagram(
                isLeft: false,
                activeFinger: !isLeft ? finger : (isThumb ? 'thumb' : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Finger label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: fingerColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fingerColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            fingerName,
            style: GoogleFonts.fredoka(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a single hand (left or right) with fingers as rounded shapes.
/// The active finger is highlighted with a glow.
class _HandDiagram extends StatelessWidget {
  final bool isLeft;
  final String? activeFinger;

  const _HandDiagram({required this.isLeft, this.activeFinger});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(96, 74),
      painter: _HandPainter(isLeft: isLeft, activeFinger: activeFinger),
    );
  }
}

class _HandPainter extends CustomPainter {
  final bool isLeft;
  final String? activeFinger;

  _HandPainter({required this.isLeft, this.activeFinger});

  // Wider, gently angled fingers approximate a relaxed palm-down typing
  // posture. The thumb points inward toward the spacebar instead of standing
  // upright beside the palm.
  static const _leftFingerData = <_FingerSpec>[
    _FingerSpec(0.17, 0.34, 0.38, 15, -0.10, 'left-pinky'),
    _FingerSpec(0.34, 0.13, 0.53, 16, -0.04, 'left-ring'),
    _FingerSpec(0.51, 0.05, 0.61, 17, 0.0, 'left-middle'),
    _FingerSpec(0.68, 0.17, 0.50, 17, 0.05, 'left-index'),
  ];

  static const _rightFingerData = <_FingerSpec>[
    _FingerSpec(0.32, 0.17, 0.50, 17, -0.05, 'right-index'),
    _FingerSpec(0.49, 0.05, 0.61, 17, 0.0, 'right-middle'),
    _FingerSpec(0.66, 0.13, 0.53, 16, 0.04, 'right-ring'),
    _FingerSpec(0.83, 0.34, 0.38, 15, 0.10, 'right-pinky'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fingers = isLeft ? _leftFingerData : _rightFingerData;

    // Draw palm
    final palmRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.58,
        size.width * 0.80,
        size.height * 0.34,
      ),
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: const Radius.circular(9),
      bottomRight: const Radius.circular(9),
    );
    final palmPaint = Paint()
      ..color = const Color(0xFFFFE0B2)
      ..style = PaintingStyle.fill;
    final palmBorder = Paint()
      ..color = const Color(0xFFD7A97A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // Fingers sit behind the palm so their bases join naturally.
    for (final spec in fingers) {
      final isActive = activeFinger == spec.fingerName;
      final color = KeyboardData.fingerColor(spec.fingerName);

      final cx = size.width * spec.centerXFrac;
      final top = size.height * spec.topFrac;
      final h = size.height * spec.heightFrac;
      final w = spec.width.toDouble();

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(w * 0.48),
      );

      canvas.save();
      canvas.translate(cx, top + h / 2);
      canvas.rotate(spec.rotation);

      // Glow for active finger
      if (isActive) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w + 8, height: h + 8),
            Radius.circular((w + 8) / 2),
          ),
          glowPaint,
        );
      }

      // Finger fill
      final fillPaint = Paint()
        ..color = isActive ? color : const Color(0xFFFFE0B2)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, fillPaint);

      // Finger border
      final borderPaint = Paint()
        ..color = isActive
            ? color.withValues(alpha: 0.9)
            : const Color(0xFFD7A97A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 2.0 : 1.2;
      canvas.drawRRect(rect, borderPaint);

      // Fingernail hint
      final nailRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -h / 2 + 7),
          width: w * 0.6,
          height: 7,
        ),
        const Radius.circular(2),
      );
      final nailPaint = Paint()
        ..color = isActive
            ? Colors.white.withValues(alpha: 0.7)
            : const Color(0xFFF5D5B8)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(nailRect, nailPaint);
      canvas.restore();
    }

    canvas.drawRRect(palmRect, palmPaint);
    canvas.drawRRect(palmRect, palmBorder);

    // Angled thumb crossing toward the spacebar.
    final thumbName = 'thumb';
    final thumbActive = activeFinger == thumbName;
    final thumbColor = KeyboardData.fingerColor(thumbName);
    final thumbCenter = Offset(
      size.width * (isLeft ? 0.82 : 0.18),
      size.height * 0.68,
    );
    canvas.save();
    canvas.translate(thumbCenter.dx, thumbCenter.dy);
    canvas.rotate(isLeft ? -0.68 : 0.68);
    final thumb = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 18, height: 40),
      const Radius.circular(9),
    );
    if (thumbActive) {
      canvas.drawRRect(
        thumb,
        Paint()
          ..color = thumbColor.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawRRect(
      thumb,
      Paint()..color = thumbActive ? thumbColor : const Color(0xFFFFE0B2),
    );
    canvas.drawRRect(
      thumb,
      Paint()
        ..color = thumbActive ? thumbColor : const Color(0xFFD7A97A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thumbActive ? 2 : 1.2,
    );
    canvas.restore();

    // Knuckle arcs make the palm read as a hand rather than a mitten.
    final creasePaint = Paint()
      ..color = const Color(0xFFD7A97A).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final x in [0.27, 0.44, 0.61, 0.76]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.61),
          width: 12,
          height: 8,
        ),
        3.35,
        2.7,
        false,
        creasePaint,
      );
    }

    // Hand label
    final labelSpan = TextSpan(
      text: isLeft ? 'L' : 'R',
      style: const TextStyle(
        color: Color(0xFFBE8C5E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    final tp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.76));
  }

  @override
  bool shouldRepaint(covariant _HandPainter oldDelegate) =>
      activeFinger != oldDelegate.activeFinger || isLeft != oldDelegate.isLeft;
}

class _FingerSpec {
  final double centerXFrac;
  final double topFrac;
  final double heightFrac;
  final int width;
  final double rotation;
  final String fingerName;

  const _FingerSpec(
    this.centerXFrac,
    this.topFrac,
    this.heightFrac,
    this.width,
    this.rotation,
    this.fingerName,
  );
}
