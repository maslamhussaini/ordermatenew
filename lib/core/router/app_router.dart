import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/app_routes_config.dart';
import 'package:ordermate/core/router/report_catalog_map.dart';
import 'package:ordermate/features/entitlement/presentation/providers/entitlement_providers.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/router/auth_guard.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/views/responsive_scaffold.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';

// Public/Auth Screens outside the Shell
import 'package:ordermate/features/auth/presentation/screens/login_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/register_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/splash_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/organization_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/organization_configure_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/store_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/team_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/email_verification_screen.dart';

// Helper to convert AppRoutes to GoRoutes recursively
List<GoRoute> buildGoRoutes(List<AppRoute> routes) {
  return routes.map((r) {
    return GoRoute(
      path: r.path,
      name: r.routeName,
      builder: r.builder,
      routes: buildGoRoutes(r.children),
    );
  }).toList();
}

// Helper to find metadata
AppRoute? findAppRoute(List<AppRoute> routes, String location,
    {String parentPath = ''}) {
  final cleanLocation = location.split('?').first;

  for (final route in routes) {
    // Construct full path for comparison
    String fullPath = route.path;
    if (!fullPath.startsWith('/') && parentPath.isNotEmpty) {
      fullPath = parentPath.endsWith('/')
          ? '$parentPath$fullPath'
          : '$parentPath/$fullPath';
    }

    // Normalize path to remove double slashes
    fullPath = fullPath.replaceAll('//', '/');

    // Simple path matching logic (handling :id parameters)
    if (_pathMatches(fullPath, cleanLocation)) {
      // If there are children, try to find a deeper match first
      if (route.children.isNotEmpty) {
        final childMatch =
            findAppRoute(route.children, cleanLocation, parentPath: fullPath);
        if (childMatch != null) return childMatch;
      }
      return route;
    }

    // Recurse if the current route is a parent prefix of the target location
    // Ensure we only match true parents (e.g. /accounting matches /accounting/coa but not /accounting-reports)
    final isParent = fullPath.startsWith('/') &&
        (cleanLocation.startsWith('$fullPath/') || cleanLocation == fullPath);

    if (isParent && route.children.isNotEmpty) {
      final childMatch =
          findAppRoute(route.children, cleanLocation, parentPath: fullPath);
      if (childMatch != null) return childMatch;
    }
  }
  return null;
}

bool _pathMatches(String routePath, String location) {
  if (routePath == location) return true;

  // Handle path parameters like :id
  final pattern =
      routePath.replaceAllMapped(RegExp(r':\w+'), (match) => r'[^/]+');
  final regex = RegExp('^' + pattern + r'$');
  return regex.hasMatch(location);
}

