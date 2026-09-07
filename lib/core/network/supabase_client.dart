// lib/core/network/supabase_client.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when Supabase configuration is missing or invalid.
///
/// SECURITY (C-1): this replaces the previous silent fallback to embedded
/// production credentials. A misconfigured build must fail loudly rather than
/// connect to production.
class SupabaseConfigException implements Exception {
  SupabaseConfigException(this.message);
  final String message;
  @override
  String toString() => 'SupabaseConfigException: $message';
}

class SupabaseConfig {
  static SupabaseClient? _client;

  /// Compile-time overrides for CI / web builds that cannot ship a `.env`:
  ///   flutter build web --release \
  ///     --dart-define=SUPABASE_URL=<your-project-url> \
  ///     --dart-define=SUPABASE_ANON_KEY=eyJ...
  static const String _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _defineAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Reads config from --dart-define first, then `.env`.
  /// Never falls back to an embedded credential.
  static String _readConfig(String key, String compileTimeValue) {
    final fromDefine = compileTimeValue.trim();
    if (fromDefine.isNotEmpty && !fromDefine.contains('placeholder')) {
      return fromDefine;
    }
    String fromEnv = '';
    try {
      fromEnv = (dotenv.env[key] ?? '').trim();
    } catch (_) {
      // dotenv not initialised (e.g. asset missing) — treat as absent.
      fromEnv = '';
    }
    if (fromEnv.isEmpty || fromEnv.contains('placeholder')) {
      throw SupabaseConfigException(
        '$key is not configured. Provide it via --dart-define=$key=... '
        'or in the .env asset. The app will not start with missing '
        'Supabase configuration.',
      );
    }
    return fromEnv;
  }

  static Future<void> initialize() async {
    final url = _readConfig('SUPABASE_URL', _defineUrl);
    final anonKey = _readConfig('SUPABASE_ANON_KEY', _defineAnonKey);

    // Never log the key or the full URL.
    debugPrint('SupabaseConfig: Initializing Supabase client...');

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      // Fallback if accessed before init (shouldn't happen in configured app)
      return Supabase.instance.client;
    }
    return _client!;
  }

  static User? get currentUser => client.auth.currentUser;

  /// The real Supabase user id of the offline-authenticated user, read from the
  /// `local_users` cache at offline login. Null when nobody is offline-signed-in.
  ///
  /// SECURITY (C-0b): `currentUserId` used to return a hardcoded placeholder
  /// string whenever [isOfflineLoggedIn] was true. That fabricated id was
  /// persisted as `created_by` on offline-created customers and vendors.
  /// We now return the genuine cached UUID, or null — never an invented value.
  static String? offlineUserId;

  static String? get currentUserId => currentUser?.id ?? offlineUserId;

  /// Flag to indicate if user is logged in via offline mode (bypassing Supabase session check)
  static bool isOfflineLoggedIn = false;

  /// Clears offline-session state. Call on logout.
  static void clearOfflineSession() {
    isOfflineLoggedIn = false;
    offlineUserId = null;
  }

  static String get frontendUrl {
    // 1. Check .env first (useful for local testing if someone set it to localhost)
    final envUrl = dotenv.env['FRONTEND_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // 2. Default to production Vercel URL for ALL platforms (Mobile, Mac, PC, Web)
    // This ensures links sent in emails always work for the recipient.
    return 'https://ordermate-v619.vercel.app';
  }
}
