import 'package:flutter/foundation.dart';

class Constants {
  static const String appName = 'Pull Print';

  /// Runs the whole app on in-memory sample data, no server needed. This is the
  /// default for `flutter run`. Hosted builds pass `--dart-define=USE_MOCK=false`.
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// True while the person is using sample data, so screens explain that nothing is
  /// really printed. Set from the server's answer on the sign-in screen and from the
  /// kind of session after signing in.
  static bool demoMode = useMockData;

  /// Where the API lives. Set with `--dart-define=API_BASE_URL=...`. A web build
  /// served by the backend uses its own address, which is what the hosted demo does.
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? '${Uri.base.origin}/api' : 'http://localhost:5000/api';
  }

  /// Seconds before the printer panel signs the user out after printing.
  static const int autoSignOutSeconds = 20;

  /// Seconds without a touch before the printer panel signs the user out, so a
  /// person who walks away does not leave their documents on screen.
  static const int idleSignOutSeconds = 60;
}
