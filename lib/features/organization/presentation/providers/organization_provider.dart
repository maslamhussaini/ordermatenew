import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State
class OrganizationState {
  // State
  const OrganizationState({
    this.isLoading = false,
    this.organizations = const [],
    this.selectedOrganization,
    this.selectedStore,
    this.selectedFinancialYear,
    this.stores = const [],
    this.isInitialized = false,
    this.error,
  });

  final bool isLoading;
  final bool isInitialized;
  final List<Organization> organizations;
  final Organization? selectedOrganization;
  final Store? selectedStore;
  final int? selectedFinancialYear;
  final List<Store> stores;
  final String? error;

  int? get selectedOrganizationId => selectedOrganization?.id;
  int? get selectedStoreId => selectedStore?.id;

  OrganizationState copyWith({
    bool? isLoading,
    List<Organization>? organizations,
    Organization? selectedOrganization,
    Store? selectedStore,
    // `selectedStore: null` is a legitimate, meaningful value here (e.g.
    // "multiple stores, nothing unambiguous to auto-select — show the
    // dropdown"), not "no change was requested". Plain `selectedStore ??
    // this.selectedStore` can't tell those apart, so passing null silently
    // kept whatever was selected before — including a store belonging to a
    // *different* organization after switching. This flag makes the clear
    // explicit.
    bool clearSelectedStore = false,
    int? selectedFinancialYear,
    List<Store>? stores,
    bool? isInitialized,
    String? error,
  }) {
    return OrganizationState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      organizations: organizations ?? this.organizations,
      selectedOrganization: selectedOrganization ?? this.selectedOrganization,
      selectedStore: clearSelectedStore
          ? null
          : (selectedStore ?? this.selectedStore),
      selectedFinancialYear:
          selectedFinancialYear ?? this.selectedFinancialYear,
      stores: stores ?? this.stores,
      error: error,
    );
  }
}

// Notifier
class OrganizationNotifier extends StateNotifier<OrganizationState> {
  final OrganizationRepository _repository;
  final Ref ref;

