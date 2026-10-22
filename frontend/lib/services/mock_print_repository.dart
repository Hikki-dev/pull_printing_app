import '../models/print_job.dart';
import '../models/session.dart';
import 'print_repository.dart';

/// In-memory sample data so the whole app can be tried without a server.
/// State resets when the app restarts.
class MockPrintRepository implements PrintRepository {
  MockPrintRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final yesterday = t.subtract(const Duration(days: 1));
    PrintJob job(String id, String uid, String name, String file, int pages,
            DateTime at, String status, [String? reason]) =>
        PrintJob(
          id: id,
          userId: uid,
          userName: name,
          fileName: file,
          pages: pages,
          submittedAt: at,
          status: status,
          failureReason: reason,
        );
    _jobs = [
      job('1', 'u1', 'Alice Tan', 'Q3 budget review.pdf', 12,
          t.subtract(const Duration(minutes: 20)), 'Held'),
      job('2', 'u1', 'Alice Tan', 'Site visit notes.docx', 3,
          t.subtract(const Duration(minutes: 40)), 'Held'),
      job('3', 'u1', 'Alice Tan', 'Contract draft v4.pdf', 28, yesterday, 'Held'),
      job('4', 'u1', 'Alice Tan', 'Floor plan.png', 1,
          yesterday.subtract(const Duration(hours: 1)), 'Held'),
      job('5', 'u2', 'Bob Reyes', 'report.docx', 3,
          t.subtract(const Duration(minutes: 30)), 'Printed'),
      job('6', 'u3', 'Priya Nair', 'Safety audit.pdf', 41,
          t.subtract(const Duration(hours: 1)), 'Held'),
      job('7', 'u4', 'Marcus Lee', 'Invoice 2291.pdf', 2, yesterday, 'Failed',
          'printer offline'),
    ];
  }

  final Duration latency;
  late List<PrintJob> _jobs;

  final Map<String, String> _names = {
    'u1': 'Alice Tan',
    'u2': 'Bob Reyes',
    'u3': 'Priya Nair',
    'u4': 'Marcus Lee',
  };
  final Map<String, int> _used = {'u1': 12, 'u2': 50, 'u3': 8, 'u4': 20};
  final Map<String, int> _total = {'u1': 50, 'u2': 50, 'u3': 200, 'u4': 50};

  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  @override
  Future<Session> signIn({bool asAdmin = false}) async {
    await _wait();
    return asAdmin
        ? const Session(
            token: 'demo-admin', userId: 'admin', name: 'Administrator', isAdmin: true)
        : const Session(token: 'demo-user', userId: 'u1', name: 'Alice Tan');
  }

  @override
  Future<List<PrintJob>> myHeldJobs(Session session) async {
    await _wait();
    final mine = _jobs
        .where((j) => j.userId == session.userId && j.isHeld)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return mine;
  }

  @override
  Future<QuotaInfo> myQuota(Session session) async {
    await _wait();
    return QuotaInfo(
      used: _used[session.userId] ?? 0,
      total: _total[session.userId] ?? 0,
    );
  }

  @override
  Future<void> release(Session session, List<String> jobIds) async {
    await _wait();
    final chosen = _jobs
        .where((j) =>
            jobIds.contains(j.id) && j.userId == session.userId && j.isHeld)
        .toList();
    if (chosen.isEmpty) throw const PrintException('Nothing to print.');
    final pages = chosen.fold<int>(0, (n, j) => n + j.pages);
    final left = (_total[session.userId] ?? 0) - (_used[session.userId] ?? 0);
    if (pages > left) throw QuotaExceededException(pages - left);
    _used[session.userId] = (_used[session.userId] ?? 0) + pages;
    _jobs = [
      for (final j in _jobs)
        if (chosen.any((c) => c.id == j.id)) j.copyWith(status: 'Printed') else j,
    ];
  }

  @override
  Future<List<PrintJob>> allJobs(Session session) async {
    await _wait();
    if (!session.isAdmin) throw const PrintException('Administrators only.');
    return [..._jobs]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Future<List<UserQuota>> users(Session session) async {
    await _wait();
    if (!session.isAdmin) throw const PrintException('Administrators only.');
    return [
      for (final id in _names.keys)
        UserQuota(
          userId: id,
          name: _names[id]!,
          quota: QuotaInfo(used: _used[id] ?? 0, total: _total[id] ?? 0),
        ),
    ];
  }

  @override
  Future<void> setQuota(Session session, String userId, int quota) async {
    await _wait();
    if (!session.isAdmin) throw const PrintException('Administrators only.');
    if (quota < 0) throw const PrintException('Quota cannot be negative.');
    _total[userId] = quota;
  }
}
