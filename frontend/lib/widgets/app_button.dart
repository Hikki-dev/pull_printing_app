import 'package:flutter/material.dart';
import '../utils/theme.dart';

enum AppButtonStyle { primary, onNavy, light, outline }

/// Large, high-contrast button. Disabled when [onPressed] is null.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final double height;
  final double fontSize;
  final double radius;
  final bool busy;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.height = 56,
    this.fontSize = 17,
    this.radius = 12,
    this.busy = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (style) {
      AppButtonStyle.primary => (
          AppColors.primary,
          Colors.white,
          BorderSide.none
        ),
      AppButtonStyle.onNavy => (
          AppColors.navyChip,
          Colors.white,
          const BorderSide(color: Color(0xFF3A5F8A))
        ),
      AppButtonStyle.light => (Colors.white, AppColors.navy, BorderSide.none),
      AppButtonStyle.outline => (
          Colors.white,
          AppColors.ink,
          const BorderSide(color: AppColors.ink)
        ),
    };
    final disabled = onPressed == null && !busy;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: busy ? bg : AppColors.lineSoft,
        disabledForegroundColor: busy ? fg : AppColors.muted,
        minimumSize: Size(expand ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: disabled ? BorderSide.none : side,
        ),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      child: busy
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: fontSize + 4),
                  const SizedBox(width: 10)
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}
