import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/business_partners/data/repositories/business_partner_repository_impl.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/domain/repositories/business_partner_repository.dart';

import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:uuid/uuid.dart';

// State
class BusinessPartnerState {
  const BusinessPartnerState({
    this.customers = const [],
    this.vendors = const [],
    this.employees = const [],
    this.businessTypes = const [],
    this.cities = const [],
    this.states = const [],
    this.countries = const [],
    this.roles = const [],
    this.departments = const [],
    this.appUsers = const [],
    this.appForms = const [],
    this.formPrivileges = const [],
    this.storeAccess = const [],
    this.isLoading = false,
    this.error,
  });

  final List<BusinessPartner> customers;
  final List<BusinessPartner> vendors;
  final List<BusinessPartner> employees;
  final List<Map<String, dynamic>> businessTypes;
  final List<Map<String, dynamic>> cities;
  final List<Map<String, dynamic>> states;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> departments;
  final List<AppUser> appUsers;
  final List<Map<String, dynamic>> appForms;
  final List<Map<String, dynamic>> formPrivileges;
  final List<int> storeAccess;
  final bool isLoading;
  final String? error;

  BusinessPartnerState copyWith({
    List<BusinessPartner>? customers,
    List<BusinessPartner>? vendors,
    List<BusinessPartner>? employees,
    List<Map<String, dynamic>>? businessTypes,
    List<Map<String, dynamic>>? cities,
    List<Map<String, dynamic>>? states,
    List<Map<String, dynamic>>? countries,
    List<Map<String, dynamic>>? roles,
    List<Map<String, dynamic>>? departments,
    List<AppUser>? appUsers,
    List<Map<String, dynamic>>? appForms,
    List<Map<String, dynamic>>? formPrivileges,
    List<int>? storeAccess,
    bool? isLoading,
    String? error,
  }) {
    return BusinessPartnerState(
      customers: customers ?? this.customers,
      vendors: vendors ?? this.vendors,
      employees: employees ?? this.employees,
      businessTypes: businessTypes ?? this.businessTypes,
      cities: cities ?? this.cities,
      states: states ?? this.states,
      countries: countries ?? this.countries,
      roles: roles ?? this.roles,
      departments: departments ?? this.departments,
      appUsers: appUsers ?? this.appUsers,
      appForms: appForms ?? this.appForms,
      formPrivileges: formPrivileges ?? this.formPrivileges,
      storeAccess: storeAccess ?? this.storeAccess,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class BusinessPartnerNotifier extends StateNotifier<BusinessPartnerState> {
  BusinessPartnerNotifier(this.ref, this.repository, this.localRepository,
      {this.storeId})
      : super(const BusinessPartnerState());

  final Ref ref;
  final BusinessPartnerRepository repository;
  final BusinessPartnerLocalRepository localRepository;
  final int? storeId;

  Future<void> loadCustomers() async {
    Future.microtask(() => state = state.copyWith(isLoading: true));

    // Always load local data first as fallback
    List<BusinessPartner> localData = [];
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      localData = await localRepository.getLocalPartners(
          isCustomer: true, storeId: storeId, organizationId: orgId);
    } catch (localE) {
      debugPrint('Local load failed: $localE');
    }

    // Check connectivity first
    final connectivityResult = await ConnectivityHelper.check();
    if (!mounted) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      state = state.copyWith(isLoading: false, customers: localData);
      return;
    }

    // Online: Try server, use if has data, else keep local
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final remoteCustomers = await repository.getPartners(
          isCustomer: true, storeId: storeId, organizationId: orgId);
      final withBalances = await _populateOpeningBalances(remoteCustomers);
      state = state.copyWith(isLoading: false, customers: withBalances);
    } catch (e) {
      debugPrint('Server load failed, using local cache: $e');
      final withBalances = await _populateOpeningBalances(localData);
      state = state.copyWith(isLoading: false, customers: withBalances);
    }
  }

  Future<void> loadVendors() async {
    Future.microtask(() => state = state.copyWith(isLoading: true));

    // Always load local data first as fallback
    List<BusinessPartner> localData = [];
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      localData = await localRepository.getLocalPartners(
          isVendor: true, storeId: storeId, organizationId: orgId);
    } catch (localE) {
      debugPrint('Local load failed: $localE');
    }

