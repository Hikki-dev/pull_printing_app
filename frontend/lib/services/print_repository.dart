import '../models/print_job.dart';
import '../models/session.dart';

/// Everything the screens need from the server. The demo implementation keeps
/// data in memory; the HTTP one talks to the backend.
abstract class PrintRepository {
  Future<Session> signIn({bool asAdmin = false});

  /// The signed-in user's jobs that are waiting to print, newest first.
  Future<List<PrintJob>> myHeldJobs(Session session);

  Future<QuotaInfo> myQuota(Session session);

  /// Prints the given jobs and reduces the quota by their page count. Returns the
  /// ids that really printed, which can be fewer than were asked for when the
  /// printer rejects one. Throws [QuotaExceededException] when they do not fit.
  Future<List<String>> release(Session session, List<String> jobIds);

  Future<List<PrintJob>> allJobs(Session session);

  Future<List<UserQuota>> users(Session session);

  Future<void> setQuota(Session session, String userId, int quota);

  /// Demo only: adds up to [count] sample documents to the user's waiting list.
  Future<void> sendSampleDocuments(Session session, {int count = 1});

  /// Demo only: puts the sample data back as it started. Does nothing when the
  /// data lives on a server, where signing in again starts a fresh sandbox.
  void resetDemo();
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

/// The token is no longer valid, for example after the demo server restarted.
class SessionExpiredException extends PrintException {
  const SessionExpiredException()
      : super('Your session has ended. Please sign in again.');
}
