import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

enum ConnectionStatus {
  online,
  offline,
}

class ConnectivityServiceNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityServiceNotifier(this._ref, {bool initialOffline = false})
      : super(initialOffline
            ? ConnectionStatus.offline
            : ConnectionStatus.online) {
    _init();
  }

  final Ref _ref;
  ConnectionStatus _previousStatus = ConnectionStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void _init() async {
    // Check initial status
    try {
      final result = await ConnectivityHelper.check();
      _updateStatus(result);
    } catch (e) {
      debugPrint('Connectivity: Initial check failed: $e');
      // On some platforms, even checkConnectivity might fail.
      // Assume offline or online based on a safe default.
    }

    // Listen for changes
    _setupStream();
  }

  void _setupStream() {
    try {
      // Clear existing subscription if any
      _subscription?.cancel();

      _subscription = Connectivity().onConnectivityChanged.listen(
        (result) {
          _updateStatus(result);
        },
        onError: (error) {
          debugPrint('Connectivity: Stream encountered an error: $error');
          // If we get a specific error like the NetworkManager one on Windows,
          // we might want to stop/restart differently, but for now just log.
        },
        cancelOnError: false,
      );
    } on PlatformException catch (e) {
      debugPrint(
          'Connectivity: PlatformException while establishing stream: ${e.code} - ${e.message}');
      // Specifically handle the Windows NetworkManager error if it occurs here
      if (e.message?.contains('NetworkManager') == true) {
        debugPrint(
            'Connectivity: Windows NetworkManager failed to start. Falling back to manual checks.');
      }
    } catch (e) {
      debugPrint('Connectivity: Unexpected error establishing stream: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _updateStatus(List<ConnectivityResult> result) {
    if (!mounted) return;

    final offlineMode = _ref.read(settingsProvider).offlineMode;

    final newStatus = (result.contains(ConnectivityResult.none) || offlineMode)
        ? ConnectionStatus.offline
        : ConnectionStatus.online;

    // Check if status changed from offline to online
    if (_previousStatus == ConnectionStatus.offline &&
        newStatus == ConnectionStatus.online) {
      debugPrint(
          'Connectivity: Device came back online, triggering auto-sync...');
      _triggerAutoSync();
    }

    _previousStatus = state;
    state = newStatus;
  }

  Future<void> _triggerAutoSync() async {
    try {
      // Get sync service and trigger sync
      final syncService = _ref.read(syncServiceProvider);
      await syncService.syncAll();
      debugPrint('Auto-sync completed successfully');
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
      // Don't throw - auto-sync failures shouldn't crash the app
    }
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityServiceNotifier, ConnectionStatus>((ref) {
  final offlineMode = ref.watch(settingsProvider.select((s) => s.offlineMode));
  return ConnectivityServiceNotifier(ref, initialOffline: offlineMode);
});
