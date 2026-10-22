import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// The Pull Print mark: a page with text lines on the primary blue.
/// Placeholder until the organisation supplies its own logo.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36, size.height / 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 36, 36), const Radius.circular(9)),
      Paint()..color = AppColors.primary,
    );
    const r = Radius.circular(1);
    final page = Path()
      ..moveTo(11, 8)
      ..lineTo(21, 8)
      ..lineTo(26, 13)
      ..lineTo(26, 27)
      ..arcToPoint(const Offset(25, 28), radius: r)
      ..lineTo(11, 28)
      ..arcToPoint(const Offset(10, 27), radius: r)
      ..lineTo(10, 9)
      ..arcToPoint(const Offset(11, 8), radius: r)
      ..close();
    canvas.drawPath(page, Paint()..color = Colors.white);
    final fold = Path()
      ..moveTo(21, 8)
      ..lineTo(21, 13)
      ..lineTo(26, 13)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFB9D6F2));
    final line = Paint()..color = AppColors.primary;
    for (final l in const [
      Rect.fromLTWH(13, 17, 10, 1.8),
      Rect.fromLTWH(13, 21, 10, 1.8),
      Rect.fromLTWH(13, 25, 6, 1.8),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(l, const Radius.circular(0.9)), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
