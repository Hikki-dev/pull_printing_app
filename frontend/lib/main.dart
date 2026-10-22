import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/http_print_repository.dart';
import 'services/mock_print_repository.dart';
import 'services/print_repository.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

void main() {
  // Plain addresses, so the sign-in token in `#token=...` is not mistaken for a page.
  usePathUrlStrategy();
  runApp(PullPrintingApp(
    repository:
        Constants.useMockData ? MockPrintRepository() : HttpPrintRepository(),
  ));
}

class PullPrintingApp extends StatelessWidget {
  final PrintRepository repository;

  /// Only set by tests, which load a real font so text is measured realistically.
  final String? fontFamily;

  const PullPrintingApp({super.key, required this.repository, this.fontFamily});

  @override
  Widget build(BuildContext context) {
    return Provider<PrintRepository>.value(
      value: repository,
      child: MaterialApp(
        title: Constants.appName,
        debugShowCheckedModeBanner: false,
        theme: fontFamily == null
            ? AppTheme.light
            : AppTheme.build(fontFamily: fontFamily),
        // Always start at the sign-in screen, whatever the address says. The browser can
        // arrive with `/?printer=...#token=...`, which is not a route.
        onGenerateRoute: (_) => _signInRoute(),
        onGenerateInitialRoutes: (_) => [_signInRoute()],
      ),
    );
  }

  static Route<void> _signInRoute() =>
      MaterialPageRoute<void>(builder: (_) => const LoginScreen());
}
