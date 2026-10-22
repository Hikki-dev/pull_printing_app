class Constants {
  static const String appName = 'Pull Print';

  /// Demo mode runs the whole app on in-memory sample data, no server needed.
  /// Run against the real backend with `--dart-define=USE_MOCK=false`.
  static const bool useMockData =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  // Point this at your backend when it’s up. For local .NET run, it’s often https://localhost:5001
  static const String apiBaseUrl = 'http://localhost:5000/api';

  /// Shown on the release and confirmation screens.
  static const String printerName = 'Level 3 East';

  /// Seconds before the printer panel signs the user out after printing.
  static const int autoSignOutSeconds = 20;

  // If you later need a default printer for quick release, set it here.
  static const String? defaultPrinterId = null;
}
