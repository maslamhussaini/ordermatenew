import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/entities/permission_object.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/services/auth_service.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthState {
  final String userId;
  final String userFullName;
  final bool isLoggedIn;
  final bool isPasswordRecovery;
  final bool isPermissionLoading;
  final UserRole role;
  final List<PermissionObject> permissions;

  final int? organizationId;

  // BusinessPartner id (omtbl_businesspartners.id) of the logged-in user,
  // resolved via omtbl_users.business_partner_id. Distinct from the Supabase
  // Auth UID (userId) and from omtbl_users.id. Null for the org owner/admin
  // and any user without a linked BusinessPartner row -- this is expected,
  // not an error. Used for Customer -> Salesman assignment ("My Customers").
  final String? businessPartnerId;

  // True only once `userId` has been corrected from the Supabase Auth UID
  // (set immediately on sign-in, see the auth-state-change listener below)
  // to the canonical application identity, omtbl_users.id (set once
  // loadDynamicPermissions() resolves the user's profile). Application
  // create/save flows that write `created_by` (an omtbl_users.id foreign
  // key) MUST check this before using `userId` -- checking `userId.isNotEmpty`
  // alone is NOT sufficient, because during the window between sign-in and
  // profile resolution `userId` already holds a non-empty value: the Auth
  // UID. Resets to false on sign-out (via `_clearAuthState`'s `const
  // AuthState()`) and stays true for the rest of the session once set,
  // since nothing after profile resolution reverts `userId` to the Auth UID.
  final bool applicationIdentityResolved;

  const AuthState({
    this.userId = '',
    this.userFullName = '',
    this.isLoggedIn = false,
    this.isPasswordRecovery = false,
    this.isPermissionLoading = false,
    this.role = UserRole.staff,
    this.permissions = const [],
    this.organizationId,
    this.businessPartnerId,
    this.applicationIdentityResolved = false,
  });

  bool can(String module, Permission action) {
    if (role == UserRole.superUser) return true;

    // While loading, we can't confirm permission, so deny by default
    // or return true if it's a "loading" state the UI handles.
    if (isPermissionLoading) return false;

    return permissions.any(
      (p) => p.module == module && p.action == action,
    );
  }

  AuthState copyWith({
    String? userId,
    String? userFullName,
    bool? isLoggedIn,
    bool? isPasswordRecovery,
    bool? isPermissionLoading,
    UserRole? role,
    List<PermissionObject>? permissions,
    int? organizationId,
    String? businessPartnerId,
    bool? applicationIdentityResolved,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      userFullName: userFullName ?? this.userFullName,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
      isPermissionLoading: isPermissionLoading ?? this.isPermissionLoading,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      organizationId: organizationId ?? this.organizationId,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      applicationIdentityResolved:
          applicationIdentityResolved ?? this.applicationIdentityResolved,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  AuthState build() {
    final initialState = AuthState(
      isLoggedIn: AuthService.isLoggedIn,
      role: AuthService.role,
      permissions: _getPermissionsForRole(AuthService.role),
    );

    // Listen to Supabase Auth Changes
    _setupAuthListener();

    // Attempt to load dynamic permissions if logged in
    if (initialState.isLoggedIn) {
      Future.microtask(() => loadDynamicPermissions());
    }

    // Cleanup on dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return initialState;
  }

  void _setupAuthListener() {
    _authSubscription?.cancel(); // Cancel any existing

    // Subscribe to the Supabase Auth State Stream
    _authSubscription =
        SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('AuthNotifier: Event $event');

      if (event == supabase.AuthChangeEvent.passwordRecovery) {
        state = state.copyWith(
          isLoggedIn: true,
          isPasswordRecovery: true,
        );
      } else if (event == supabase.AuthChangeEvent.signedIn ||
          event == supabase.AuthChangeEvent.tokenRefreshed) {
        // Only trigger load if session is present and state is not logged in or email changed
        if (session != null) {
          final fullName = session.user.userMetadata?['full_name'] ?? '';
          if (!state.isLoggedIn || state.userId != session.user.id) {
            state = state.copyWith(
              isLoggedIn: true,
              userId: session.user.id,
              userFullName: fullName,
              isPasswordRecovery: false,
              isPermissionLoading: true,
            );
            loadDynamicPermissions();
          }
        }
      } else if (event == supabase.AuthChangeEvent.signedOut) {
        _clearAuthState();
      }
    });
  }

  void _clearAuthState() {
    state = const AuthState();
    AuthService.testRole = null;
    AuthService.setPermissions = null;
  }

  // Fetch Permissions from the RolePermissions Configuration (Static Defaults)
  List<PermissionObject> _getPermissionsForRole(UserRole role) {
    if (RolePermissions.admin.isEmpty) return []; // Guard

    final Map<String, Set<Permission>> permissionMap =
        (role == UserRole.superUser || role == UserRole.admin)
            ? RolePermissions.admin
            : RolePermissions.staff;

    List<PermissionObject> objects = [];
    permissionMap.forEach((module, actions) {
      for (final action in actions) {
        objects.add(PermissionObject(module, action));
      }
    });

    return objects;
  }

  /// Loads permissions from omtbl_role_form_privileges for the current user
  Future<void> loadDynamicPermissions() async {
    final sessionUser = SupabaseConfig.client.auth.currentUser;
    if (sessionUser == null) {
      state = state.copyWith(isPermissionLoading: false);
      return;
    }

    // Set loading if not already set
    if (!state.isPermissionLoading) {
      state = state.copyWith(isPermissionLoading: true);
    }

    try {
      // 1. Get User Profile - Try by Auth ID first
      var userResponse = await SupabaseConfig.client
          .from('omtbl_users')
          .select(
              'id, auth_id, role_id, role, full_name, organization_id, business_partner_id')
          .eq('auth_id', sessionUser.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      // Fallback: Try by Email
      if (userResponse == null && sessionUser.email != null) {
        userResponse = await SupabaseConfig.client
            .from('omtbl_users')
            .select(
              'id, auth_id, role_id, role, full_name, organization_id, business_partner_id')
            .eq('email', sessionUser.email!)
            .maybeSingle()
            .timeout(const Duration(seconds: 15));
      }

      if (userResponse == null) {
        debugPrint(
            'AuthNotifier: No user profile found in omtbl_users for ${sessionUser.email}');
        state = state.copyWith(isPermissionLoading: false);
        return;
      }

      // Check for Organization Ownership if assigned ID is null
      if (userResponse['organization_id'] == null) {
        try {
          final ownedOrg = await SupabaseConfig.client
              .from('omtbl_organizations')
              .select('id')
              .eq('auth_user_id', sessionUser.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 15));
              
          if (ownedOrg != null) {
            userResponse['organization_id'] = ownedOrg['id'];
            debugPrint('AuthNotifier: Found owned organization ${ownedOrg['id']} for user');
            
            // Self-heal: Update user profile with Organization ID
             var updateData = {'organization_id': ownedOrg['id']};

            // ALSO: If I am the owner, ensure I have the OWNER role and Admin Role ID
            // This fixes the issue where the first user (Owner) is stuck as 'Employee'
             if (userResponse['role'] != 'OWNER' && userResponse['role'] != 'admin') {
                userResponse['role'] = 'OWNER';
                updateData['role'] = 'OWNER';

                // Fetch Admin Role ID to keep DB consistent
                try {
                  final adminRoleRes = await SupabaseConfig.client
                      .from('omtbl_roles')
                      .select('id')
                      .eq('organization_id', ownedOrg['id'])
                      .ilike('role_name', '%Admin%')
                      .limit(1)
                      .maybeSingle()
                      .timeout(const Duration(seconds: 10));
                  
                  if (adminRoleRes != null) {
                    userResponse['role_id'] = adminRoleRes['id']; // Update local var
                    updateData['role_id'] = adminRoleRes['id'];
                  }
                } catch (_) {}
             }

             unawaited(SupabaseConfig.client
                .from('omtbl_users')
                .update(updateData)
                .eq('id', userResponse['id'])
                .timeout(const Duration(seconds: 10))
                .catchError((e) => debugPrint('AuthNotifier: Quick update failed: $e')));
          }
        } catch (e) {
          debugPrint('AuthNotifier: Error checking org ownership: $e');
        }
      }

      debugPrint(
          'AuthNotifier: Found profile for ${sessionUser.email}: Role=${userResponse['role']}, OrgId=${userResponse['organization_id']}');

      // Auto-link if needed
      if (userResponse['auth_id'] != sessionUser.id) {
        unawaited(SupabaseConfig.client
            .from('omtbl_users')
            .update({'auth_id': sessionUser.id})
            .eq('id', userResponse['id'])); // Use ID as we found it via email
      }

      final roleId = userResponse['role_id'] as int?;
      final employeeId = userResponse['id'] as String?;
      final organizationId =
          userResponse['organization_id'] as int?; // Capture Org ID
      // BusinessPartner id of the logged-in user (Customer -> Salesman
      // assignment bridge). Legitimately null for the org owner/admin and
      // any user without a linked BusinessPartner/employee row.
      final businessPartnerId = userResponse['business_partner_id'] as String?;
      final roleStr = (userResponse['role'] as String?)?.toUpperCase();
      final fullName = userResponse['full_name'] as String?;

      // Determine the role
      //
      // Platform superUser status is no longer a hardcoded email
      // comparison (Phase 3B-4A-R) -- it now comes from the
      // is_platform_admin() SECURITY DEFINER function, which checks the
      // authoritative omtbl_platform_admins table for the CURRENT
      // authenticated caller (auth.uid()) only. This is still only a
      // client-side UI/RBAC convenience value -- any future privileged
      // Edge Function MUST independently re-verify the caller's JWT and
      // re-check the same table/function server-side; this client-derived
      // role must never be trusted as proof by a server.
      bool isPlatformAdmin = false;
      try {
        final rpcResult = await SupabaseConfig.client
            .rpc('is_platform_admin')
            .timeout(const Duration(seconds: 10));
        isPlatformAdmin = rpcResult == true;
      } catch (e) {
        // Fail closed: any error (migration not yet applied, network
        // issue, RPC missing) means "not a platform admin", never the
        // reverse. See PHASE3B_4A_R_PLATFORM_ADMIN_AUTHORITY.md.
        debugPrint('AuthNotifier: is_platform_admin() check failed: $e');
      }

      UserRole determinedRole = UserRole.staff;

      if (isPlatformAdmin) {
        determinedRole = UserRole.superUser;
      } else if (roleStr == 'OWNER' ||
                 roleStr == 'SUPER USER' ||
                 roleStr == 'CORPORATE_ADMIN' ||
                 roleStr == 'ADMIN' ||
                 roleStr == 'ORG_ADMIN' ||
                 roleStr == 'MANAGER') {
        determinedRole = UserRole.admin;
      }

      state = state.copyWith(
        userId: employeeId ?? '',
        userFullName: fullName ?? state.userFullName,
        role: determinedRole,
        organizationId: organizationId, // Update State
        businessPartnerId: businessPartnerId,
        // userId now holds omtbl_users.id, not the Auth UID -- safe for
        // create/save flows to use as `created_by` from this point on.
        applicationIdentityResolved: employeeId != null && employeeId.isNotEmpty,
      );
      AuthService.testRole = determinedRole; // Sync static role for permission checks

      // Super Users bypass all checks
      if (determinedRole == UserRole.superUser) {
        state = state.copyWith(isPermissionLoading: false);
        return;
      }

      // 2. Fetch Privileges
      // Note: Privileges are currently Role-Based (Global), not Org-Specific.
      // However, Multi-Tenancy is enforced via RLS on Data Tables.
      final filters = [];
      if (roleId != null) filters.add('role_id.eq.$roleId');
      if (employeeId != null) filters.add('employee_id.eq."$employeeId"');

      final dynamic privsResponse = filters.isEmpty
          ? []
          : await SupabaseConfig.client
              .from('omtbl_role_form_privileges')
              .select('*, omtbl_app_forms(form_code, module_name)')
              .or(filters.join(','));

      debugPrint(
          'AuthNotifier: Loaded ${privsResponse.length} dynamic privileges from DB');

      if (privsResponse.isEmpty) {
        debugPrint(
            'AuthNotifier: No dynamic privileges found for RoleId=$roleId / EmpId=$employeeId. Keeping defaults.');
        state = state.copyWith(isPermissionLoading: false);
        return;
      }

      // 3. Map & Merge Privileges
      // We use a Set to avoid duplicates and MERGE with existing defaults
      final Set<PermissionObject> permissionSet = Set.from(state.permissions);

      // Basic static permissions for staff to ensure they can at least see the dashboard
      if (determinedRole == UserRole.staff) {
        permissionSet.add(const PermissionObject('dashboard', Permission.read));
      }

      for (var p in privsResponse) {
        final form = p['omtbl_app_forms'];
        if (form == null) continue;

        final String formCode = form['form_code'] ?? '';
        final String? module = _mapFormCodeToModule(formCode);
        if (module == null) continue;

        final canRead = p['can_view'] == true || p['can_read'] == true;
        final canWrite = p['can_add'] == true || p['can_edit'] == true;
        final canDelete = p['can_delete'] == true;

        if (canRead) {
          permissionSet.add(PermissionObject(module, Permission.read));

          // MAP TO PARENT MODULES IF NECESSARY
          // If any accounting form is allowed, allow the 'accounting' module
          final accountingForms = [
            'chart_of_accounts',
            'coa',
            'bank_cash',
            'voucher_prefixes',
            'financial_sessions',
            'gl_setup',
            'transactions',
            'cash_flow',
            'account_types',
            'account_categories'
          ];
          if (accountingForms.contains(module)) {
            permissionSet
                .add(const PermissionObject('accounting', Permission.read));
          }

          // If any customers form is allowed, allow the 'customers' module
          final customersForms = [
            'customers',
            'payment_terms',
            'business_partners',
            'salesmen',
            'sales_manager',
          ];
          if (customersForms.contains(module)) {
            permissionSet
                .add(const PermissionObject('customers', Permission.read));
          }
        }

        if (canWrite) {
          permissionSet.add(PermissionObject(module, Permission.write));
          final accountingForms = [
            'chart_of_accounts',
            'coa',
            'bank_cash',
            'voucher_prefixes',
            'financial_sessions',
            'gl_setup',
            'transactions',
            'cash_flow'
          ];
          if (accountingForms.contains(module)) {
            permissionSet
                .add(const PermissionObject('accounting', Permission.write));
          }

          final customersForms = [
            'customers',
            'payment_terms',
            'business_partners',
            'salesmen',
            'sales_manager',
          ];
          if (customersForms.contains(module)) {
            permissionSet
                .add(const PermissionObject('customers', Permission.write));
          }
        }

        if (canDelete) {
          permissionSet.add(PermissionObject(module, Permission.delete));
          if (module == 'chart_of_accounts' ||
              module == 'coa' ||
              module == 'transactions') {
            permissionSet
                .add(const PermissionObject('accounting', Permission.delete));
          }
        }
      }

      final finalPermissions = permissionSet.toList();
      state = state.copyWith(
        permissions: finalPermissions,
        isPermissionLoading: false,
      );

      // Sync with AuthService so PermissionUtils works
      final Map<String, Set<Permission>> permissionMap = {};
      for (var p in finalPermissions) {
        permissionMap.putIfAbsent(p.module, () => {}).add(p.action);
      }
      AuthService.setPermissions = permissionMap;

    } catch (e) {
      debugPrint('Error loading dynamic permissions: $e');
      state = state.copyWith(isPermissionLoading: false);
    }
  }

  void login(UserRole role, {String fullName = ''}) {
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
      userFullName: fullName,
      permissions: _getPermissionsForRole(role),
      isPasswordRecovery: false,
      isPermissionLoading: false,
    );
    AuthService.testRole = role;
    loadDynamicPermissions();
  }

  void clearRecoveryStatus() {
    state = state.copyWith(isPasswordRecovery: false);
  }

  /// FIXED: Only initiate sign out. State cleanup is handled by the auth listener.
  Future<void> logout() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (e) {
      debugPrint('AuthNotifier: Error during Supabase sign-out: $e');
      // In case of error, we should still clear state to allow user to try again
      _clearAuthState();
    }
  }

  String? _mapFormCodeToModule(String code) {
    switch (code.toUpperCase()) {
      case 'FRM_CUSTOMERS':
        return 'customers';
      case 'FRM_ORDERS':
        return 'orders';
      case 'FRM_INVOICES':
        return 'invoices';
      case 'FRM_PRODUCTS':
        return 'products';
      case 'FRM_VENDORS':
        return 'vendors';
      case 'FRM_INVENTORY':
        return 'inventory';
      case 'FRM_BRANDS':
        return 'inventory';
      case 'FRM_CATEGORIES':
        return 'inventory';
      case 'FRM_UOM':
        return 'inventory';
      case 'FRM_EMPLOYEES':
        return 'employees';
      case 'FRM_DEPARTMENTS':
        return 'employees';
      case 'FRM_ROLES':
        return 'employees';
      case 'FRM_USERS':
        return 'employees';
      case 'FRM_STORES':
        return 'stores';
      case 'FRM_SETTINGS':
        return 'settings';
      case 'FRM_REPORTS':
        return 'reports';
      case 'FRM_ORGANIZATION':
        return 'organization';
      case 'FRM_COA':
        return 'accounting';
      case 'FRM_JOURNAL':
        return 'accounting';
      case 'FRM_TRANSACTIONS':
        return 'accounting';
      case 'FRM_PURCHASE_ORDERS':
        return 'orders';
      case 'FRM_STOCK_TRANSFER':
        return 'inventory';
      case 'FRM_PAYMENT_TERMS':
        return 'customers';
      default:
        // Fallback: strip FRM_ and use as is
        final fallback = code.toLowerCase().replaceFirst('frm_', '');
        return fallback.isEmpty ? null : fallback;
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
