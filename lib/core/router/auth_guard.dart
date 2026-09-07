import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ordermate/core/providers/auth_provider.dart';

String? authGuard(BuildContext context, GoRouterState state, String landingPage,
    AuthState auth) {
  final isAuthenticated = auth.isLoggedIn;
  final isGoingToLogin = state.matchedLocation == '/login';
  final isGoingToSplash = state.matchedLocation == '/splash';
  final isGoingToRegister = state.matchedLocation == '/register' ||
      state.matchedLocation == '/signup';
  final isGoingToOnboarding = state.matchedLocation.startsWith('/onboarding');
  final isGoingToResetPassword = state.matchedLocation == '/reset-password';

  debugPrint(
      'authGuard: location=${state.matchedLocation}, isAuthenticated=$isAuthenticated, isGoingToLogin=$isGoingToLogin, isGoingToSplash=$isGoingToSplash, isGoingToRegister=$isGoingToRegister, isGoingToOnboarding=$isGoingToOnboarding');

  // Allow splash screen
  if (isGoingToSplash) {
    debugPrint('authGuard: allowing splash');
    return null;
  }

  // Password Recovery Flow
  if (auth.isPasswordRecovery) {
    if (!isGoingToResetPassword) {
      debugPrint('authGuard: redirecting to /reset-password');
      return '/reset-password';
    }
    debugPrint('authGuard: allowing reset-password');
    return null;
  }

  // Redirect to login if not authenticated and not going to public routes
  if (!isAuthenticated &&
      !isGoingToLogin &&
      !isGoingToResetPassword &&
      !isGoingToRegister &&
      !isGoingToOnboarding) {
    debugPrint('authGuard: not authenticated, redirecting to /login');
    return '/login';
  }

  // Redirect to workspace selection if authenticated and going to login or register
  if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
    debugPrint('authGuard: authenticated but going to login/register, redirecting to /workspace-selection');
    return '/workspace-selection';
  }

  debugPrint('authGuard: allowing ${state.matchedLocation}');
  return null;
}
