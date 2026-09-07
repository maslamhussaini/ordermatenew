import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/location_tracking/data/repositories/location_repository_impl.dart';
import 'package:ordermate/features/location_tracking/domain/entities/location_history.dart';
import 'package:ordermate/features/location_tracking/domain/repositories/location_repository.dart';
import 'package:uuid/uuid.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return SupabaseLocationRepository();
});

class LocationTrackingState {
  final List<LocationHistory> history;
  final bool isLoading;
  final String? error;
  final bool isTracking;

  LocationTrackingState({
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.isTracking = false,
  });

  LocationTrackingState copyWith({
    List<LocationHistory>? history,
    bool? isLoading,
    String? error,
    bool? isTracking,
  }) {
    return LocationTrackingState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

class LocationTrackingNotifier extends StateNotifier<LocationTrackingState> {
  final LocationRepository _repository;
  final Ref _ref;
  Timer? _trackingTimer;

  LocationTrackingNotifier(this._repository, this._ref)
      : super(LocationTrackingState());

  void startTracking() {
    if (state.isTracking) return;

    state = state.copyWith(isTracking: true);

    // Initial capture
    _captureLocation();

    // Periodic capture every 5 minutes
    _trackingTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _captureLocation());
    debugPrint('Location tracking started (every 5 mins)');
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    state = state.copyWith(isTracking: false);
    debugPrint('Location tracking stopped');
  }

  Future<void> _captureLocation() async {
    try {
      final user = await _ref.read(userProfileProvider.future);
      if (user == null) {
        debugPrint('Skip location capture: User profile not loaded');
        return;
      }
      if (user.businessPartnerId == null) {
        debugPrint(
            'Skip location capture: User ${user.email} not linked to a Business Partner (Employee) record');
        return;
      }
      if (user.organizationId == null) {
        debugPrint(
            'Skip location capture: No active organization context for user');
        return;
      }

      final position = await LocationHelper.getCurrentPosition();

      final history = LocationHistory(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        organizationId: user.organizationId,
        storeId: user.storeId,
        userId: user.businessPartnerId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      await _repository.saveLocation(history);
      debugPrint(
          'Location captured and saved: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Location capture failed: $e');
    }
  }

  Future<void> loadHistory(
      {DateTime? start, DateTime? end, String? userId}) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _ref.read(userProfileProvider.future);
      final list = await _repository.getHistory(
        startDate: start,
        endDate: end,
        userId: userId,
        organizationId: user?.organizationId,
      );
      state = state.copyWith(history: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }
}

final locationTrackingProvider =
    StateNotifierProvider<LocationTrackingNotifier, LocationTrackingState>(
        (ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return LocationTrackingNotifier(repo, ref);
});
