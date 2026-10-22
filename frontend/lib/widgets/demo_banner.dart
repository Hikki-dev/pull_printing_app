import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Wraps a screen so that, in demo mode, a slim banner above it says that the
/// data is sample data and opens "About this demo". Does nothing otherwise.
class DemoShell extends StatelessWidget {
  final Widget child;
  const DemoShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Constants.demoMode) return child;
    return Column(
      children: [
        const DemoBanner(),
        Expanded(
          // The banner already covers the status bar, so the screen below must not pad for it again.
          child: MediaQuery.removePadding(
              context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.waitingBackground,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => showDemoInfo(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: AppColors.waitingText),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Demo: nothing is really printed.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.waitingText,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'What is this?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.waitingText,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDemoInfo(BuildContext context) {
  final points = <String>[
    'Pull Print keeps your documents on a server until you are standing at a printer. This demo lets you try that.',
    'You get your own sample documents. Other visitors cannot see them.',
    'Print does not use a real printer. It marks your documents as printed and uses up pages from your quota.',
    if (Constants.useMockData)
      'Everything resets when you restart the app.'
    else
      'Everything is deleted after 2 hours without use, and whenever the server restarts.',
    'Run out of documents? Use "Send sample documents" to get more.',
    'To see every job and change page limits, go back to sign-in and choose "Demo: sign in as administrator". You get your own sample people there too.',
  ];
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About this demo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, right: 10),
                      child: SizedBox(
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    Expanded(
                        child: Text(p,
                            style: const TextStyle(fontSize: 15, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it')),
      ],
    ),
  );
}
