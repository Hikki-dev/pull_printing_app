import 'package:flutter/material.dart';

/// Flat two-blue printer with a sheet that feeds out of the front slot.
/// Replace with a photo of the real printer once one is available.
class PrinterIllustration extends StatefulWidget {
  final double width;
  const PrinterIllustration({super.key, this.width = 300});

  @override
  State<PrinterIllustration> createState() => _PrinterIllustrationState();
}

class _PrinterIllustrationState extends State<PrinterIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.stop();
      _controller.value = 0.6;
      _started = false;
    } else if (!_started) {
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Printer with a sheet coming out',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.width,
          height: widget.width * 230 / 320,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(painter: _PrinterPainter(_controller.value)),
          ),
        ),
      ),
    );
  }
}

class _PrinterPainter extends CustomPainter {
  _PrinterPainter(this.t);
  final double t;

  Paint _p(int argb, [double opacity = 1]) =>
      Paint()..color = Color(argb).withAlpha((opacity * 255).round());

  void _rr(Canvas c, double x, double y, double w, double h, double r, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 320, size.height / 230);

    canvas.drawOval(
        Rect.fromCenter(center: const Offset(160, 216), width: 264, height: 18), _p(0xFF000000, .22));

    canvas.save();
    canvas.translate(160, 52);
    canvas.rotate(-4 * 3.1415926535 / 180);
    canvas.translate(-160, -52);
    _rr(canvas, 92, 16, 136, 72, 4, _p(0xFFDCE6F1));
    canvas.restore();

    _rr(canvas, 100, 8, 120, 76, 4, _p(0xFFFFFFFF));
    _rr(canvas, 112, 22, 60, 6, 3, _p(0xFFB9C8D8));
    _rr(canvas, 112, 36, 96, 4, 2, _p(0xFFDCE6F1));
    _rr(canvas, 112, 46, 88, 4, 2, _p(0xFFDCE6F1));

    _rr(canvas, 30, 66, 260, 124, 16, _p(0xFF1F4B7A));
    final top = Path()
      ..moveTo(30, 82)
      ..arcToPoint(const Offset(46, 66), radius: const Radius.circular(16))
      ..lineTo(274, 66)
      ..arcToPoint(const Offset(290, 82), radius: const Radius.circular(16))
      ..lineTo(290, 102)
      ..lineTo(30, 102)
      ..close();
    canvas.drawPath(top, _p(0xFF2B5F96));
    _rr(canvas, 52, 104, 76, 16, 3, _p(0xFFCFE3F7));
    canvas.drawCircle(const Offset(240, 112), 4.5, _p(0xFF7FD1FF));
    canvas.drawCircle(const Offset(256, 112), 4.5, _p(0xFFFFFFFF, .45));
    _rr(canvas, 62, 128, 196, 10, 5, _p(0xFF0A1E33));

    // Sheet feeding out of the slot, clipped to the area below it.
    final p = (t / 0.55).clamp(0.0, 1.0);
    final offset = -46 * (1 - Curves.easeInOut.transform(p));
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 134, 320, 100));
    canvas.translate(0, offset);
    _rr(canvas, 80, 134, 160, 78, 3, _p(0xFFFFFFFF));
    _rr(canvas, 94, 150, 70, 6, 3, _p(0xFFB9C8D8));
    _rr(canvas, 94, 164, 130, 4, 2, _p(0xFFDCE6F1));
    _rr(canvas, 94, 174, 116, 4, 2, _p(0xFFDCE6F1));
    _rr(canvas, 94, 184, 124, 4, 2, _p(0xFFDCE6F1));
    canvas.restore();

    _rr(canvas, 50, 188, 34, 12, 3, _p(0xFF0A1E33));
    _rr(canvas, 236, 188, 34, 12, 3, _p(0xFF0A1E33));
  }

  @override
  bool shouldRepaint(covariant _PrinterPainter old) => old.t != t;
}
