import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/build_info.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isLocationDenied = false;
  bool _isCheckingLocation = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Splash: initState');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Start Check Loop
    _checkLocationAndAuth();
  }

  Future<void> _checkLocationAndAuth() async {
    debugPrint('Splash: _checkLocationAndAuth invoked');
    debugPrint('Splash: Starting checks...');
    await Future.delayed(const Duration(seconds: 3));
    debugPrint('Splash: 3s delay over. Checking location...');
    await _enforceLocationPermission();
  }

  // Location is optional -- it must never permanently prevent the user from
  // reaching Login/Dashboard. Every branch below either proceeds to
  // _checkAuth() directly, or ends in _handleLocationUnavailable(), which
  // always offers a Continue path to _checkAuth().
  Future<void> _enforceLocationPermission() async {
    if (!mounted) return;
    debugPrint('Splash: Enforcing location permission...');

    // Bypass location check in Debug Mode (Web/Windows) to prevent stuck splash
    if (kDebugMode) {
      debugPrint('Splash: Debug mode detected. Bypassing location check.');
      _checkAuth();
      return;
    }

    setState(() => _isCheckingLocation = true);

    try {
      // 1. Check Service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Splash: Location service disabled.');
        _handleLocationUnavailable('Location services are disabled.');
        return;
      }

      // 2. Check Permission
      var permission = await Geolocator.checkPermission();
      debugPrint('Splash: Current permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Splash: Requested permission result: $permission');
        if (permission == LocationPermission.denied) {
          _handleLocationUnavailable('Location permission was not granted.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Splash: Permission denied forever.');
        _handleLocationUnavailable('Location permission is denied.');
        return;
      }

      // Permission Granted -> Proceed to Auth Check
      debugPrint('Splash: Location granted. Checking auth...');
      // Best-effort background capture so customer/booker tracing has a
      // last-known location even if the user later disables permission/service.
      LocationHelper.captureAndCacheLocation().catchError((e) {
        debugPrint('Splash: Background location capture failed: $e');
      });
      _checkAuth();
    } catch (e) {
      // Covers platform/browser errors -- e.g. the Geolocation API being
      // unavailable on an insecure (non-HTTPS, non-localhost) web origin,
      // where the browser refuses the request outright. Never leave the
      // user stuck on a spinner: treat it the same as denied.
      debugPrint('Splash: Error checking location: $e');
      _handleLocationUnavailable('Location is currently unavailable.');
    }
  }

  void _handleLocationUnavailable(String reason) {
    if (!mounted) return;
    setState(() {
      _isLocationDenied = true;
      _isCheckingLocation = false;
    });
    _showLocationDialog(reason);
  }

  void _showLocationDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location Unavailable'),
        content: Text(
          '$reason\n\n'
          'You can continue using the application. Some location-based '
          'features may be unavailable until location access is enabled.'
          '${kIsWeb ? '\n\nOn the web, location permission is controlled by '
              'your browser. Look for a location icon in the address bar, or '
              "check your browser's site settings, then try again." : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _enforceLocationPermission();
            },
            child: const Text('Try Again'),
          ),
          // Open Settings is a native OS feature. geolocator does not
          // support it on web (there is no OS-level settings screen for a
          // browser tab to open) -- never show or call it there.
          if (!kIsWeb)
            TextButton(
              onPressed: () async {
                try {
                  await Geolocator.openAppSettings();
                } catch (e) {
                  debugPrint('Splash: openAppSettings failed: $e');
                }
              },
              child: const Text('Open Settings'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _checkAuth();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAuth() async {
    debugPrint('Splash: _checkAuth invoked');
    debugPrint('Splash: _checkAuth started.');
    if (!mounted) return;

    try {
      final hasSession = SupabaseConfig.currentUser != null ||
          SupabaseConfig.isOfflineLoggedIn;
      final isOffline = SupabaseConfig.isOfflineLoggedIn;
      debugPrint('Splash: hasSession=$hasSession, isOfflineLoggedIn=$isOffline');

      if (hasSession) {
        debugPrint('Splash: Session detected. Loading profile (with safety timeout)...');

        // Ensure dynamic permissions/role are loaded before navigating
        // Added safety timeout to prevents stuck splash screen
        final permissionsStart = DateTime.now();
        await ref
            .read(authProvider.notifier)
            .loadDynamicPermissions()
            .timeout(const Duration(seconds: 15))
            .catchError((e) {
              debugPrint('Splash: Permission load timed out or failed: $e');
              return null;
            });
        final permissionsEnd = DateTime.now();
        debugPrint(
            'Splash: loadDynamicPermissions completed in ${permissionsEnd.difference(permissionsStart).inMilliseconds}ms');

        if (!mounted) return;

        debugPrint('Splash: BEFORE OnboardingStateService.resumeData()');
        final resumeDataStart = DateTime.now();
        Map<String, dynamic>? resumeData;
        try {
          resumeData = await OnboardingStateService.resumeData();
        } catch (e) {
          debugPrint('Splash: resumeData threw exception: $e');
          debugPrint('Splash: resumeData stack trace: ${StackTrace.current}');
          rethrow;
        }
        final resumeDataEnd = DateTime.now();
        debugPrint(
            'Splash: resumeData completed in ${resumeDataEnd.difference(resumeDataStart).inMilliseconds}ms');
        debugPrint('Splash: resumeData result = $resumeData');
        debugPrint('SPLASH RESUME DATA = $resumeData');

        if (resumeData != null) {
          final route = resumeData['route'] as String?;
          debugPrint('Splash: resumeData route = $route');
            if (route != null) {
              if (route == '/onboarding/team' || route == '/onboarding/verify') {
                final orgId = resumeData['orgId'] as int;
                final storeId = resumeData['storeId'] as int;
                final email = resumeData['email'] as String;
                debugPrint('Splash navigation: FROM=/splash TO=$route REASON=onboarding_resume');
                debugPrint('SPLASH NAVIGATION = $route');
                context.go(route, extra: {
                  'orgId': orgId,
                  'storeId': storeId,
                  'email': email,
                });
                return;
              } else if (route == '/onboarding/store') {
                final email = resumeData['email'] as String;
                debugPrint('Splash navigation: FROM=/splash TO=/onboarding/store REASON=onboarding_resume_store');
                debugPrint('SPLASH NAVIGATION = /onboarding/store');
                context.go('/onboarding/store', extra: {
                  'userData': {'email': email},
                  'orgData': const {},
                });
                return;
              }
            }
        }

        debugPrint('Splash: FALLBACK TO WORKSPACE-SELECTION because resumeData == null or no valid route');
        debugPrint('SPLASH NAVIGATION = /workspace-selection');
        debugPrint('Splash: Triggering Sync...');
        ref.read(syncServiceProvider).syncAll();

        debugPrint('Splash: Navigating to /workspace-selection');
        context.go('/workspace-selection');
      } else {
        debugPrint('Splash: No session, navigating to /login');
        if (mounted) context.go('/login');
      }
    } catch (e) {
      debugPrint('Splash: Critical error in _checkAuth: $e');
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    debugPrint('Splash: dispose');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Stack(
          children: [
            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Column(
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'Order Mate',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Contrast on dark gradient
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_isLocationDenied && !_isCheckingLocation)
                    Column(
                      children: [
                        const Text(
                          'Location access is currently unavailable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Some location-based features may be limited.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        // Safety net in addition to the dialog's own
                        // buttons -- location must never be a dead end.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: _enforceLocationPermission,
                              child: const Text('Try Again'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _checkAuth,
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    FadeTransition(
                      opacity: _opacityAnimation,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.loginGradientStart),
                      ),
                    ),
                ],
              ),
            ),

            // Footer (Powered By + Version)
            Positioned(
              bottom: 24,
              right: 24,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Powered by ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Triangletech Logo
                        Image.asset(
                          'assets/images/triangletech_logo.jpg',
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $appVersion • $buildTime',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
