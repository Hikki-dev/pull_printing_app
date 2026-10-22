import '../models/print_job.dart';
import '../models/printer.dart';
import '../models/session.dart';

/// Everything the screens need from the server. The demo implementation keeps
/// data in memory; the HTTP one talks to the backend.
abstract class PrintRepository {
  /// How people sign in on this server. Asked before anyone is signed in.
  Future<AuthConfig> authConfig();

  /// Demo sign-in: a private sandbox with sample documents.
  Future<Session> signIn({bool asAdmin = false});

  /// Takes the user to Microsoft or Google to sign in. The browser leaves the app and
  /// comes back to the same address, where [resumeSignIn] finishes the job.
  void startWorkspaceSignIn();

  /// Finishes a work-account sign-in when the browser has just come back from it.
  /// Returns null when it did not. Throws [PrintException] with a plain reason when
  /// the account was turned away.
  Future<Session?> resumeSignIn();

  /// The printer named in the address (`?printer=`) when this screen is a printer's panel.
  String? get panelPrinterId;

  /// Printers people can pick from. Switched-off printers are included only for administrators.
  Future<List<Printer>> printers(Session session);

  /// The signed-in user's jobs that are waiting to print, newest first.
  Future<List<PrintJob>> myHeldJobs(Session session);

  Future<QuotaInfo> myQuota(Session session);

  /// Prints the given jobs and reduces the quota by their page count. Returns the
  /// ids that really printed, which can be fewer than were asked for when the
  /// printer rejects one. Throws [QuotaExceededException] when they do not fit.
  Future<List<String>> release(Session session, List<String> jobIds,
      {String? printerId});

  Future<List<PrintJob>> allJobs(Session session);

  Future<List<UserQuota>> users(Session session);

  Future<void> setQuota(Session session, String userId, int quota);

  /// How this server is set up and what still needs attention. Administrators only.
  Future<SetupInfo> setup(Session session);

  /// Pages a month that people start with the first time they sign in.
  Future<void> setDefaultQuota(Session session, int quota);

  /// Gives everyone the same pages a month. Returns how many people changed.
  Future<int> setQuotaForAll(Session session, int quota);

  Future<Printer> addPrinter(Session session, String name, String location);

  Future<void> updatePrinter(Session session, Printer printer);

  Future<void> deletePrinter(Session session, String printerId);

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
