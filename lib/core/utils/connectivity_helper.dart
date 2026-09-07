import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityHelper {
  /// Safely checks connectivity, catching any PlatformException or other errors
  /// that might occur, especially on Windows or when the platform channel is unstable.
  static Future<List<ConnectivityResult>> check() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (e) {
      debugPrint('ConnectivityHelper: Failed to check connectivity: $e');
      // If native check fails, assume we ARE online so that we attempt the request
      // and handle any SocketException later. This is safer than assuming 'none'
      // which might block all operations.
      return [ConnectivityResult.wifi];
    }
  }

  /// Returns true if the device is definitely offline based on the check.
  static Future<bool> isOffline() async {
    final results = await check();
    return results.contains(ConnectivityResult.none);
  }

  /// Returns true if the device has some potential connectivity.
  static Future<bool> isOnline() async {
    return !(await isOffline());
  }
}
