import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/print_job.dart';
import '../models/printer.dart';
import '../models/session.dart';
import '../services/print_repository.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/demo_banner.dart';
import '../widgets/job_card.dart';
import '../widgets/quota_ring.dart';
import 'login_screen.dart';
import 'printed_screen.dart';

/// Lists the signed-in user's waiting documents and prints the ones chosen.
/// Phone layout below [AppTheme.panelBreakpoint], printer-panel layout above.
class ReleaseJobsScreen extends StatefulWidget {
  final Session session;
  const ReleaseJobsScreen({required this.session, super.key});

  @override
  State<ReleaseJobsScreen> createState() => _ReleaseJobsScreenState();
}

class _ReleaseJobsScreenState extends State<ReleaseJobsScreen> {
  bool _loading = true;
  Object? _error;
  List<PrintJob> _jobs = const [];
  QuotaInfo _quota = QuotaInfo.unknown;
  Set<String> _selected = {};
  List<Printer> _printers = const [];
  Printer? _printer;

  /// True when the address names a printer (`?printer=`), as on a printer's own panel.
  bool _printerLocked = false;
  bool _printing = false;
  Timer? _idleTimer;
  bool _idleStarted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A printer panel is shared, so it signs out a person who walks away.
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.panelBreakpoint;
    if (wide && !_idleStarted) {
      _idleStarted = true;
      _resetIdle();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdle() {
    if (!_idleStarted) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(
      const Duration(seconds: Constants.idleSignOutSeconds),
      () =>
          _signOut(message: 'You were signed out because the screen was idle.'),
    );
  }

  Future<void> _load() async {
    final repo = context.read<PrintRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        repo.myHeldJobs(widget.session),
        repo.myQuota(widget.session),
        repo.printers(widget.session),
      ]);
      if (!mounted) return;
      final jobs = results[0] as List<PrintJob>;
      final quota = results[1] as QuotaInfo;
      final printers =
          (results[2] as List<Printer>).where((p) => p.enabled).toList();
      final fixed = repo.panelPrinterId;
      Printer? chosen;
      for (final p in printers) {
        if (p.id == fixed) chosen = p;
      }
      chosen ??= printers.where((p) => p.id == _printer?.id).firstOrNull;
      chosen ??= printers.firstOrNull;
      setState(() {
        _printers = printers;
        _printer = chosen;
        _printerLocked = fixed != null && chosen?.id == fixed;
        _jobs = jobs;
        _quota = quota;
        _selected = _defaultSelection(jobs, quota);
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

  Future<void> _sendSamples(int count) async {
    final repo = context.read<PrintRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.sendSampleDocuments(widget.session, count: count);
    } on SessionExpiredException catch (e) {
      _signOut(message: e.message);
      return;
    } on PrintException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) _load();
  }

  /// Newest documents first, stopping at the first one that would go over quota.
  Set<String> _defaultSelection(List<PrintJob> jobs, QuotaInfo quota) {
    final picked = <String>{};
    var pages = 0;
    for (final j in jobs) {
      if (quota.known && pages + j.pages > quota.left) break;
      picked.add(j.id);
      pages += j.pages;
    }
    return picked;
  }

  int get _pages => _jobs
      .where((j) => _selected.contains(j.id))
      .fold(0, (n, j) => n + j.pages);
  int get _count => _selected.length;
  bool get _over => _quota.known && _pages > _quota.left;
  bool get _canPrint => _count > 0 && !_over && !_printing && _printer != null;
  bool get _allSelected => _jobs.isNotEmpty && _selected.length == _jobs.length;

  void _toggleAll() {
    setState(() {
      _selected = _allSelected ? <String>{} : _jobs.map((j) => j.id).toSet();
    });
  }

  /// Why the selection cannot be printed, in words that say what to do.
  String get _overText {
    final left = _quota.left;
    if (left == 0) return 'No pages left this month.';
    if (_count == 1) {
      return 'This document needs $_pages pages. You have $left left.';
    }
    return 'Over your limit by ${_pages - left} pages. Untick one.';
  }

  void _toggle(PrintJob job, bool on) {
    setState(() => on ? _selected.add(job.id) : _selected.remove(job.id));
  }

