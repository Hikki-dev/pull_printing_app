import 'package:flutter/material.dart';
import '../models/print_job.dart';

class JobCard extends StatelessWidget {
  final PrintJob job;
  final VoidCallback? onRelease; // null => no actions for users

  const JobCard({
    super.key,
    required this.job,
    this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = '${job.userName} • ${job.pages} pages • ${job.submittedAt.toLocal()}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.print),
        title: Text(job.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: onRelease == null
            ? const SizedBox.shrink()
            : ElevatedButton(
                onPressed: onRelease,
                child: const Text('Release'),
              ),
      ),
    );
  }
}
