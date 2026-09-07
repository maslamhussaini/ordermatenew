import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/features/module_access/presentation/screens/module_config_screen.dart';

final List<AppRoute> moduleAccessRoutes = [
  AppRoute(
    path: '/module-config',
    title: 'Module Configuration',
    routeName: 'moduleConfig',
    module: 'admin', // Accessible module
    icon: Icons.settings_applications,
    roles: [UserRole.admin],
    builder: (_, __) => const ModuleConfigScreen(),
  ),
];
