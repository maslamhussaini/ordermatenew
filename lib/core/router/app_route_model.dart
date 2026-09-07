import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/user_role.dart';

class AppRoute {
  final String path;
  final String title; // Display Name (Menu)
  final String? routeName; // GoRouter Name (Slug)
  final String module; // Permission Module
  final Widget Function(BuildContext, GoRouterState) builder;
  final List<UserRole> roles;
  final IconData? icon;
  final List<AppRoute> children;
  final bool showInMenu;

  /// Phase 3B-3: nullable `omtbl_app_forms.id` this route corresponds to,
  /// when the route has a direct 1:1 catalog mapping (see
  /// audit_results/PHASE3B_ARCHITECTURE_DECISIONS.md §7 for the mapping
  /// inventory this was populated from). Null for the majority of routes
  /// that have no catalog entry -- those keep their existing role-only
  /// gating, unchanged. Never invented; only set where a real, live
  /// `omtbl_app_forms` row was confirmed to exist for that exact screen.
  ///
  /// Parameterized report routes (ledger/:type, sales/:groupBy,
  /// returns/:groupBy) fan out to multiple catalog rows depending on a
  /// runtime path parameter and therefore cannot carry one static formId
  /// here -- those are resolved dynamically in app_router.dart's redirect
  /// guard via `resolveParameterizedReportFormId`.
  final int? formId;

  AppRoute({
    required this.path,
    required this.title,
    required this.module,
    required this.builder,
    required this.roles,
    this.routeName,
    this.icon,
    this.children = const [],
    this.showInMenu = true, // Defaults to true, set false for details pages
    this.formId,
  });
}