    // Check connectivity first
    final connectivityResult = await ConnectivityHelper.check();
    if (!mounted) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      state = state.copyWith(isLoading: false, vendors: localData);
      return;
    }

    // Online: Try server
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final remoteVendors = await repository.getPartners(
          isVendor: true, storeId: storeId, organizationId: orgId);
      final withBalances = await _populateOpeningBalances(remoteVendors);
      state = state.copyWith(isLoading: false, vendors: withBalances);
    } catch (e) {
      debugPrint('Server load failed, using local cache: $e');
      final withBalances = await _populateOpeningBalances(localData);
      state = state.copyWith(isLoading: false, vendors: withBalances);
    }
  }

  Future<void> loadEmployees() async {
    Future.microtask(() => state = state.copyWith(isLoading: true));

    // Always load local data first as fallback
    List<BusinessPartner> localData = [];
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      localData = await localRepository.getLocalPartners(
          isEmployee: true, storeId: storeId, organizationId: orgId);
    } catch (localE) {
      debugPrint('Local load failed: $localE');
    }

    // Check connectivity first
    final connectivityResult = await ConnectivityHelper.check();
    if (!mounted) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      state = state.copyWith(isLoading: false, employees: localData);
      return;
    }

    // Online: Try server
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final remoteEmployees = await repository.getPartners(
          isEmployee: true, storeId: storeId, organizationId: orgId);
      final withBalances = await _populateOpeningBalances(remoteEmployees);
      state = state.copyWith(isLoading: false, employees: withBalances);
    } catch (e) {
      debugPrint('Server load failed, using local cache: $e');
      final withBalances = await _populateOpeningBalances(localData);
      state = state.copyWith(isLoading: false, employees: withBalances);
    }
  }

  Future<List<BusinessPartner>> _populateOpeningBalances(
      List<BusinessPartner> partners) async {
    final sYear = ref.read(organizationProvider).selectedFinancialYear;
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    if (sYear == null || orgId == null) return partners;

    try {
      final repo = ref.read(accountingRepositoryProvider);
      final openingBalances = await repo.getOpeningBalances(
          organizationId: orgId, sYear: sYear);

      return partners.map((p) {
        final bal = openingBalances
            .where(
                (b) => b.entityId == p.id && b.entityType == 'BusinessPartner')
            .firstOrNull;
        if (bal != null) {
          return p.copyWith(openingBalance: bal.amount);
        }
        return p;
      }).toList();
    } catch (e) {
      // debugPrint('Error populating opening balances: $e');
      return partners;
    }
  }

  Future<void> loadAppUsers() async {
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    if (orgId == null) return;

    Future.microtask(() => state = state.copyWith(isLoading: true));
    try {
      final users = await repository.getAppUsers(orgId);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, appUsers: users);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBusinessTypes() async {
    try {
      final types = await repository.getBusinessTypes();
      state = state.copyWith(businessTypes: types);
    } catch (e) {
      debugPrint('Error loading business types: $e');
    }
  }

  Future<void> addBusinessType(String name) async {
    try {
      await repository.addBusinessType(name);
      await loadBusinessTypes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadCities() async {
    try {
      final list = await repository.getCities();
      state = state.copyWith(cities: list);
    } catch (e) {
      debugPrint('Error loading cities: $e');
    }
  }

  Future<void> addCity(String name) async {
    try {
      await repository.addCity(name);
      await loadCities();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadStates() async {
    try {
      final list = await repository.getStates();
      state = state.copyWith(states: list);
    } catch (e) {
      debugPrint('Error loading states: $e');
    }
  }

  Future<void> addState(String name) async {
    try {
      await repository.addState(name);
      await loadStates();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadCountries() async {
    try {
      final list = await repository.getCountries();
      state = state.copyWith(countries: list);
    } catch (e) {
      debugPrint('Error loading countries: $e');
    }
  }

  Future<void> addCountry(String name) async {
    try {
      await repository.addCountry(name);
      await loadCountries();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadRoles({int? organizationId}) async {
    try {
      final orgId =
          organizationId ?? ref.read(organizationProvider).selectedOrganizationId;
      final list = await repository.getRoles(organizationId: orgId);
      if (!mounted) return;
      state = state.copyWith(roles: list);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading roles: $e');
    }
  }

  Future<void> addRole(
    String name,
    int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
    bool isSystem = false,
  }) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.addRole(name, departmentId,
          canRead: canRead,
          canWrite: canWrite,
          canEdit: canEdit,
          canPrint: canPrint,
          storeId: storeId,
          syear: syear,
          isSystem: isSystem,
          organizationId: orgId);
      await loadRoles();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateRole(
    int id,
    String name,
    int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
  }) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.updateRole(id, name, departmentId,
          canRead: canRead,
          canWrite: canWrite,
          canEdit: canEdit,
          canPrint: canPrint,
          storeId: storeId,
          syear: syear);
      await loadRoles(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteRole(int id) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.deleteRole(id);
      await loadRoles(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadDepartments(int organizationId) async {
    try {
      final list = await repository.getDepartments(organizationId);
      state = state.copyWith(departments: list);
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  Future<void> addDepartment(String name, int organizationId) async {
    try {
      await repository.addDepartment(name, organizationId);
      await loadDepartments(organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateDepartment(int id, String name, int organizationId) async {
    try {
      await repository.updateDepartment(id, name);
      await loadDepartments(organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteDepartment(int id, int organizationId) async {
    try {
      await repository.deleteDepartment(id);
      await loadDepartments(organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addPartner(BusinessPartner partner) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final storeId = ref.read(organizationProvider).selectedStoreId;
      final partnerWithOrg = partner.copyWith(
        organizationId: partner.organizationId ?? orgId,
        storeId: partner.storeId ?? storeId,
      );
      await repository.createPartner(partnerWithOrg);
      
      if (partner.openingBalance != 0) {
        await _saveOpeningBalance(partner.id, partner.openingBalance);
      }

      _refreshLists(partnerWithOrg);
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        debugPrint('Network error adding partner, saving locally: $e');
        try {
          await localRepository.addPartner(partner);
          if (partner.openingBalance != 0) {
            await _saveOpeningBalance(partner.id, partner.openingBalance);
          }
          _refreshLists(partner);
          ref.read(dashboardProvider.notifier).refresh();
          // TODO: Queue for sync
          return;
        } catch (localE) {
          state = state.copyWith(error: 'Offline save failed: $localE');
          rethrow;
        }
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addPartners(List<BusinessPartner> partners,
      {bool refresh = true}) async {
    if (partners.isEmpty) return;
    try {
      await repository.createPartners(partners);

      if (refresh) {
        if (partners.first.isCustomer) await loadCustomers();
        if (partners.first.isVendor) await loadVendors();
        if (partners.first.isEmployee) await loadEmployees();
        ref.read(dashboardProvider.notifier).refresh();
      }
    } catch (e) {
      // Bulk offline add not strictly requested, but good to have safety
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePartner(BusinessPartner partner) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final storeId = ref.read(organizationProvider).selectedStoreId;
      final partnerWithOrg = partner.copyWith(
        organizationId: partner.organizationId ?? orgId,
        storeId: partner.storeId ?? storeId,
      );
      await repository.updatePartner(partnerWithOrg);

      if (partner.openingBalance != 0) {
        await _saveOpeningBalance(partner.id, partner.openingBalance);
      }

      _refreshLists(partnerWithOrg);
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        debugPrint('Network error updating partner, saving locally: $e');
        try {
          await localRepository.updatePartner(partner);
          if (partner.openingBalance != 0) {
            await _saveOpeningBalance(partner.id, partner.openingBalance);
          }
          _refreshLists(partner);
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          state = state.copyWith(error: 'Offline update failed: $localE');
          rethrow;
        }
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deletePartner(String id,
      {bool isCustomer = false,
      bool isVendor = false,
      bool isEmployee = false}) async {
    // Optimistic Update: Remove from UI immediately
    final previousState = state;
    if (isCustomer) {
      state = state.copyWith(
        customers: state.customers.where((p) => p.id != id).toList(),
      );
    }
    if (isVendor) {
      state = state.copyWith(
        vendors: state.vendors.where((p) => p.id != id).toList(),
      );
    }
    if (isEmployee) {
      state = state.copyWith(
        employees: state.employees.where((p) => p.id != id).toList(),
      );
    }

    try {
      await repository.deletePartner(id);
      // Repository handles offline fallback internaly now.
      // If we are here, it's deleted (synced or locally).

      // We can trigger a refresh to be safe, but we already updated UI.
      // _refreshLists() might be overkill if we trust the optimistic delete.
      // But let's do it in background to sync up any other changes.
      _refreshLists(BusinessPartner(
          id: id,
          name: '',
          phone: '',
          address: '',
          isCustomer: isCustomer,
          isVendor: isVendor,
          isEmployee: isEmployee,
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          organizationId: 0,
          storeId: 0));
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      // Revert if completely failed
      state = previousState.copyWith(error: 'Delete failed: $e');
      rethrow;
    }
  }

  Future<void> _refreshLists(BusinessPartner partner) async {
    if (partner.isCustomer) await loadCustomers();
    if (partner.isVendor) await loadVendors();
    if (partner.isEmployee) await loadEmployees();
  }

  Future<void> loadAppForms() async {
    try {
      final forms = await repository.getAppForms();
      state = state.copyWith(appForms: forms);
    } catch (e) {
      debugPrint('Error loading app forms: $e');
    }
  }

  Future<void> loadFormPrivileges({int? roleId, String? employeeId}) async {
    Future.microtask(() => state = state.copyWith(isLoading: true));
    try {
      final privileges = await repository.getFormPrivileges(
          roleId: roleId, employeeId: employeeId);

      // Sort: Employee-specific rows first, then role-based rows
      privileges.sort((a, b) {
        if (a['employee_id'] != null && b['employee_id'] == null) return -1;
        if (a['employee_id'] == null && b['employee_id'] != null) return 1;
        return 0;
      });

      state = state.copyWith(formPrivileges: privileges, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveFormPrivileges(List<Map<String, dynamic>> privileges) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.saveBatchFormPrivileges(privileges);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> createAppUser({
    required String partnerId,
    required String email,
    required int roleId,
    required int organizationId,
    required int storeId,
    String? password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.createAppUser(
        partnerId: partnerId,
        email: email,
        roleId: roleId,
        organizationId: organizationId,
        storeId: storeId,
        password: password,
      );
      await loadAppUsers();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> importAppUsersFromEmployees(
      List<BusinessPartner> employees) async {
    if (employees.isEmpty) return;
    state = state.copyWith(isLoading: true);

    int successCount = 0;
    List<String> errors = [];

    for (final emp in employees) {
      try {
        await repository.createAppUser(
          partnerId: emp.id,
          email: emp.email ?? '',
          fullName: emp.name,
          roleId: emp.roleId ?? 0,
          organizationId: emp.organizationId,
          storeId: emp.storeId,
          password: emp.password,
        );
        successCount++;
      } catch (e) {
        errors.add('Failed to import ${emp.name}: $e');
      }
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(isLoading: false, error: errors.join('\n'));
    } else {
      state = state.copyWith(isLoading: false);
    }
    await loadAppUsers();
  }

  Future<void> loadStoreAccess({int? roleId, String? employeeId}) async {
    state = state.copyWith(isLoading: true);
    try {
      List<int> access = [];
      if (roleId != null) {
        access = await repository.getRoleStoreAccess(roleId);
      } else if (employeeId != null) {
        access = await repository.getUserStoreAccess(employeeId);
      }
      if (!mounted) return;
      state = state.copyWith(storeAccess: access, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveStoreAccess(
      {int? roleId, String? employeeId, required List<int> storeIds}) async {
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    if (orgId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      if (roleId != null) {
        await repository.saveRoleStoreAccess(roleId, storeIds, orgId);
      } else if (employeeId != null) {
        await repository.saveUserStoreAccess(employeeId, storeIds, orgId);
      }
      if (!mounted) return;
      state = state.copyWith(storeAccess: storeIds, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> sendCredentials(
      BusinessPartner employee, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.sendEmployeeCredentials(employee, password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> _saveOpeningBalance(String entityId, double amount) async {
    final sYear = ref.read(organizationProvider).selectedFinancialYear;
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    if (sYear == null || orgId == null) return;

    final repo = ref.read(accountingRepositoryProvider);

    try {
      final existingBalances = await repo.getOpeningBalances(
          organizationId: orgId, sYear: sYear);

      final existing = existingBalances
          .where((b) =>
              b.entityId == entityId && b.entityType == 'BusinessPartner')
          .firstOrNull;

      final balance = OpeningBalance(
        id: existing?.id ?? const Uuid().v4(),
        sYear: sYear,
        amount: amount,
        entityId: entityId,
        entityType: 'BusinessPartner',
        organizationId: orgId,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveOpeningBalance(balance);
    } catch (e) {
      debugPrint('Error saving opening balance for partner: $e');
    }
  }
}

// Providers
final businessPartnerRepositoryProvider =
    Provider<BusinessPartnerRepository>((ref) {
  return BusinessPartnerRepositoryImpl();
});

final businessPartnerLocalRepositoryProvider =
    Provider<BusinessPartnerLocalRepository>((ref) {
  return BusinessPartnerLocalRepository();
});

final businessPartnerProvider =
    StateNotifierProvider<BusinessPartnerNotifier, BusinessPartnerState>((ref) {
  final repository = ref.watch(businessPartnerRepositoryProvider);
  final localRepository = ref.watch(businessPartnerLocalRepositoryProvider);

  // Watch organization to trigger refresh and get storeId
  final storeId =
      ref.watch(organizationProvider.select((s) => s.selectedStore?.id));

  final notifier = BusinessPartnerNotifier(ref, repository, localRepository,
      storeId: storeId);

  // Trigger initial load if needed, or rely on UI to call loadCustomers etc.
  // Since switching store invalidates old data, we *should* reload if we want fresh state.
  // But unlike ProductNotifier which has single list, BusinessPartner has 3 lists.
  // We can let UI trigger load, BUT current state will be from previous store if we don't clear it.
  // But wait, creating a NEW Notifier instance resets state to initial empty state.
  // So simply creating it is enough to "clear" old data.
  // The UI will likely see empty list and trigger load in initState/build.
  // However, if the UI only triggers load in initState, rebuilding provider won't re-trigger initState unless widget tree rebuilds significantly.
  // It is safer to trigger loads here if we know what to load, OR rely on the fact that provider rebuild forces consumers to re-subscribe.
  // For now, let's just return notifier.

  return notifier;
});
