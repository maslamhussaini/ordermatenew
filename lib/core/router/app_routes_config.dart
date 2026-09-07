import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/features/dashboard/presentation/screens/dashboard_screen.dart';

// Module Route Imports
import 'package:ordermate/features/customers/customer_routes.dart';
import 'package:ordermate/features/accounting/accounting_routes.dart';
import 'package:ordermate/features/location_tracking/location_routes.dart';
import 'package:ordermate/core/router/misc_routes.dart';
import 'package:ordermate/features/module_access/module_access_routes.dart';

final List<AppRoute> appRoutes = [
  // Dashboard (Landing)
  AppRoute(
    path: '/dashboard',
    title: 'Dashboard',
    routeName: RouteNames.dashboard,
    module: 'dashboard',
    icon: Icons.dashboard,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, state) => DashboardScreen(
      initialSelection: state.extra as Map<String, dynamic>?,
    ),
  ),

  // Module Routes (Lazy Loaded / Merged)
  ...customerRoutes,
  ...orderRoutes,
  ...invoiceRoutes,
  ...productRoutes,
  ...inventoryRoutes,
  ...accountingRoutes,
  ...vendorRoutes,
  ...employeeRoutes,
  ...branchRoutes,
  ...organizationRoutes,
  ...reportRoutes,
  ...coreRoutes,
  ...locationRoutes,
  ...moduleAccessRoutes,
];