  Future<void> _print() async {
    final repo = context.read<PrintRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ids = _selected.toList();
    setState(() => _printing = true);
    try {
      final printedIds =
          await repo.release(widget.session, ids, printerId: _printer?.id);
      if (!mounted) return;
      final printed = _jobs.where((j) => printedIds.contains(j.id)).toList();
      if (printed.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'The printer could not print your documents. They are still waiting.'),
        ));
        setState(() => _printing = false);
        _load();
        return;
      }
      final pagesPrinted = printed.fold(0, (n, j) => n + j.pages);
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => PrintedScreen(
          session: widget.session,
          printed: printed,
          printerName: _printer?.name ?? 'the printer',
          notPrinted: ids.length - printed.length,
          pagesLeft: _quota.known ? _quota.left - pagesPrinted : null,
          totalPages: _quota.total,
        ),
      ));
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _printing = false);
      _load();
    } on SessionExpiredException catch (e) {
      _signOut(message: e.message);
    } on PrintException catch (e) {
      // Often "those documents are not waiting": the list was out of date.
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('${e.message} Your list has been refreshed.')));
      setState(() => _printing = false);
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content:
                Text('Could not print. Your documents are still waiting.')),
      );
      setState(() => _printing = false);
    }
  }

  void _signOut({String? message}) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(message: message)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppTheme.panelBreakpoint;
    final content = DemoShell(
      child: Column(
        children: [
          wide ? _panelHeader() : _phoneHeader(),
          Expanded(child: _body(wide)),
          if (!_loading && _error == null && _jobs.isNotEmpty) _footer(wide),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: wide
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _resetIdle(),
              onPointerMove: (_) => _resetIdle(),
              onPointerSignal: (_) => _resetIdle(),
              child: content,
            )
          : content,
    );
  }

  // ---- headers ---------------------------------------------------------

  Widget _phoneHeader() {
    return Column(
      children: [
        Container(
          color: AppColors.navy,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    const BrandMark(size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        Constants.appName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: () => _signOut(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.navyChip,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(44, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting(),
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.onNavyMuted)),
                          Text(
                            widget.session.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (!_loading && _error == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _jobs.length == 1
                                    ? '1 document waiting'
                                    : '${_jobs.length} documents waiting',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.onNavyMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_quota.known) QuotaRing(quota: _quota),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Rounded top edge of the content sheet.
        Container(
          height: 24,
          color: AppColors.navy,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelHeader() {
    return Container(
      height: 72,
      color: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const BrandMark(size: 36),
          const SizedBox(width: 16),
          Text(
            widget.session.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 16),
          if (_printer != null) ...[
            const Icon(Icons.print_outlined,
                size: 20, color: AppColors.onNavyMuted),
            const SizedBox(width: 6),
            Text(_printer!.name,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.onNavyMuted)),
            const SizedBox(width: 16),
          ],
          if (_quota.known)
            Text(
              '${_quota.left} pages left this month',
              style:
                  const TextStyle(fontSize: 16, color: AppColors.onNavyMuted),
            ),
          const Spacer(),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout,
            style: AppButtonStyle.onNavy,
            height: 48,
            fontSize: 16,
            expand: false,
            onPressed: () => _signOut(),
          ),
        ],
      ),
    );
  }

  // ---- body --------------------------------------------------------------

  Widget _body(bool wide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(
        'Cannot reach the print server.',
        'Check your connection and try again.',
        action: AppButton(
          label: 'Try again',
          expand: false,
          onPressed: _load,
        ),
      );
    }
    if (_jobs.isEmpty) {
      return _message(
        'Nothing waiting to print.',
        widget.session.demo
            ? 'This is a demo, so you can send yourself some sample documents.'
            : 'Send a file to Pull Print from your computer.',
        action: widget.session.demo
            ? AppButton(
                label: 'Send sample documents',
                expand: false,
                onPressed: () => _sendSamples(4),
              )
            : AppButton(
                label: 'Check again',
                style: AppButtonStyle.outline,
                expand: false,
                onPressed: _load,
              ),
      );
    }

    final titleStyle = TextStyle(
      fontSize: wide ? 28 : 18,
      fontWeight: wide ? FontWeight.w800 : FontWeight.w700,
    );
    final hint = TextStyle(fontSize: wide ? 16 : 14, color: AppColors.muted);
    final pad = wide ? 32.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 4, pad, wide ? 12 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(wide ? 'Your documents' : 'Waiting to print',
                    style: titleStyle),
              ),
              if (wide)
                Text('Tap a document to include or leave it out', style: hint),
              TextButton(
                onPressed: _toggleAll,
                style:
                    TextButton.styleFrom(minimumSize: Size(64, wide ? 48 : 44)),
                child: Text(_allSelected ? 'Clear' : 'Select all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: wide ? _grid(pad) : _list(pad),
          ),
        ),
        if (widget.session.demo)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad - 8),
            child: TextButton.icon(
              onPressed: () => _sendSamples(1),
              icon: const Icon(Icons.add),
              label: const Text('Send another sample document'),
            ),
          ),
      ],
    );
  }

  Widget _list(double pad) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => JobTile(
        job: _jobs[i],
        selected: _selected.contains(_jobs[i].id),
        onChanged: (on) => _toggle(_jobs[i], on),
      ),
    );
  }

  Widget _grid(double pad) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 4, pad, 16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 262 + 140 * (textScale > 1 ? textScale - 1 : 0),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _jobs.length,
      itemBuilder: (context, i) => JobCard(
        job: _jobs[i],
        selected: _selected.contains(_jobs[i].id),
        onChanged: (on) => _toggle(_jobs[i], on),
      ),
    );
  }

  Widget _message(String title, String detail, {required Widget action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.muted)),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }

  // ---- footer ------------------------------------------------------------

  String get _summary =>
      '${_count == 1 ? '1 document' : '$_count documents'} · $_pages pages';

  String? get _afterText {
    if (!_quota.known) return null;
    return _over
        ? _overText
        : '${_quota.left - _pages} pages left after printing';
  }

  String get _blockText => _printer == null
      ? 'No printer available'
      : _count == 0
          ? 'Select a document'
          : (_quota.left == 0 ? 'No pages left' : 'Over your limit');

  /// "Printer: Level 3 East" on the phone. Tap to pick another when there is a choice.
  Widget _printerRow() {
    final canPick = _printers.length > 1 && !_printerLocked && !_printing;
    final row = Row(
      children: [
        const Icon(Icons.print_outlined, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        const Text('Printer',
            style: TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _printer?.name ?? 'None set up yet',
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _printer == null ? AppColors.failedText : null,
            ),
          ),
        ),
        if (canPick)
          const Icon(Icons.expand_more, size: 20, color: AppColors.muted),
      ],
    );
    if (!canPick) return row;
    return InkWell(
      onTap: _pickPrinter,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(alignment: Alignment.center, child: row),
      ),
    );
  }

  Future<void> _pickPrinter() async {
    final picked = await showModalBottomSheet<Printer>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Print at',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final p in _printers)
              ListTile(
                minVerticalPadding: 12,
                title: Text(p.name),
                subtitle: p.location.isEmpty ? null : Text(p.location),
                trailing: p.id == _printer?.id
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _printer = picked);
  }

  Widget _footer(bool wide) {
    const shadow = [
      BoxShadow(color: Color(0x0F0E2A47), blurRadius: 18, offset: Offset(0, -6))
    ];
    if (wide) {
      return Container(
        height: 104,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_summary,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  if (_afterText != null)
                    Text(_afterText!,
                        style: TextStyle(
                          fontSize: 16,
                          color: _over ? AppColors.failedText : AppColors.muted,
                        )),
                ],
              ),
            ),
            SizedBox(
              width: 320,
              child: AppButton(
                label: _canPrint || _printing ? 'Print' : _blockText,
                icon: _canPrint || _printing ? Icons.print_outlined : null,
                height: 72,
                fontSize: 26,
                radius: 16,
                busy: _printing,
                onPressed: _canPrint ? _print : null,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: shadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _printerRow(),
              const SizedBox(height: 12),
              AppButton(
                label: _canPrint || _printing
                    ? 'Print ${_count == 1 ? '1 document' : '$_count documents'} · $_pages pages'
                    : (_printer == null
                        ? 'No printer available'
                        : (_over ? _overText : 'Select a document to print')),
                busy: _printing,
                onPressed: _canPrint ? _print : null,
              ),
              if (_over && widget.session.demo)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Demo tip: go back to sign-in and choose the administrator demo to raise your limit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
