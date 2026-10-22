import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// A drawn preview of a document: a page with a title bar and text lines (or a
/// plan outline for images) and a file-type strip. Replace with a real
/// first-page preview from the server when one exists.
class DocThumbnail extends StatelessWidget {
  final String fileName;
  final double width;

  const DocThumbnail({super.key, required this.fileName, this.width = 52});

  static String _ext(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Label and colour of the strip for a file name.
  static (String, Color) kind(String fileName) {
    switch (_ext(fileName)) {
      case 'pdf':
        return ('PDF', AppColors.pdf);
      case 'doc':
      case 'docx':
        return ('DOCX', AppColors.docx);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return (_ext(fileName).toUpperCase(), AppColors.image);
      default:
        final e = _ext(fileName);
        return (e.isEmpty ? 'FILE' : e.toUpperCase(), AppColors.otherFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, accent) = kind(fileName);
    final isImage = accent == AppColors.image;
    final s = width / 120; // drawn at 120 x 156, scaled to [width]
    const lineColor = Color(0xFFDCE3EA);

    Widget bar(double l, double t, double? r, double h, Color c, {double? w}) =>
        Positioned(
          left: l * s,
          top: t * s,
          right: r == null ? null : r * s,
          width: w == null ? null : w * s,
          height: h * s,
          child: DecoratedBox(
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3 * s)),
          ),
        );

    return ExcludeSemantics(
      child: Container(
        width: width,
        height: 156 * s,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: width < 80 ? Border.all(color: AppColors.line) : null,
          boxShadow: const [
            BoxShadow(color: Color(0x240E2A47), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!isImage) ...[
              bar(14, 18, null, 10, accent, w: 58),
              bar(14, 42, 14, 6, lineColor),
              bar(14, 56, 22, 6, lineColor),
              bar(14, 70, 14, 6, lineColor),
              bar(14, 84, 30, 6, lineColor),
              bar(14, 98, 14, 6, lineColor),
            ] else ...[
              Positioned(
                left: 14 * s,
                top: 18 * s,
                right: 14 * s,
                bottom: 44 * s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.muted, width: 3 * s),
                  ),
                ),
              ),
              Positioned(
                left: 58 * s,
                top: 18 * s,
                width: 3 * s,
                height: 48 * s,
                child: const ColoredBox(color: AppColors.muted),
              ),
              Positioned(
                left: 14 * s,
                top: 62 * s,
                width: 44 * s,
                height: 3 * s,
                child: const ColoredBox(color: AppColors.muted),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 26 * s,
              child: ColoredBox(
                color: accent,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (12 * s).clamp(7.0, 14.0),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8 * s,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
