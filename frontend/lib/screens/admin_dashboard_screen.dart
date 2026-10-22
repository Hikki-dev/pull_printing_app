import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/print_job.dart';
import '../models/session.dart';
import '../services/print_repository.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/demo_banner.dart';
import '../widgets/doc_thumbnail.dart';
import 'login_screen.dart';

/// All jobs and per-user quotas, for administrators.
class AdminDashboardScreen extends StatefulWidget {
  final Session session;
  const AdminDashboardScreen({required this.session, super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  Object? _error;
  List<PrintJob> _jobs = const [];
  List<UserQuota> _users = const [];
  String _search = '';
  String _status = 'All';
  final Map<String, TextEditingController> _quotaFields = {};

  static const _statuses = ['All', 'Waiting', 'Printed', 'Failed'];
  static const _avatarColors = [
    Color(0xFF0B5CAD),
    Color(0xFF7A4FA3),
    Color(0xFF0F6B63),
    Color(0xFF9A5B13),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _quotaFields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<PrintRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        repo.allJobs(widget.session),
        repo.users(widget.session),
      ]);
      if (!mounted) return;
      final users = results[1] as List<UserQuota>;
      for (final u in users) {
        final text = '${u.quota.total}';
        final existing = _quotaFields[u.userId];
        if (existing == null) {
          _quotaFields[u.userId] = TextEditingController(text: text);
        } else {
          existing.text = text;
        }
      }
      setState(() {
        _jobs = results[0] as List<PrintJob>;
        _users = users;
        _loading = false;
      });
    } on SessionExpiredException catch (e) {
      _signOut(message: e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _saveQuota(UserQuota user) async {
    final repo = context.read<PrintRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final value = int.tryParse(_quotaFields[user.userId]!.text.trim());
    if (value == null || value < 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a whole number of pages.')));
      return;
    }
    try {
      await repo.setQuota(widget.session, user.userId, value);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Quota for ${user.name} set to $value pages.')));
      _load();
    } on SessionExpiredException catch (e) {
      _signOut(message: e.message);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  void _signOut({String? message}) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(message: message)),
      (_) => false,
    );
  }

  String _label(PrintJob j) =>
      j.isHeld ? 'Waiting' : (j.isFailed ? 'Failed' : 'Printed');

  List<PrintJob> get _visibleJobs {
    final q = _search.trim().toLowerCase();
    return _jobs.where((j) {
      if (_status != 'All' && _label(j) != _status) return false;
      if (q.isEmpty) return true;
      return j.userName.toLowerCase().contains(q) ||
          j.fileName.toLowerCase().contains(q);
    }).toList();
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    final l = d.toLocal();
    return l.year == n.year && l.month == n.month && l.day == n.day;
  }

  Color _avatarColor(String name) => _avatarColors[
      name.codeUnits.fold<int>(0, (a, b) => a + b) % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DemoShell(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1200),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _stats(),
                                    const SizedBox(height: 24),
                                    _jobsSection(),
                                    const SizedBox(height: 24),
                                    _quotaSection(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cannot load the dashboard.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$_error', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            AppButton(label: 'Try again', expand: false, onPressed: _load),
          ],
        ),
      );

  Widget _topBar() {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              const BrandMark(size: 32),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '${Constants.appName} Admin',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                style: AppButtonStyle.onNavy,
                height: 44,
                fontSize: 15,
                radius: 10,
                expand: false,
                onPressed: () => _signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _stats() {
    final waiting = _jobs.where((j) => j.isHeld).length;
    final printed =
        _jobs.where((j) => j.isPrinted && _isToday(j.submittedAt)).length;
    final failed = _jobs.where((j) => j.isFailed).length;
    final out = _users.where((u) => u.quota.known && u.quota.left == 0).length;

    Widget stat(String label, int value, IconData icon, Color bg, Color fg) =>
        _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.muted)),
                      Text('$value',
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - 16 * (cols - 1)) / cols;
      final cards = [
        stat('Waiting to print', waiting, Icons.schedule,
            AppColors.waitingBackground, AppColors.waitingText),
        stat('Printed today', printed, Icons.print_outlined,
            AppColors.printedBackground, AppColors.printedText),
        stat('Failed', failed, Icons.warning_amber_rounded,
            AppColors.failedBackground, AppColors.failedText),
        stat('Users out of quota', out, Icons.person_outline,
            const Color(0xFFE6EEF7), const Color(0xFF0B4A8A)),
      ];
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final s in cards) SizedBox(width: w, child: s)],
      );
    });
  }

  Widget _pill(PrintJob j) {
    final label = _label(j);
    final (bg, fg) = switch (label) {
      'Waiting' => (AppColors.waitingBackground, AppColors.waitingText),
      'Failed' => (AppColors.failedBackground, AppColors.failedText),
      _ => (AppColors.printedBackground, AppColors.printedText),
    };
    final text = j.isFailed && j.failureReason != null
        ? 'Failed: ${j.failureReason}'
        : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _avatar(String name) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: _avatarColor(name), shape: BoxShape.circle),
        child: Text(initials(name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _jobsSection() {
    final jobs = _visibleJobs;
    // Stretch the table to the card on wide screens; scroll sideways on narrow ones.
    final tableWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(760.0, 1200.0);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const Text('All jobs',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search user or file',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in _statuses)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  const Text('No jobs match.',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _search = '';
                      _status = 'All';
                    }),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableWidth),
                child: DataTable(
                  headingRowColor:
                      const WidgetStatePropertyAll(Color(0xFFF9FAFB)),
                  headingTextStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted),
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  columnSpacing: 32,
                  columns: const [
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Document')),
                    DataColumn(label: Text('Pages'), numeric: true),
                    DataColumn(label: Text('Sent')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final j in jobs)
                      DataRow(cells: [
                        DataCell(Row(children: [
                          _avatar(j.userName),
                          const SizedBox(width: 10),
                          Text(j.userName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ])),
                        DataCell(Row(children: [
                          _FileStrip(j.fileName),
                          const SizedBox(width: 10),
                          Text(j.fileName),
                        ])),
                        DataCell(Text('${j.pages}')),
                        DataCell(Text(whenLabel(j.submittedAt.toLocal()))),
                        DataCell(_pill(j)),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quotaSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Users and quotas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (_users.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text('The server does not list users yet.',
                  style: TextStyle(color: AppColors.muted)),
            ),
          for (final u in _users)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.lineSoft)),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: Row(children: [
                      _avatar(u.name),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(u.name,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  SizedBox(
                    width: 280,
                    child: Row(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: u.quota.total == 0
                                ? 0
                                : (u.quota.used / u.quota.total)
                                    .clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.lineSoft,
                            color: u.quota.left == 0
                                ? AppColors.pdf
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        u.quota.left == 0
                            ? '${u.quota.used} of ${u.quota.total} · none left'
                            : '${u.quota.used} of ${u.quota.total}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: u.quota.left == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: u.quota.left == 0
                              ? AppColors.failedText
                              : AppColors.muted,
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _quotaFields[u.userId],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Pages per month',
                        semanticCounterText: 'Quota for ${u.name}',
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'Save',
                    height: 44,
                    fontSize: 15,
                    radius: 10,
                    expand: false,
                    onPressed: () => _saveQuota(u),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small file-type tile used in the admin table.
class _FileStrip extends StatelessWidget {
  final String fileName;
  const _FileStrip(this.fileName);

  @override
  Widget build(BuildContext context) {
    final (label, color) = DocThumbnail.kind(fileName);
    return Container(
      width: 34,
      height: 42,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}
