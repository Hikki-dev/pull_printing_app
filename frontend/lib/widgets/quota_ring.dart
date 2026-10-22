import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../utils/theme.dart';

/// Ring showing pages left this month, for use on the navy header.
class QuotaRing extends StatelessWidget {
  final QuotaInfo quota;
  final double size;

  const QuotaRing({super.key, required this.quota, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final fraction = quota.total == 0 ? 0.0 : quota.left / quota.total;
    return Semantics(
      label: '${quota.left} of ${quota.total} pages left',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) => CustomPaint(
              painter: _RingPainter(value),
              child: child,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${quota.left}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'pages left',
                    style: TextStyle(color: AppColors.onNavyMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = AppColors.ringTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..color = AppColors.ringFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, fill);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction;
}
