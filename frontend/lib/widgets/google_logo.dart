import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The four-colour Google "G", drawn from arcs. Swap for Google's own asset
/// before release.
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 21});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _GPainter()),
        ),
      );
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - w / 2,
    );
    double rad(double deg) => deg * math.pi / 180;
    void arc(Color color, double from, double to) => canvas.drawArc(
          rect,
          rad(from),
          rad(to - from),
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w,
        );

    // Angles run clockwise from 3 o'clock; the gap on the right is the mouth of the G.
    arc(const Color(0xFFEA4335), 215, 315);
    arc(const Color(0xFFFBBC05), 135, 215);
    arc(const Color(0xFF34A853), 45, 135);
    arc(const Color(0xFF4285F4), 0, 45);
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, size.height / 2 - w / 2, size.width / 2, w),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Sign in with Google" in Google's sign-in button style.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1F1F);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, height),
          backgroundColor: Colors.white,
          foregroundColor: ink,
          disabledForegroundColor: ink,
          side: const BorderSide(color: Color(0xFF747775)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: ink),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleLogo(),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Sign in with Google',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
