import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Temporary brand mark for Multi Mause: a rounded tile with ten cursor dots.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28, this.showGlow = false});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          colors: [Palette.accent, Color(0xFF4AA7D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: showGlow
            ? const [BoxShadow(color: Color(0x6667C7B7), blurRadius: 16, spreadRadius: 1)]
            : const [BoxShadow(color: Color(0x223A6D63), blurRadius: 8)],
      ),
      child: CustomPaint(painter: const _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dot = Paint()..color = Palette.bg;
    final c = Offset(w * 0.5, h * 0.5);
    final r = w * 0.30;
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + (i * 2 * math.pi / 10);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      canvas.drawCircle(p, w * (i == 0 ? 0.055 : 0.035), dot);
    }
    final stem = Paint()
      ..color = Palette.bg
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.34, h * 0.34), Offset(w * 0.66, h * 0.66), stem);
    canvas.drawLine(Offset(w * 0.66, h * 0.66), Offset(w * 0.60, h * 0.42), stem);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
