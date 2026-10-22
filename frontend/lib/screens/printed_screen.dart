import 'dart:async';
import 'package:flutter/material.dart';
import '../models/print_job.dart';
import '../models/session.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/app_button.dart';
import '../widgets/demo_banner.dart';
import '../widgets/printer_illustration.dart';
import 'login_screen.dart';
import 'release_jobs_screen.dart';

/// Confirmation after printing. On the printer-panel layout it signs the user
/// out after [Constants.autoSignOutSeconds] so the next person never sees
/// this user's documents.
class PrintedScreen extends StatefulWidget {
  final Session session;
  final List<PrintJob> printed;

  /// Pages left after this print, or null when the quota is not known.
  final int? pagesLeft;
  final int totalPages;

  const PrintedScreen({
    super.key,
    required this.session,
    required this.printed,
    required this.pagesLeft,
    required this.totalPages,
  });

  @override
  State<PrintedScreen> createState() => _PrintedScreenState();
}

class _PrintedScreenState extends State<PrintedScreen> {
  Timer? _timer;
  bool _timerStarted = false;

  int get _pages => widget.printed.fold(0, (n, j) => n + j.pages);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.panelBreakpoint;
    if (wide && !_timerStarted) {
      _timerStarted = true;
      _timer = Timer(
          const Duration(seconds: Constants.autoSignOutSeconds), _signOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _signOut() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _backToDocuments() {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => ReleaseJobsScreen(session: widget.session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.panelBreakpoint;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: DemoShell(child: wide ? _panel() : _phone()),
    );
  }

  Widget _tick(double size) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
          child: Icon(Icons.check, color: Colors.white, size: size * 0.55),
        ),
      );

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _phone() {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned(
                          right: -70,
                          top: -60,
                          child: _circle(260, AppColors.navyLight)),
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                _tick(64),
                                const SizedBox(height: 20),
                                const Text(
                                  'Printing at ${Constants.printerName}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  Constants.demoMode
                                      ? 'This is a demo, so nothing was really printed.'
                                      : 'Collect your pages from the tray.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.onNavyMuted),
                                ),
                                const SizedBox(height: 24),
                                const PrinterIllustration(width: 240),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          for (final j in widget.printed)
                            _row(j.fileName, pagesLabel(j.pages)),
                          if (widget.pagesLeft != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Pages left this month',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: AppColors.muted)),
                                  Text(
                                    '${widget.pagesLeft} of ${widget.totalPages}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          const SizedBox(height: 16),
                          AppButton(
                              label: 'Back to my documents',
                              onPressed: _backToDocuments),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _row(String name, String pages) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Text(pages,
                style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          ],
        ),
      );

  Widget _panel() {
    return Stack(
      children: [
        Positioned(
            left: -120, top: -120, child: _circle(420, AppColors.navyLight)),
        Positioned(
            right: -80, bottom: -140, child: _circle(400, AppColors.navyDeep)),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tick(80),
                    const SizedBox(height: 18),
                    Text(
                      'Printing ${pagesLabel(_pages)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '${Constants.demoMode ? 'This is a demo, so nothing was really printed.' : 'Collect your documents from the tray.'}'
                      '${widget.pagesLeft == null ? '' : '\nYou have ${widget.pagesLeft} pages left this month.'}',
                      style: const TextStyle(
                          fontSize: 22,
                          height: 1.4,
                          color: AppColors.onNavyMuted),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        AppButton(
                          label: 'Print more',
                          style: AppButtonStyle.onNavy,
                          height: 64,
                          fontSize: 20,
                          radius: 14,
                          expand: false,
                          onPressed: _backToDocuments,
                        ),
                        const SizedBox(width: 16),
                        AppButton(
                          label: 'Sign out',
                          style: AppButtonStyle.light,
                          height: 64,
                          fontSize: 20,
                          radius: 14,
                          expand: false,
                          onPressed: _signOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Signing out automatically',
                              style: TextStyle(
                                  fontSize: 15, color: AppColors.onNavyMuted)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1, end: 0),
                              duration: const Duration(
                                  seconds: Constants.autoSignOutSeconds),
                              builder: (context, v, _) =>
                                  LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                backgroundColor: AppColors.ringTrack,
                                color: AppColors.ringFill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              width: 440,
              child: Center(child: PrinterIllustration(width: 400)),
            ),
          ],
        ),
      ],
    );
  }
}
