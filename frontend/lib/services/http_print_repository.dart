import '../models/print_job.dart';
import '../models/session.dart';
import '../utils/constants.dart';
import 'MsAuthService.dart';
import 'api_service.dart';
import 'print_repository.dart';

/// Talks to the backend. Signs in with a demo sandbox or with Microsoft,
/// depending on [Constants.authMode].
class HttpPrintRepository implements PrintRepository {
  HttpPrintRepository({ApiService? api, MsAuthService? auth})
      : _api = api ?? ApiService(),
        _auth = auth;

  final ApiService _api;
  MsAuthService? _auth;
  bool _authReady = false;

  @override
  Future<Session> signIn({bool asAdmin = false}) async {
    if (Constants.authMode == 'demo') return _api.demoLogin(admin: asAdmin);

    final auth = _auth ??= MsAuthService();
    if (!_authReady) {
      await auth.init();
      _authReady = true;
    }
    final token = await auth.login(scopes: [Constants.microsoftScope]);
    if (token == null) throw const PrintException('Sign-in failed.');
    return _api.me(token);
  }

  @override
  Future<List<PrintJob>> myHeldJobs(Session session) =>
      _api.heldJobs(session.token);

  @override
  Future<QuotaInfo> myQuota(Session session) => _api.quota(session.token);

  @override
  Future<void> release(Session session, List<String> jobIds) =>
      _api.release(session.token, jobIds);

  @override
  Future<List<PrintJob>> allJobs(Session session) =>
      _api.allJobs(session.token);

  @override
  Future<List<UserQuota>> users(Session session) => _api.users(session.token);

  @override
  Future<void> setQuota(Session session, String userId, int quota) =>
      _api.setQuota(session.token, userId, quota);

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
