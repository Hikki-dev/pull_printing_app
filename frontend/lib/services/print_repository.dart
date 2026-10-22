import '../models/print_job.dart';
import '../models/session.dart';

/// Everything the screens need from the server. The demo implementation keeps
/// data in memory; the HTTP one talks to the backend.
abstract class PrintRepository {
  Future<Session> signIn({bool asAdmin = false});

  /// The signed-in user's jobs that are waiting to print, newest first.
  Future<List<PrintJob>> myHeldJobs(Session session);

  Future<QuotaInfo> myQuota(Session session);

  /// Prints the given jobs and reduces the quota by their page count.
  /// Throws [QuotaExceededException] when they do not fit.
  Future<void> release(Session session, List<String> jobIds);

  Future<List<PrintJob>> allJobs(Session session);

  Future<List<UserQuota>> users(Session session);

  Future<void> setQuota(Session session, String userId, int quota);
}

class QuotaExceededException implements Exception {
  final int pagesOver;
  const QuotaExceededException(this.pagesOver);

  @override
  String toString() => 'Over your limit by $pagesOver pages.';
}

class PrintException implements Exception {
  final String message;
  const PrintException(this.message);

  @override
  String toString() => message;
}