final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.read to keep the GoRouter instance stable across state changes.
  // This prevents the application from resetting to the initial route (/splash) 
  // every time a dependency changes, which was causing the infinite loop.

  return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      redirect: (context, state) async {
        final settings = ref.read(settingsProvider);
        final auth = ref.read(authProvider);
        final location = state.matchedLocation;
        debugPrint('[ROUTER-DIAG] REDIRECT START');
        debugPrint('[ROUTER-DIAG] state.matchedLocation = $location');
        debugPrint('[ROUTER-DIAG] state.uri = ${state.uri}');
        debugPrint('[ROUTER-DIAG] auth.isLoggedIn = ${auth.isLoggedIn}');
        debugPrint('[ROUTER-DIAG] isPermissionLoading = ${auth.isPermissionLoading}');
        debugPrint('Router: Redirect check for $location');
        debugPrint(
            'Router: auth.isLoggedIn=${auth.isLoggedIn}, isPermissionLoading=${auth.isPermissionLoading}');

        // 0. Safeguard for Supabase tokens
        if (location.contains('access_token')) {
          debugPrint('Router: Token detected in path, redirecting to splash');
          debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /splash REASON = access_token');
          return '/splash';
        }

        // 1. Password Recovery Guard
        if (auth.isPasswordRecovery &&
            state.matchedLocation != '/reset-password') {
          debugPrint('Router: Redirecting to /reset-password');
          debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /reset-password REASON = password_recovery');
          return '/reset-password';
        }

        // 2. Auth Check (Login/Splash logic)
        final authRedirect =
            authGuard(context, state, settings.landingPage, auth);
        if (authRedirect != null) {
          debugPrint('Router: authGuard returned $authRedirect');
          debugPrint('[ROUTER-DIAG] RETURN REDIRECT = $authRedirect REASON = authGuard');
          return authRedirect;
        }

        // 2b. Onboarding resume check for authenticated users
        final isCurrentlyOnOnboarding = location.startsWith('/onboarding');
        if (auth.isLoggedIn && !isCurrentlyOnOnboarding) {
          final resumeData = await OnboardingStateService.resumeData();
          debugPrint('Router: OnboardingStateService.resumeData() = $resumeData');
          debugPrint('[ROUTER-DIAG] onboarding_resume = $resumeData');
          if (resumeData != null) {
            final resumeRoute = resumeData['route'] as String?;
            if (resumeRoute != null &&
                (resumeRoute == '/onboarding/team' ||
                 resumeRoute == '/onboarding/verify' ||
                 resumeRoute == '/onboarding/store')) {
              debugPrint(
                  'Router: Resuming onboarding route $resumeRoute from persisted state');
              debugPrint(
                  '[ROUTER-DIAG] RETURN REDIRECT = $resumeRoute REASON = onboarding_resume');
              return resumeRoute;
            }
          }
        }

        // 3. Logic for Logged In Users
        if (!auth.isLoggedIn) {
          debugPrint('Router: Not logged in, allowing');
          debugPrint('[ROUTER-DIAG] RETURN NULL REASON = not_logged_in');
          return null;
        }

        if (settings.offlineMode) {
          debugPrint('Router: Offline mode, allowing');
          debugPrint('[ROUTER-DIAG] RETURN NULL REASON = offline_mode');
          return null;
        }

        // 4. Workspace Selection check
        final orgState = ref.read(organizationProvider);
        final isWorkspaceSelected = orgState.selectedOrganization != null &&
            orgState.selectedStore != null &&
            orgState.selectedFinancialYear != null;

        debugPrint(
            'Router: Workspace selected=$isWorkspaceSelected, org=${orgState.selectedOrganizationId}, store=${orgState.selectedStoreId}, year=${orgState.selectedFinancialYear}');
        debugPrint(
            '[ROUTER-DIAG] selectedOrganizationId = ${orgState.selectedOrganizationId}');
        debugPrint(
            '[ROUTER-DIAG] selectedStoreId = ${orgState.selectedStoreId}');
        debugPrint(
            '[ROUTER-DIAG] selectedFinancialYear = ${orgState.selectedFinancialYear}');

        // final location = state.matchedLocation; // Moved to top

        // Exempt onboarding and workspace-selection
        final isWorkspacePath = location.startsWith('/workspace-selection') ||
            location == '/organizations-list' ||
            location.startsWith('/onboarding') ||
            location.startsWith('/module-access') ||
            location == '/splash';

        debugPrint(
            'Router: isWorkspacePath=$isWorkspacePath, isWorkspaceSelected=$isWorkspaceSelected');
        debugPrint(
            '[ROUTER-DIAG] isWorkspacePath = $isWorkspacePath, isWorkspaceSelected = $isWorkspaceSelected');
        debugPrint('ROUTER LOCATION = $location');
        debugPrint('SELECTED ORG = ${orgState.selectedOrganization?.id}');
        debugPrint('SELECTED STORE = ${orgState.selectedStore?.id}');
        debugPrint('IS WORKSPACE SELECTED = $isWorkspaceSelected');

        if (!isWorkspaceSelected && !isWorkspacePath) {
          debugPrint(
              'Router: Workspace missing (Org: ${orgState.selectedOrganizationId}, Store: ${orgState.selectedStoreId}, Year: ${orgState.selectedFinancialYear}). Redirecting.');
          debugPrint('WORKSPACE-SELECTION NAVIGATION: SOURCE=app_router.redirect CONDITION=workspace_missing');
          debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /workspace-selection REASON = workspace_missing');
          debugPrint('WORKSPACE REDIRECT = true');
          return '/workspace-selection';
        }

        if (isWorkspaceSelected && location.startsWith('/workspace-selection')) {
          debugPrint('Router: Workspace selected and on workspace-selection, allowing');
          debugPrint('[ROUTER-DIAG] RETURN NULL REASON = workspace_selected_and_on_workspace_selection');
          return null;
        }

        // 5. Permission & Role Guard
        if (auth.isPermissionLoading) {
          debugPrint('Router: Permissions loading, skipping RBAC for $location');
          debugPrint('[ROUTER-DIAG] RETURN NULL REASON = permissions_loading');
          return null;
        }

        if (location.startsWith('/workspace-selection')) {
          debugPrint('Router: On workspace-selection, allowing');
          debugPrint('[ROUTER-DIAG] RETURN NULL REASON = on_workspace_selection');
          return null;
        }

        final route = findAppRoute(appRoutes, location);

        if (route != null) {
          if (auth.role != UserRole.superUser &&
              !route.roles.contains(auth.role)) {
            debugPrint('RBAC: Role ${auth.role} denied for $location');
            debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /dashboard REASON = role_denied');
            return '/dashboard';
          }

          if (!auth.can(route.module, Permission.read)) {
            debugPrint('RBAC: Permission Read denied for ${route.module}');
            debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /dashboard REASON = permission_denied');
            return '/dashboard';
          }

          // 6. Commercial Entitlement Guard.
          //
          // Catalog-backed routes (a static AppRoute.formId, or one of the
          // three parameterized report routes resolved via
          // resolveParameterizedReportFormId) go through the Phase 3B-2
          // EffectiveAccessService -- the one place that correctly branches
          // legacy (boolean flags) vs explicit (omtbl_module_access_items)
          // entitlement. Non-catalog routes keep the original
          // Organization.isModuleEnabled() check unchanged, exactly as
          // before Phase 3B-3 -- see PHASE3B_ARCHITECTURE_DECISIONS.md §7
          // for which routes do/don't have a catalog mapping.
          final org = orgState.selectedOrganization;

          final catalogFormId = route.formId ??
              (route.module == 'reports'
                  ? resolveParameterizedReportFormId(
                      route.routeName, state.pathParameters)
                  : null);

              if (auth.role != UserRole.superUser && org != null) {
                if (catalogFormId != null) {
                  bool entitled;
                  try {
                    debugPrint('[ENTITLEMENT-TRACE] org=${org.id}, formId=$catalogFormId, calling formAccessProvider.future -> effectiveFormAccess');
                    entitled = route.module == 'reports'
                        ? await ref.read(reportAccessProvider(catalogFormId).future)
                        : await ref.read(formAccessProvider(catalogFormId).future);
                    debugPrint('[ENTITLEMENT-TRACE] org=${org.id}, formId=$catalogFormId, result=$entitled');
                  } catch (e) {
                    // Never fail open on a lookup error -- deny and log, same as
                    // an explicit "not entitled" result.
                    debugPrint(
                        'RBAC: Entitlement lookup failed for form $catalogFormId ($location): $e');
                    entitled = false;
                  }

              if (!entitled) {
                debugPrint(
                    'RBAC: Form/report $catalogFormId not commercially entitled for org ${org.id}, denying $location');
                debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /dashboard REASON = not_commercially_entitled');
                return '/dashboard';
              }
            } else if (!org.isModuleEnabled(route.module)) {
              debugPrint(
                  'RBAC: Module "${route.module}" not enabled for org ${org.id}, denying $location');
              debugPrint('[ROUTER-DIAG] RETURN REDIRECT = /dashboard REASON = module_not_enabled');
              return '/dashboard';
            }
          }
        }

        debugPrint('Router: No redirect for $location');
        debugPrint('[ROUTER-DIAG] RETURN NULL REASON = no_redirect');
        return null;
      },
      // GoRouter automatically listens to this if it manages to survive rebuilds, 
      // but since we watch at top level, recreated GoRouter will pick up new state.
      // We can actually omit refreshListenable if we watch at top level, 
      // but keeping it doesn't hurt as long as it doesn't use the ref in a stale way.
      refreshListenable: _RiverpodListenable(ref), 
      routes: [
        GoRoute(
            path: '/splash',
            name: RouteNames.splash,
            builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: '/login',
            name: RouteNames.login,
            builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/register',
            name: RouteNames.register,
            builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/signup', redirect: (_, __) => '/register'),
        GoRoute(
            path: '/reset-password',
            name: RouteNames.resetPassword,
            builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(
            path: '/organizations',
            redirect: (context, state) => '/organizations-list'),
        GoRoute(
            path: '/onboarding',
            redirect: (context, state) => state.fullPath == '/onboarding'
                ? '/onboarding/organization'
                : null,
            routes: [
              GoRoute(
                  path: 'organization',
                  builder: (context, state) => OrganizationSetupScreen(
                      userData: state.extra as Map<String, dynamic>)),
              GoRoute(
                  path: 'store',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>;
                    return StoreSetupScreen(
                        userData: extra['userData'] as Map<String, dynamic>,
                        orgData: extra['orgData'] as Map<String, dynamic>);
                  }),
               GoRoute(
                   path: 'team',
                   builder: (context, state) {
                     final extra = state.extra as Map<String, dynamic>?;
                     return TeamSetupScreen(
                         onboardingData: extra ?? const {});
                   }),
               GoRoute(
                   path: 'verify',
                   builder: (context, state) {
                     final extra = state.extra as Map<String, dynamic>?;
                     return EmailVerificationScreen(
                         onboardingData: extra ?? const {});
                   }),
              GoRoute(
                  path: 'configure/:orgId',
                  builder: (context, state) {
                    final orgIdStr = state.pathParameters['orgId'];
                    final orgId = int.tryParse(orgIdStr ?? '') ?? 0;
                    return OrganizationConfigureScreen(orgId: orgId);
                  }),
            ]),

        ShellRoute(
          builder: (context, state, child) {
            return ResponsiveScaffold(state: state, child: child);
          },
          routes: buildGoRoutes(appRoutes),
        ),

        // Catch-all route for malformed URLs or Supabase tokens
        GoRoute(
            path: '/:catchAll(.*)', builder: (_, __) => const SplashScreen()),
      ],
      errorBuilder: (context, state) => Scaffold(
          body: Center(child: Text('Page Not Found: ${state.error}'))));
});

// Helper class to make GoRouter listen to Riverpod
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => _safeNotify());
    ref.listen(settingsProvider, (_, __) => _safeNotify());
    ref.listen(organizationProvider, (_, __) => _safeNotify());
  }

  void _safeNotify() {
    // notifyListeners() can lead to synchronous redirect() call.
    // If redirect() uses ref.read(), it might trigger an assertion if called
    // while a provider is still updating its dependencies.
    // Using microtask ensures it runs after the current build/update cycle.
    Future.microtask(() => notifyListeners());
  }
}
