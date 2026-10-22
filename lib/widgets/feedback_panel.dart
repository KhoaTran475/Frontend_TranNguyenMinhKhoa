import 'package:flutter/material.dart';

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.message,
    this.retry,
    this.error = true,
  });
  final String message;
  final VoidCallback? retry;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: error ? colors.errorContainer : colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: error
                    ? colors.onErrorContainer
                    : colors.onPrimaryContainer,
              ),
            ),
            if (retry != null)
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
          ],
        ),
      ),
    );
  }
}
