// lib/features/customers/presentation/providers/customer_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:ordermate/features/customers/domain/entities/customer.dart';
import 'package:ordermate/features/customers/domain/usecases/get_customers_by_location_usecase.dart';
import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';

// Filter Modes
enum CustomerFilterMode { myCustomers, nearby }

// State for customer list
class CustomerState {
  CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.userLocation,
    this.filterMode = CustomerFilterMode.myCustomers,
  });
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final Position? userLocation;
  final CustomerFilterMode filterMode;

  CustomerState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    Position? userLocation,
    CustomerFilterMode? filterMode,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userLocation: userLocation ?? this.userLocation,
      filterMode: filterMode ?? this.filterMode,
    );
  }
}

// Dependecy Injection
final customerRepositoryProvider = Provider<CustomerRepositoryImpl>((ref) {
  return CustomerRepositoryImpl();
});

final getCustomersByLocationUseCaseProvider =
    Provider<GetCustomersByLocationUseCase>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return GetCustomersByLocationUseCase(repository);
});

// StateNotifier for customer management
class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier(this.ref, this.getCustomersByLocation, this.repository)
      : super(CustomerState());
  final Ref ref;
  final GetCustomersByLocationUseCase getCustomersByLocation;
  final CustomerRepositoryImpl repository;

  Future<void> setFilterMode(CustomerFilterMode mode) async {
    state = state.copyWith(filterMode: mode);
    await refreshCustomers();
  }

  Future<void> createCustomer(Customer customer) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.createCustomer(customer);
      await refreshCustomers();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.updateCustomer(customer);
      await refreshCustomers();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> loadCustomersByUser() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Resolve omtbl_users.id from Auth Email
      String? validUserId;
      final currentUserEmail = SupabaseConfig.currentUser?.email;
      if (currentUserEmail != null) {
        final userModel = await SupabaseConfig.client
            .from('omtbl_users')
            .select('id')
            .eq('email', currentUserEmail)
            .maybeSingle();
        if (userModel != null) {
          final data = userModel;
          validUserId = data['id'] as String;
        }
      }

      if (validUserId == null) {
        // Fallback or Error? fallback to location
        await loadCustomersByLocation();
        return;
      }

      // 2. Fetch Customers
      final customers = await repository.getCustomersByUser(validUserId);

      // 3. Get User Location and Calculate Distances
      Position? position;
      var processedCustomers = customers;

      try {
        position = await LocationHelper.getCurrentPosition();

        processedCustomers = customers.map((c) {
          final dist = LocationHelper.calculateDistance(
            position!.latitude,
            position.longitude,
            c.latitude,
            c.longitude,
          );
          return c.copyWith(distanceMeters: dist);
        }).toList();
      } catch (_) {}

      state = state.copyWith(
        customers: processedCustomers,
        isLoading: false,
        userLocation: position,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCustomersByLocation({double radiusKm = 50.0}) async {
    // Increased default
    state = state.copyWith(isLoading: true);

    try {
      // Get current location
      final position = await LocationHelper.getCurrentPosition();

      // Fetch customers within radius
      final customers = await getCustomersByLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: (radiusKm * 1000).toInt(),
      );

      state = state.copyWith(
        customers: customers,
        isLoading: false,
        userLocation: position,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await repository.deleteCustomer(id);
      state = state.copyWith(
        customers: state.customers.where((c) => c.id != id).toList(),
      );
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refreshCustomers() async {
    if (state.filterMode == CustomerFilterMode.myCustomers) {
      await loadCustomersByUser();
    } else {
      await loadCustomersByLocation();
    }
  }
}

// Provider definition
final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>(
  (ref) {
    final customerRepository = ref.watch(customerRepositoryProvider);
    final getCustomersByLocation =
        ref.watch(getCustomersByLocationUseCaseProvider);
    return CustomerNotifier(ref, getCustomersByLocation, customerRepository);
  },
);
