import 'package:flutter/material.dart';

/// Microsoft's four-square mark, drawn to its published colours and
/// proportions. Swap for Microsoft's own asset before release.
class MicrosoftLogo extends StatelessWidget {
  final double size;
  const MicrosoftLogo({super.key, this.size = 21});

  @override
  Widget build(BuildContext context) {
    final s = size * 9 / 21;
    final gap = size / 21;
    Widget sq(Color c) => Container(width: s, height: s, color: c);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              sq(const Color(0xFFF25022)),
              SizedBox(width: gap),
              sq(const Color(0xFF7FBA00)),
            ]),
            SizedBox(height: gap),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              sq(const Color(0xFF00A4EF)),
              SizedBox(width: gap),
              sq(const Color(0xFFFFB900)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// "Sign in with Microsoft" in Microsoft's sign-in button style.
class MicrosoftSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  const MicrosoftSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, height),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF5E5E5E),
          disabledForegroundColor: const Color(0xFF5E5E5E),
          side: const BorderSide(color: Color(0xFF8C8C8C)),
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
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFF5E5E5E)),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MicrosoftLogo(),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Sign in with Microsoft',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
