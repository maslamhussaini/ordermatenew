import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/vendors/data/repositories/vendor_repository_impl.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/domain/repositories/vendor_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';

// State
class VendorState {
  const VendorState({
    this.vendors = const [],
    this.suppliers = const [],
    this.isLoading = false,
    this.error,
  });
  final List<Vendor> vendors;
  final List<Vendor> suppliers;
  final bool isLoading;
  final String? error;

  VendorState copyWith({
    List<Vendor>? vendors,
    List<Vendor>? suppliers,
    bool? isLoading,
    String? error,
  }) {
    return VendorState(
      vendors: vendors ?? this.vendors,
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class VendorNotifier extends StateNotifier<VendorState> {
  VendorNotifier(this.ref, this.repository) : super(const VendorState());
  final Ref ref;
  final VendorRepository repository;

  Future<void> loadVendors() async {
    state = state.copyWith(isLoading: true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final vendors = await repository.getVendors(organizationId: orgId);
      state = state.copyWith(isLoading: false, vendors: vendors);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadSuppliers() async {
    state = state.copyWith(isLoading: true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final suppliers = await repository.getSuppliers(organizationId: orgId);
      state = state.copyWith(isLoading: false, suppliers: suppliers);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    try {
      final vendors = await repository.getVendors(organizationId: orgId);
      final suppliers = await repository.getSuppliers(organizationId: orgId);
      state = state.copyWith(
          isLoading: false, vendors: vendors, suppliers: suppliers);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addVendor(Vendor vendor) async {
    try {
      await repository.createVendor(vendor);
      await loadVendors();
      await loadSuppliers();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateVendor(Vendor vendor) async {
    try {
      await repository.updateVendor(vendor);
      await loadVendors();
      await loadSuppliers();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteVendor(String id) async {
    final previousState = state;
    // Optimistic Update
    state = state.copyWith(
      vendors: state.vendors.where((v) => v.id != id).toList(),
      suppliers: state.suppliers.where((s) => s.id != id).toList(),
    );

    try {
      await repository.deleteVendor(id);
      // Backend (Repository) handles offline fallback.
      // We assume success or handled offline.
      // We can reload to be safe, but optimistic is enough for UI response.
      // await loadVendors();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      // Revert
      state = previousState.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Providers
final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  return VendorRepositoryImpl();
});

final vendorProvider =
    StateNotifierProvider<VendorNotifier, VendorState>((ref) {
  final repository = ref.watch(vendorRepositoryProvider);
  return VendorNotifier(ref, repository);
});
