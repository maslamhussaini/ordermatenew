// lib/main.dart

import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/app.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/notification_service.dart';
import 'package:ordermate/core/utils/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // Web support
import 'package:ordermate/core/utils/bug_reporter.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // Add this for path URL strategy

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Path URL Strategy for Web
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize database factory
  try {
    if (kIsWeb) {
      // Web Initialization
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop Initialization
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    // We continue so the app can still run in online-only mode
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables
  try {
    await dotenv.load();
  } catch (e) {
    AppLogger.error('Error loading .env file', e);
  }

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize Notification Service
  try {
    await NotificationService().init();
  } catch (e) {
    AppLogger.error('Failed to init notifications', e);
  }

  // Initialize Logger
  AppLogger.initialize();

  // Create ProviderContainer to access services before/outside widget tree
  final container = ProviderContainer();

  // 1. Capture Flutter Framework Errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    container.read(bugReportServiceProvider).reportError(
          details.exceptionAsString(),
          details.stack,
        );
  };

  // 2. Capture Platform/Async Errors
  PlatformDispatcher.instance.onError = (error, stack) {
    container.read(bugReportServiceProvider).reportError(error, stack);
    return true; // Error handled
  };

  // Run the app with Riverpod
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OrderMateApp(),
    ),
  );
}
