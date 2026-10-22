import 'package:flutter/material.dart';
import '../models/print_job.dart';
import '../utils/format.dart';
import '../utils/theme.dart';
import 'doc_thumbnail.dart';

/// A job as a full-width row, for phones. The whole row toggles selection.
class JobTile extends StatelessWidget {
  final PrintJob job;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const JobTile({
    super.key,
    required this.job,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.lineSoft,
            width: 2,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x240B5CAD), blurRadius: 14, offset: Offset(0, 4))]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(!selected),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Row(
                children: [
                  DocThumbnail(fileName: job.fileName, width: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          jobMeta(job),
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 1.3,
                    child: Checkbox(
                      value: selected,
                      onChanged: (v) => onChanged(v ?? false),
                      semanticLabel: 'Select ${job.fileName}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A job as a card with a large preview, for the printer panel.
class JobCard extends StatelessWidget {
  final PrintJob job;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const JobCard({
    super.key,
    required this.job,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.lineSoft,
          width: 3,
        ),
        boxShadow: selected
            ? const [BoxShadow(color: Color(0x2E0B5CAD), blurRadius: 18, offset: Offset(0, 6))]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Container(
                    height: 176,
                    color: AppColors.thumbBackground,
                    alignment: Alignment.center,
                    child: DocThumbnail(fileName: job.fileName, width: 120),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Transform.scale(
                      scale: 1.5,
                      child: Checkbox(
                        value: selected,
                        onChanged: (v) => onChanged(v ?? false),
                        semanticLabel: 'Include ${job.fileName}',
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jobMeta(job),
                      style: const TextStyle(fontSize: 15, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
