import 'package:intl/intl.dart';
import '../models/print_job.dart';

String pagesLabel(int n) => n == 1 ? '1 page' : '$n pages';

/// "Today 9:02", "Yesterday" or "3 Oct".
String whenLabel(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today ${DateFormat('H:mm').format(at)}';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM').format(at);
}

String jobMeta(PrintJob job, {DateTime? now}) =>
    '${pagesLabel(job.pages)} · ${whenLabel(job.submittedAt.toLocal(), now: now)}';

String greeting({DateTime? now}) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
