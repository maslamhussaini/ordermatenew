import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final double opacity;
  final Color? color;
  final Widget? progressIndicator;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.opacity = 0.5,
    this.color,
    this.progressIndicator,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetList = [child];
    if (isLoading) {
      Widget modal = Stack(
        children: [
          Opacity(
            opacity: opacity,
            child:
                ModalBarrier(dismissible: false, color: color ?? Colors.black),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                progressIndicator ?? const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
      widgetList.add(modal);
    }
    return Stack(children: widgetList);
  }
}
