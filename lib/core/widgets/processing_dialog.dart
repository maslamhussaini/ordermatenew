import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ProcessingDialog extends StatefulWidget {
  final Future<void> Function() task;
  final String initialMessage;
  final String successMessage;
  final String errorMessage;
  final Duration successDuration;
  final ValueNotifier<double>? progressNotifier;
  final ValueNotifier<String>? messageNotifier;

  const ProcessingDialog({
    super.key,
    required this.task,
    this.initialMessage = 'Processing...',
    this.successMessage = 'Success!',
    this.errorMessage = 'Failed',
    this.successDuration = const Duration(seconds: 2),
    this.progressNotifier,
    this.messageNotifier,
  });

  @override
  State<ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<ProcessingDialog>
    with SingleTickerProviderStateMixin {
  late String _message;
  bool _isSuccess = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;

    // Listen to message updates
    widget.messageNotifier?.addListener(_updateMessage);

    _runTask();
  }

  @override
  void dispose() {
    widget.messageNotifier?.removeListener(_updateMessage);
    super.dispose();
  }

  void _updateMessage() {
    if (mounted && widget.messageNotifier != null) {
      setState(() {
        _message = widget.messageNotifier!.value;
      });
    }
  }

  Future<void> _runTask() async {
    try {
      await widget.task();
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _message = widget.successMessage;
        });

        // Wait and close
        await Future.delayed(widget.successDuration);
        if (mounted) {
          Navigator.of(context).pop(true); // Return true for success
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = '${widget.errorMessage}: $e';
        });

        // Wait and close (longer for error)
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pop(false); // Return false for failure
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _buildIcon(),
            ),
            const SizedBox(height: 24),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_isSuccess) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 64,
        key: ValueKey('success'),
      );
    } else if (_isError) {
      return const Icon(
        Icons.error,
        color: Colors.red,
        size: 64,
        key: ValueKey('error'),
      );
    } else if (widget.progressNotifier != null) {
      return ValueListenableBuilder<double>(
        key: const ValueKey('progress'),
        valueListenable: widget.progressNotifier!,
        builder: (context, value, child) {
          // If value is 0 or indeterminate, show spinner, otherwise show progress
          // Actually user wants percentage, so if value is valid (>=0), show it.
          // Let's assume passed 0.0 starts as 0%.
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          );
        },
      );
    } else {
      return const SpinKitFadingCircle(
        color: Colors.blue,
        size: 64,
        key: ValueKey('loading'),
      );
    }
  }
}
