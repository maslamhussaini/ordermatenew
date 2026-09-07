import 'package:flutter/material.dart';

class ImportProgress {
  const ImportProgress({
    this.processed = 0,
    this.total = 0,
    this.success = 0,
    this.failed = 0,
    this.duplicate = 0,
  });
  final int processed;
  final int total;
  final int success;
  final int failed;
  final int duplicate;

  int get remaining => total > 0 ? total - processed : 0;
}

class BatchImportDialog extends StatelessWidget {
  const BatchImportDialog({
    required this.title,
    required this.progressNotifier,
    required this.onStop,
    super.key,
  });
  final String title;
  final ValueNotifier<ImportProgress> progressNotifier;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor:
            const Color(0xFFEBEFF5), // Light greyish blue from image
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<ImportProgress>(
            valueListenable: progressNotifier,
            builder: (context, progress, child) {
              final percent = progress.total == 0
                  ? 0.0
                  : (progress.processed / progress.total).clamp(0.0, 1.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400, // Clean look
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green), // Or primary color
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats Text
                  Text(
                    'Processing: ${progress.processed} / ${progress.total}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Remaining: ${progress.remaining}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Counters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCounter(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        count: progress.success,
                        label: 'Success',
                      ),
                      _buildCounter(
                        icon: Icons.copy, // Duplicate icon
                        color: Colors.orange,
                        count: progress.duplicate,
                        label: 'Skipped',
                      ),
                      _buildCounter(
                        icon: Icons.error,
                        color: Colors.red,
                        count: progress.failed,
                        label: 'Failed',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stop Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onStop,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Stop'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(
      {required IconData icon,
      required Color color,
      required int count,
      required String label}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}
