import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/features/location_tracking/presentation/screens/location_history_screen.dart';

final List<AppRoute> locationRoutes = [
  AppRoute(
    path: '/location-tracker',
    title: 'Location Tracker',
    routeName: RouteNames.locationTracker,
    module: 'location_tracking',
    icon: Icons.location_on_outlined,
    roles: [UserRole.admin],
    builder: (_, __) => const LocationHistoryScreen(),
  ),
];
