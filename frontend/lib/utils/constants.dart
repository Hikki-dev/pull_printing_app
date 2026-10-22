import 'package:flutter/foundation.dart';

class Constants {
  static const String appName = 'Pull Print';

  /// Runs the whole app on in-memory sample data, no server needed. This is the
  /// default for `flutter run`. Hosted builds pass `--dart-define=USE_MOCK=false`.
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// How to sign in when talking to the server: `demo` (a private sandbox for
  /// each visitor) or `microsoft` (Microsoft Entra ID).
  static const String authMode =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'demo');

  /// Scope requested at Microsoft sign-in. For the server to accept the token this
  /// must be a scope exposed by the app registration, such as
  /// `api://<client-id>/access_as_user`.
  static const String microsoftScope =
      String.fromEnvironment('MS_SCOPE', defaultValue: 'User.Read');

  /// True when visitors are using sample data, so screens explain that nothing is
  /// really printed.
  static const bool demoMode = useMockData || authMode == 'demo';

  /// Where the API lives. Set with `--dart-define=API_BASE_URL=...`. A web build
  /// served by the backend uses its own address, which is what the hosted demo does.
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? '${Uri.base.origin}/api' : 'http://localhost:5000/api';
  }

  /// Shown on the release and confirmation screens.
  static const String printerName = 'Level 3 East';

  /// Seconds before the printer panel signs the user out after printing.
  static const int autoSignOutSeconds = 20;

  // If you later need a default printer for quick release, set it here.
  static const String? defaultPrinterId = null;
}
