import '../models/print_job.dart';
import '../models/printer.dart';
import '../models/session.dart';
import '../utils/browser.dart' as browser;
import 'api_service.dart';
import 'print_repository.dart';

/// Talks to the backend. People sign in with their Microsoft or Google work account
/// (the server does the sign-in and hands back a session token), or with a demo sandbox.
class HttpPrintRepository implements PrintRepository {
  HttpPrintRepository({
    ApiService? api,
    Uri Function()? location,
    void Function(String url)? navigate,
    void Function()? clearFragment,
  })  : _api = api ?? ApiService(),
        _location = location ?? (() => Uri.base),
        _navigate = navigate ?? browser.goTo,
        _clearFragment = clearFragment ?? browser.removeAddressFragment;

  final ApiService _api;
  final Uri Function() _location;
  final void Function(String url) _navigate;
  final void Function() _clearFragment;

  /// What each reason the server gives for turning someone away means for the person.
  static String signInProblem(String? code) => switch (code) {
        'wrong_account' =>
          'That account is not allowed here. Sign in with your work account.',
        'unverified_email' =>
          'Your email address is not verified, so you cannot sign in with it.',
        'no_identity' =>
          'Your account did not tell us who you are. Ask your administrator.',
        _ => 'Sign-in did not work. Please try again.',
      };

  @override
  Future<AuthConfig> authConfig() => _api.authConfig();

  @override
  Future<Session> signIn({bool asAdmin = false}) =>
      _api.demoLogin(admin: asAdmin);

  @override
  void startWorkspaceSignIn() {
    final here = _location();
    final back = '/${here.hasQuery ? '?${here.query}' : ''}';
    _navigate(
        '${_api.baseUrl}/auth/login?returnTo=${Uri.encodeQueryComponent(back)}');
  }

  @override
  Future<Session?> resumeSignIn() async {
    final fragment = _location().fragment;
    if (!fragment.contains('token=') && !fragment.contains('error=')) {
      return null;
    }
    Map<String, String> values;
    try {
      values = Uri.splitQueryString(fragment);
    } on FormatException {
      return null;
    }
    // The token must not stay in the address bar or the browser history.
    _clearFragment();
    final error = values['error'];
    if (error != null) throw PrintException(signInProblem(error));
    final token = values['token'];
    if (token == null || token.isEmpty) return null;
    return _api.me(token);
  }

  @override
  String? get panelPrinterId {
    final id = _location().queryParameters['printer'];
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Future<List<Printer>> printers(Session session) =>
      _api.printers(session.token);

  @override
  Future<List<PrintJob>> myHeldJobs(Session session) =>
      _api.heldJobs(session.token);

  @override
  Future<QuotaInfo> myQuota(Session session) => _api.quota(session.token);

  @override
  Future<List<String>> release(Session session, List<String> jobIds,
          {String? printerId}) =>
      _api.release(session.token, jobIds, printerId: printerId);

  @override
  Future<List<PrintJob>> allJobs(Session session) =>
      _api.allJobs(session.token);

  @override
  Future<List<UserQuota>> users(Session session) => _api.users(session.token);

  @override
  Future<void> setQuota(Session session, String userId, int quota) =>
      _api.setQuota(session.token, userId, quota);

  @override
  Future<SetupInfo> setup(Session session) => _api.setup(session.token);

  @override
  Future<void> setDefaultQuota(Session session, int quota) =>
      _api.setDefaultQuota(session.token, quota);

  @override
  Future<int> setQuotaForAll(Session session, int quota) =>
      _api.setQuotaForAll(session.token, quota);

  @override
  Future<Printer> addPrinter(Session session, String name, String location) =>
      _api.addPrinter(session.token, name, location);

  @override
  Future<void> updatePrinter(Session session, Printer printer) =>
      _api.updatePrinter(session.token, printer);

  @override
  Future<void> deletePrinter(Session session, String printerId) =>
      _api.deletePrinter(session.token, printerId);

  @override
  void resetDemo() {}

  @override
  Future<void> sendSampleDocuments(Session session, {int count = 1}) async {
    for (var i = 0; i < count; i++) {
      try {
        await _api.sendSample(session.token);
      } on PrintException {
        // The server says when there are no more samples; stop quietly after the first.
        if (i == 0) rethrow;
        return;
      }
    }
  }
}
