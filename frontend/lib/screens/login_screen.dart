import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../services/print_repository.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/demo_banner.dart';
import '../widgets/microsoft_logo.dart';
import '../widgets/printer_illustration.dart';
import 'admin_dashboard_screen.dart';
import 'release_jobs_screen.dart';

class LoginScreen extends StatefulWidget {
  /// Shown once on arrival, for example "Your session has ended".
  final String? message;
  const LoginScreen({super.key, this.message});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final message = widget.message;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }
  }

  Future<void> _login({bool asAdmin = false}) async {
    final repo = context.read<PrintRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    Session? session;
    String? failure;
    try {
      session = await repo.signIn(asAdmin: asAdmin);
    } catch (e) {
      session = null;
      failure = e is PrintException ? e.message : null;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (session == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure ?? 'Sign-in failed. Please try again.')),
      );
      return;
    }
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => session!.isAdmin
          ? AdminDashboardScreen(session: session)
          : ReleaseJobsScreen(session: session),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.panelBreakpoint;
    return Scaffold(
      backgroundColor: wide ? AppColors.background : AppColors.navy,
      body: DemoShell(child: wide ? _panel() : _phone()),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _phone() {
    return LayoutBuilder(builder: (context, c) {
      // On short phones drop the step cards and shrink the printer so the
      // sign-in button stays on screen without scrolling.
      final compact = c.maxHeight < 720;
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                        left: -60,
                        top: -80,
                        child: _circle(300, AppColors.navyLight)),
                    Positioned(
                        right: -90,
                        top: 120,
                        child: _circle(260, AppColors.navyDeep)),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                BrandMark(size: 36),
                                SizedBox(width: 10),
                                Text(
                                  Constants.appName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 12 : 32),
                            PrinterIllustration(width: compact ? 200 : 300),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Print now.\nCollect at any printer.',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Your documents wait safely until you are at the printer and tap Print.',
                            style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: AppColors.muted),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 16),
                            const IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _StepCard(1, 'Send a file')),
                                  SizedBox(width: 8),
                                  Expanded(
                                      child:
                                          _StepCard(2, 'Walk up and sign in')),
                                  SizedBox(width: 8),
                                  Expanded(child: _StepCard(3, 'Tap Print')),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          const SizedBox(height: 20),
                          MicrosoftSignInButton(
                              onPressed: _login, busy: _loading),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              Constants.demoMode
                                  ? 'You get your own sample documents. Nothing is really printed.'
                                  : 'Use your work account. No new password.',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.muted),
                            ),
                          ),
                          if (Constants.demoMode)
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => _login(asAdmin: true),
                                child: const Text(
                                    'Demo: sign in as administrator'),
                              ),
                            ),
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

  Widget _panel() {
    return Row(
      children: [
        Container(
          width: 440,
          color: AppColors.navy,
          child: Stack(
            children: [
              Positioned(
                  left: -90,
                  bottom: -110,
                  child: _circle(360, AppColors.navyLight)),
              const Padding(
                padding: EdgeInsets.fromLTRB(40, 32, 40, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrandMark(size: 44),
                        SizedBox(width: 12),
                        Text(
                          Constants.appName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 48),
                    Text(
                      'Sign in to collect your prints',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'You will only see your own documents.',
                      style: TextStyle(
                          fontSize: 18,
                          height: 1.45,
                          color: AppColors.onNavyMuted),
                    ),
                    Spacer(),
                    Center(child: PrinterIllustration(width: 300)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 28, 48, 32),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    Constants.printerName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.primary, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sign in with your work account',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 20),
                                MicrosoftSignInButton(
                                  onPressed: _login,
                                  busy: _loading,
                                  height: 64,
                                ),
                                if (Constants.demoMode) ...[
                                  const SizedBox(height: 12),
                                  AppButton(
                                    label: 'Demo: sign in as administrator',
                                    style: AppButtonStyle.outline,
                                    height: 48,
                                    fontSize: 15,
                                    onPressed: _loading
                                        ? null
                                        : () => _login(asAdmin: true),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined,
                                    size: 28, color: AppColors.muted),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Tap your staff card',
                                    style: TextStyle(
                                        fontSize: 18, color: AppColors.muted),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.line),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Coming later',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String label;
  const _StepCard(this.number, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }
}
