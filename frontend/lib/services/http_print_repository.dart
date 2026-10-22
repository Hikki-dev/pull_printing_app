import '../models/print_job.dart';
import '../models/session.dart';
import 'MsAuthService.dart';
import 'api_service.dart';
import 'print_repository.dart';

/// Talks to the real backend. The backend has no endpoints yet for a user's
/// quota or for listing users, so those return "unknown" and an empty list
/// until they exist (see README, Current status).
class HttpPrintRepository implements PrintRepository {
  HttpPrintRepository({ApiService? api, MsAuthService? auth})
      : _api = api ?? ApiService(),
        _auth = auth ?? MsAuthService();

  final ApiService _api;
  final MsAuthService _auth;
  bool _authReady = false;

  @override
  Future<Session> signIn({bool asAdmin = false}) async {
    if (!_authReady) {
      await _auth.init();
      _authReady = true;
    }
    final token = await _auth.login();
    if (token == null) throw const PrintException('Sign-in failed.');
    return Session(token: token, userId: 'me', name: 'Microsoft account');
  }

  @override
  Future<List<PrintJob>> myHeldJobs(Session session) =>
      _api.fetchMyHeldJobs(token: session.token);

  @override
  Future<QuotaInfo> myQuota(Session session) async => QuotaInfo.unknown;

  @override
  Future<void> release(Session session, List<String> jobIds) async {
    for (final id in jobIds) {
      await _api.releaseJob(token: session.token, jobId: id);
    }
  }

  @override
  Future<List<PrintJob>> allJobs(Session session) =>
      _api.fetchAllJobs(token: session.token);

  @override
  Future<List<UserQuota>> users(Session session) async => const [];

  @override
  Future<void> setQuota(Session session, String userId, int quota) =>
      _api.setQuota(token: session.token, userId: userId, quota: quota);
}
