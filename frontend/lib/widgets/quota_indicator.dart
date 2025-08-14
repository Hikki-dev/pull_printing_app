import 'package:flutter/material.dart';

class QuotaIndicator extends StatelessWidget {
  final int total;
  final int used;

  const QuotaIndicator({
    super.key,
    required this.total,
    required this.used,
  });

  @override
  Widget build(BuildContext context) {
    double progress = total > 0 ? used / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          color: progress > 0.8 ? Colors.red : Colors.green,
        ),
        const SizedBox(height: 4),
        Text("$used / $total pages"),
      ],
    );
  }
}
