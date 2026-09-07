// lib/features/dashboard/presentation/widgets/refresh_button.dart

import 'package:flutter/material.dart';

class RefreshButton extends StatelessWidget {
  const RefreshButton({
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.color,
  });
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.refresh, color: color),
      onPressed: onPressed,
    );
  }
}
