// lib/app.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/core/router/app_router.dart';
import 'package:ordermate/core/services/connectivity_provider.dart';
import 'package:ordermate/core/theme/app_theme.dart';
import 'package:ordermate/core/utils/bug_reporter.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/location_tracking/presentation/providers/location_tracking_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:screenshot/screenshot.dart';

class OrderMateApp extends ConsumerWidget {
  const OrderMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    // Track location if logged in
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && !(previous?.isLoggedIn ?? false)) {
        ref.read(locationTrackingProvider.notifier).startTracking();
      } else if (!next.isLoggedIn && (previous?.isLoggedIn ?? false)) {
        ref.read(locationTrackingProvider.notifier).stopTracking();
      }
    });

    return MaterialApp.router(
      title: 'Order Mate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(settings.fontFamily, settings.themeColor),
      darkTheme: AppTheme.darkTheme(settings.fontFamily, settings.themeColor),
      themeMode: settings.themeMode,

      // Localization
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ur', ''), // Urdu
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: router,

      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: true,
        physics: const BouncingScrollPhysics(),
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),

      // Global Builder for Offline Overlay & Bug Reporting Screenshot
      builder: (context, child) {
        return Consumer(builder: (context, ref, _) {
          final connection = ref.watch(connectivityProvider);
          final screenshotController = ref.watch(screenshotControllerProvider);

          return Screenshot(
            controller: screenshotController,
            child: Stack(
              children: [
                if (child != null) child,
                // Offline Indicator
                if (connection == ConnectionStatus.offline)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.redAccent,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Offline Mode',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }
}