  OrganizationNotifier(this._repository, this.ref)
      : super(const OrganizationState()) {
    _init();

    // Listen for auth events to manage state
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isLoggedIn == true && !next.isLoggedIn) {
        reset();
      } else if ((previous == null || !previous.isLoggedIn) &&
          next.isLoggedIn) {
        _init();
      }
    });
  }

  Future<void> _init() async {
    try {
      debugPrint('OrganizationNotifier: _init started');
      await loadOrganizations();
      await _loadPersistedSelection();
    } catch (e) {
      debugPrint('OrganizationNotifier: _init error: $e');
    } finally {
      debugPrint('OrganizationNotifier: _init completed, setting isInitialized=true');
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> _loadPersistedSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getInt('selected_organization_id');
      final storeId = prefs.getInt('selected_store_id');
      final year = prefs.getInt('selected_financial_year');

      debugPrint('ORG PERSISTED = $orgId');
      debugPrint('STORE PERSISTED = $storeId');
      debugPrint('YEAR PERSISTED = $year');

      if (orgId != null && state.organizations.isNotEmpty) {
        final org = state.organizations.where((o) => o.id == orgId).firstOrNull;
        if (org != null) {
          state = state.copyWith(selectedOrganization: org);
          await loadStores(orgId);

          if (storeId != null) {
            final store =
                state.stores.where((s) => s.id == storeId).firstOrNull;
            if (store != null) {
              state = state.copyWith(selectedStore: store);
            }
          }

          if (year != null) {
            state = state.copyWith(selectedFinancialYear: year);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading persisted selection: $e');
    }
  }

  Future<void> _persistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.selectedOrganization != null) {
        await prefs.setInt(
            'selected_organization_id', state.selectedOrganization!.id);
      } else {
        await prefs.remove('selected_organization_id');
      }

      if (state.selectedStore != null) {
        await prefs.setInt('selected_store_id', state.selectedStore!.id);
      } else {
        await prefs.remove('selected_store_id');
      }

      if (state.selectedFinancialYear != null) {
        await prefs.setInt(
            'selected_financial_year', state.selectedFinancialYear!);
      } else {
        await prefs.remove('selected_financial_year');
      }
    } catch (e) {
      debugPrint('Error persisting selection: $e');
    }
  }

  Future<void> loadOrganizations() async {
    state = state.copyWith(isLoading: true);
    try {
      final orgs = await _repository.getOrganizations();

      // Only clear/auto-select if we have a non-empty results list
      var selected = state.selectedOrganization;
      if (orgs.isNotEmpty) {
        if (selected != null && !orgs.any((o) => o.id == selected!.id)) {
          selected = null;
        }

        if (selected == null) {
          if (orgs.length == 1) {
            selected = orgs.first;
          }
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        organizations: orgs,
        selectedOrganization: selected,
      );

      if (selected != null) {
        await loadStores(selected.id);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteOrganization(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteOrganization(id);
      await loadOrganizations();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> selectOrganization(Organization org) async {
    state = state.copyWith(selectedOrganization: org);
    await loadStores(org.id);
    await _persistSelection();
  }

  Future<void> selectStore(Store? store) async {
    state = state.copyWith(selectedStore: store, clearSelectedStore: store == null);
    await _persistSelection();
  }

  Future<void> setWorkspace({
    required Organization organization,
    Store? store,
    int? financialYear,
  }) async {
    debugPrint('OrganizationProvider: Setting workspace - Org: ${organization.id}, Store: ${store?.id}, Year: $financialYear');
    
    state = state.copyWith(
      selectedOrganization: organization,
      selectedStore: store,
      clearSelectedStore: store == null,
      selectedFinancialYear: financialYear,
    );

    // Ensure stores are loaded for the new organization in the background
    final loadStoresFuture = loadStores(organization.id);
    
    // If store was provided, we don't need to wait for loadStores to complete before proceeding
    // but we still want to ensure it completes and doesn't overwrite our selection
    if (store != null) {
      loadStoresFuture.then((_) {
        // Re-enforce selection after background load in case loadStores auto-selected something else
        if (state.selectedOrganization?.id == organization.id) {
           state = state.copyWith(selectedStore: store);
        }
      });
    } else {
      await loadStoresFuture;
    }
    
    await _persistSelection();
    debugPrint('OrganizationProvider: Workspace set and persisted.');
  }

  void clearSelection() {
    state = const OrganizationState();
  }

  void reset() {
    state = const OrganizationState();
    // Clear persisted selection on logout
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('selected_organization_id');
      prefs.remove('selected_store_id');
      prefs.remove('selected_financial_year');
    });
  }

  void selectFinancialYear(int? year) {
    state = state.copyWith(selectedFinancialYear: year);
    _persistSelection();
  }

  Future<Organization> createOrganization(
      String name, String? taxId, bool hasMultipleBranches,
      {Uint8List? logoBytes, String? logoName, int? businessTypeId}) async {
    state = state.copyWith(isLoading: true);
    try {
      String? logoUrl;
      if (logoBytes != null && logoName != null) {
        logoUrl = await _repository.uploadOrganizationLogo(logoBytes, logoName);
      }

      final newOrg = await _repository.createOrganization(
        name,
        taxId,
        hasMultipleBranches,
        logoUrl,
        businessTypeId: businessTypeId,
      );

      // Trigger Accounting Setup in background
      _setupAccounting(newOrg.id);

      // Reload to refresh list and select new org
      await loadOrganizations();
      await selectOrganization(newOrg); // Ensure we select the new one
      if (!mounted) return newOrg;
      return newOrg;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> updateOrganization(Organization org,
      {Uint8List? newLogoBytes, String? newLogoName}) async {
    state = state.copyWith(isLoading: true);
    try {
      var orgToUpdate = org;
      if (newLogoBytes != null && newLogoName != null) {
        final logoUrl =
            await _repository.uploadOrganizationLogo(newLogoBytes, newLogoName);
        orgToUpdate = Organization(
          id: org.id,
          name: org.name,
          code: org.code,
          isActive: org.isActive,
          createdAt: org.createdAt,
          updatedAt: DateTime.now(),
          logoUrl: logoUrl,
          storeCount: org.storeCount,
          isGL: org.isGL,
          isSales: org.isSales,
          isInventory: org.isInventory,
          isHR: org.isHR,
          isSettings: org.isSettings,
          entitlementMode: org.entitlementMode,
          businessTypeId: org.businessTypeId,
          planType: org.planType,
        );
      }

      await _repository.updateOrganization(orgToUpdate);
      await loadOrganizations(); // Refresh list
      if (!mounted) return;
      state = state.copyWith(selectedOrganization: orgToUpdate);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // Stores
  Future<void> loadStores(int orgId) async {
    try {
      final allStores = await _repository.getStores(orgId);

      // Filter stores based on user access (store-wise internal user access).
      final userProfile = await ref.read(userProfileProvider.future);
      List<Store> allowedStores = allStores;

      if (userProfile != null) {
        // Owner/Admin roles see every store in the org, per the existing
        // role/privilege design. Everyone else is restricted to whatever
        // the existing store-access architecture explicitly grants them.
        final role = userProfile.role.toUpperCase();
        final hasFullStoreAccess = role == 'CORPORATE_ADMIN' ||
            role == 'ADMIN' ||
            role == 'SUPER USER' ||
            role == 'OWNER';

        if (!hasFullStoreAccess) {
          final allowedIds = await _resolveAllowedStoreIds(
            employeeId: userProfile.id,
            roleId: userProfile.roleId,
            singleStoreId: userProfile.storeId,
          );
          allowedStores =
              allStores.where((s) => allowedIds.contains(s.id)).toList();
        }
      }

      final selected = Store.resolveDefault(
        allowedStores,
        previouslySelectedId: state.selectedStore?.id,
      );

      if (!mounted) return;
      state = state.copyWith(
        stores: allowedStores,
        selectedStore: selected,
        clearSelectedStore: selected == null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  /// Resolves the set of store ids a non-admin user is explicitly granted,
  /// using the store-access tables the Employees/Privileges screens already
  /// manage (see PrivilegeManagementScreen + BusinessPartnerRepositoryImpl's
  /// get/saveRoleStoreAccess and get/saveUserStoreAccess) rather than
  /// inventing a new access model:
  ///
  ///  - `omtbl_user_store_access` — stores explicitly assigned to this
  ///    employee.
  ///  - `omtbl_role_store_access` — stores assigned to this employee's role.
  ///  - `omtbl_users.store_id` — the single "primary" store already carried
  ///    on the user row (used e.g. by team_setup_screen.dart onboarding).
  ///
  /// The result is the union of whichever of these are configured. An empty
  /// result means "not granted any store" and must NOT fall back to showing
  /// every store — including on a read failure: each source fails closed
  /// (contributes nothing) rather than the whole method throwing and
  /// (accidentally) leaving the caller to show every store.
  Future<Set<int>> _resolveAllowedStoreIds({
    required String? employeeId,
    required int? roleId,
    required int? singleStoreId,
  }) async {
    final ids = <int>{};

    if (singleStoreId != null) ids.add(singleStoreId);

    if (employeeId != null) {
      try {
        final rows = await SupabaseConfig.client
            .from('omtbl_user_store_access')
            .select('store_id')
            .eq('employee_id', employeeId);
        for (final row in (rows as List)) {
          final storeId = row['store_id'];
          if (storeId is int) ids.add(storeId);
        }
      } catch (e) {
        debugPrint('OrganizationNotifier: failed to load user store access: $e');
      }
    }

    if (roleId != null) {
      try {
        final rows = await SupabaseConfig.client
            .from('omtbl_role_store_access')
            .select('store_id')
            .eq('role_id', roleId);
        for (final row in (rows as List)) {
          final storeId = row['store_id'];
          if (storeId is int) ids.add(storeId);
        }
      } catch (e) {
        debugPrint('OrganizationNotifier: failed to load role store access: $e');
      }
    }

    return ids;
  }

  Future<void> addStore(Store params) async {
    try {
      final newStore = await _repository.createStore(params);
      await loadStores(params.organizationId);
      await selectStore(newStore);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStore(Store params) async {
    try {
      await _repository.updateStore(params);
      await loadStores(params.organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteStore(int storeId, int orgId) async {
    try {
      await _repository.deleteStore(storeId);
      await loadStores(orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> _setupAccounting(int orgId) async {
    try {
      await ref
          .read(accountingSetupServiceProvider)
          .setupDefaultAccounting(orgId);
    } catch (e) {
      debugPrint('Accounting setup error: $e');
    }
  }
}

// Providers
final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepositoryImpl();
});

final organizationProvider =
    StateNotifierProvider<OrganizationNotifier, OrganizationState>((ref) {
  final repository = ref.watch(organizationRepositoryProvider);
  return OrganizationNotifier(repository, ref);
});
