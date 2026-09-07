import 'package:flutter/material.dart';
import 'package:ordermate/core/views/app_menu.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppMenu(),
      // We rely on child screens to provide their own AppBars to allow page-specific actions.
      // But we provide the drawer in the shell so functionality is available.
      // To open drawer from child: Scaffold.of(context).openDrawer();
      body: child,
    );
  }
}

class StaffLayout extends StatelessWidget {
  final Widget child;
  const StaffLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppMenu(),
      body: child,
    );
  }
}
