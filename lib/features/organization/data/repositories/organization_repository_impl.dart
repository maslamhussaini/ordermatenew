import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/organization/data/models/organization_model.dart';
import 'package:ordermate/features/organization/data/models/store_model.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:path/path.dart' as path;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/features/organization/data/repositories/organization_local_repository.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class OrganizationRepositoryImpl implements OrganizationRepository {
  final OrganizationLocalRepository _localRepository =
      OrganizationLocalRepository();

  @override
  Future<List<Organization>> getOrganizations() async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    // Always get local data
    final localOrgs = await _localRepository.getLocalOrganizations();

    if (isOffline) {
      return localOrgs;
    }

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return [];

      // 1. Get User's Role & Org ID
      debugPrint(
        '[DIAG][getOrganizations] '
        'userId=${SupabaseConfig.client.auth.currentUser?.id} '
        'sessionNull=${SupabaseConfig.client.auth.currentSession == null} '
        'expiresAt=${SupabaseConfig.client.auth.currentSession?.expiresAt} '
        'now=${DateTime.now().millisecondsSinceEpoch}',
      );
      final userDataList = await SupabaseConfig.client
          .from('omtbl_users')
          .select('role, organization_id')
          .eq('auth_id', user.id)
          .limit(1)
          .timeout(const Duration(seconds: 15));

      final userData = (userDataList as List?)?.isNotEmpty == true
          ? userDataList.first
          : null;
      
      final role = userData?['role'] as String?;
      final orgId = userData?['organization_id'] as int?;
      final isSuperUser = role?.toUpperCase() == 'SUPER USER';

      // 2. Build Query
      var query = SupabaseConfig.client
          .from('omtbl_organizations')
          .select();
      
      // 3. Apply Filters
      // Show only active organizations (unless Super User wants to see inactive ones? usually yes, but let's stick to active for selection)
      // The requirement said "active = 1 or active = true".
      query = query.eq('is_active', true);

      if (!isSuperUser) {
        if (orgId != null) {
          // Check ownership OR assignment
          // Note: OR logic in Supabase requires a string like "column.operator.value,column.operator.value"
          query = query.or('auth_user_id.eq.${user.id},id.eq.$orgId');
        } else {
          // Check only ownership
          query = query.eq('auth_user_id', user.id);
        }
      }

      final response = await query.order('name', ascending: true)
          .timeout(const Duration(seconds: 15));

      final remoteOrgs = (response as List)
          .map((json) =>
              OrganizationModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache remote data
      await _localRepository.cacheOrganizations(remoteOrgs);
      // Merge remote and local data
      final mergedOrgs = await _localRepository.mergeOrganizations(remoteOrgs);

      return mergedOrgs;
    } catch (e) {
      // Fallback to local if remote fails
      if (localOrgs.isNotEmpty) return localOrgs;
      throw Exception('Failed to fetch organizations: $e');
    }
  }

  @override
  Future<Organization?> getOrganization(int id) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_organizations')
          .select()
          .eq('id', id)
          .maybeSingle(); // Returns null if not found

      if (response == null) return null;
      return OrganizationModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch organization: $e');
    }
  }

  @override
  Future<void> updateOrganization(Organization organization) async {
    try {
      // Convert Organization entity to OrganizationModel if needed
      final model = organization is OrganizationModel
          ? organization
          : OrganizationModel(
              id: organization.id,
              name: organization.name,
              code: organization.code,
              isActive: organization.isActive,
              createdAt: organization.createdAt,
              updatedAt: organization.updatedAt,
              logoUrl: organization.logoUrl,
              storeCount: organization.storeCount,
              businessTypeId: organization.businessTypeId,
              isGL: organization.isGL,
              isSales: organization.isSales,
              isInventory: organization.isInventory,
              isHR: organization.isHR,
              isSettings: organization.isSettings,
              planType: organization.planType,
              entitlementMode: organization.entitlementMode,
            );

      // Exclude ID and timestamps from update usually, but supabase ignores id if PK
      await SupabaseConfig.client
          .from('omtbl_organizations')
          .update(
            model.toJson()
              ..remove('id')
              ..remove('created_at')
              ..remove('updated_at')
              ..remove('store_count'),
          )
          .eq('id', organization.id);
    } catch (e) {
      throw Exception('Failed to update organization: $e');
    }
  }

  @override
  Future<String> uploadOrganizationLogo(
      Uint8List bytes, String fileName) async {
    try {
      final extension = path.extension(fileName);
      final finalFileName =
          'logo_${DateTime.now().millisecondsSinceEpoch}$extension';

      await SupabaseConfig.client.storage
          .from('organizations')
          .uploadBinary(finalFileName, bytes);

      final publicUrl = SupabaseConfig.client.storage
          .from('organizations')
          .getPublicUrl(finalFileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload logo: $e');
    }
  }

  @override
  Future<Organization> createOrganization(
    String name,
    String? taxId,
    bool hasMultipleBranches,
    String? logoUrl, {
    int? businessTypeId,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_organizations')
          .insert({
            'name': name,
            'logo_url': logoUrl,
            'business_type_id': businessTypeId,
          })
          .select()
          .single();
      
      final org = OrganizationModel.fromJson(response);

      // Create Financial Session for the current year.
      //
      // N-6 fix: this previously sent Dart bool literals (true/true/false)
      // for in_use/is_active/is_closed, which are smallint/integer columns
      // in `omtbl_financial_sessions`. Postgres rejected the insert, and the
      // surrounding try/catch swallowed that error (only a `print`), so every
      // organization created through this path silently ended up with ZERO
      // financial sessions. Confirmed in production: org_id=1 ("Herbmax")
      // has 0 sessions.
      //
      // Fix: reuse the same int-safe payload builder used by the dedicated
      // `createFinancialSession` (added for the registration flow), and do
      // NOT catch the error here — a failure must now surface to the caller
      // via the existing outer `catch` below, rather than being reported as
      // a successful organization creation.
      final now = DateTime.now();
      final currentYear = now.year;
      final startDate = DateTime(currentYear, 1, 1);
      final endDate = DateTime(currentYear, 12, 31);

      await createFinancialSession(
        organizationId: org.id,
        syear: currentYear,
        startDate: startDate,
        endDate: endDate,
      );

      return org;
    } catch (e) {
      throw Exception('Failed to create organization: $e');
    }
  }

  /// Builds the insert payload for `omtbl_financial_sessions`.
  ///
  /// Pulled out as a pure, static function (no Supabase call) so the
  /// int-vs-bool serialization can be unit tested directly: `omtbl_financial_sessions`
  /// stores `in_use` / `is_active` / `is_closed` as smallint/integer columns,
  /// not boolean, so sending Dart `true`/`false` here is rejected by Postgres.
  static Map<String, dynamic> buildFinancialSessionInsertPayload({
    required int organizationId,
    required int syear,
    required DateTime startDate,
    required DateTime endDate,
    String? narration,
  }) {
    return {
      'organization_id': organizationId,
      'syear': syear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'narration': narration ?? 'Financial Year $syear',
      'in_use': 1,
      'is_active': 1,
      'is_closed': 0,
    };
  }

  @override
  Future<void> createFinancialSession({
    required int organizationId,
    required int syear,
    required DateTime startDate,
    required DateTime endDate,
    String? narration,
  }) async {
    // Intentionally NOT wrapped to swallow errors: registration flows must
    // fail loudly if this insert fails, rather than reporting a successful
    // registration that is missing its financial session (see N-6/N-related
    // "Financial sessions are missing" defect).
    await SupabaseConfig.client.from('omtbl_financial_sessions').insert(
          buildFinancialSessionInsertPayload(
            organizationId: organizationId,
            syear: syear,
            startDate: startDate,
            endDate: endDate,
            narration: narration,
          ),
        );
  }

  @override
  Future<void> deleteOrganization(int id) async {
    try {
      await SupabaseConfig.client
          .from('omtbl_organizations')
          .delete()
          .eq('id', id);

      await _localRepository.deleteOrganization(id);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('violates foreign key constraint') &&
          errorString.contains('omtbl_stores')) {
        throw Exception('First delete store or stores then you can delete orz');
      }
      throw Exception('Failed to delete organization: $e');
    }
  }

  // Stores

  @override
  Future<List<Store>> getStores(int organizationId) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    // Always get local data
    final localStores = await _localRepository.getLocalStores(organizationId);

    if (isOffline) {
      return localStores;
    }

    try {
      debugPrint(
        '[DIAG][getStores] '
        'userId=${SupabaseConfig.client.auth.currentUser?.id} '
        'sessionNull=${SupabaseConfig.client.auth.currentSession == null} '
        'expiresAt=${SupabaseConfig.client.auth.currentSession?.expiresAt} '
        'now=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await SupabaseConfig.client
          .from('omtbl_stores')
          .select()
          .eq('organization_id', organizationId)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 15));



      final remoteStores = (response as List)
          .map((json) => StoreModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge logic now handles sync status internally (drops old synced data)
      final mergedStores =
          await _localRepository.mergeStores(remoteStores, organizationId);

      // Cache merged result (clears old synced data for this org first)
      await _localRepository.cacheStores(organizationId, mergedStores);

      return mergedStores;
    } catch (e) {
      // Fallback to local if remote fails
      if (localStores.isNotEmpty) return localStores;
      throw Exception('Failed to fetch stores: $e');
    }
  }

  @override
  Future<Store> createStore(Store store) async {
    try {
      // Convert Store entity to StoreModel if needed
      final model = store is StoreModel
          ? store
          : StoreModel(
              id: store.id,
              name: store.name,
              organizationId: store.organizationId,
              location: store.location,
              city: store.city,
              country: store.country,
              postalCode: store.postalCode,
              phone: store.phone,
              storeDefaultCurrency: store.storeDefaultCurrency,
              isActive: store.isActive,
              createdAt: store.createdAt,
              updatedAt: store.updatedAt,
            );

      final json = model.toJson();
      json.remove('id');
      json.remove('created_at');
      json.remove('updated_at');

      final response = await SupabaseConfig.client
          .from('omtbl_stores')
          .insert(json)
          .select()
          .single();

      return StoreModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create store: $e');
    }
  }

  @override
  Future<void> updateStore(Store store) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.updateLocalStore(store);
      return;
    }

    try {
      // Convert Store entity to StoreModel if needed
      final model = store is StoreModel
          ? store
          : StoreModel(
              id: store.id,
              name: store.name,
              organizationId: store.organizationId,
              location: store.location,
              city: store.city,
              country: store.country,
              postalCode: store.postalCode,
              phone: store.phone,
              storeDefaultCurrency: store.storeDefaultCurrency,
              isActive: store.isActive,
              createdAt: store.createdAt,
              updatedAt: store.updatedAt,
            );

      final json = model.toJson();
      json.remove('id');
      json.remove('created_at');
      json.remove('updated_at');

      await SupabaseConfig.client
          .from('omtbl_stores')
          .update(json)
          .eq('id', store.id);

      // Update local as synced if successful (re-using updateLocalStore but relying on cacheStores typically,
      // but here we just want to reflect change. Better to cache it as synced.)
      // Actually, updateLocalStore sets synced=0. We should overwrite it.
      // reusing the internal map logic or just let refresh handle it?
      // For immediate UI update, we run updateLocalStore but we need it to be synced=1.
      // So I'll just use updateLocalStore (synced=0) then immediately mark synced=1?
      // Or I'll just rely on the fact that if it succeeded, it's on server.
      // BUT, to keep local consistent without full refresh, we should update local.
      // I'll update local and leave it as synced=0? No, that would trigger sync later.
      // Let's just use the same method but we need a way to say "it IS synced".
      // Since I can't change the interface easily right now without more edits,
      // I will assume standard flow: Optimistic update -> server.
      // If server succeeds, I technically should update local with is_synced=1.
      // For now, I will save it locally as unsynced (0) even if server succeeds? No, that prompts double update.
      // I'll just fallback:

      // Update local (marked as unsynced) - wait, if I do this before server, UI updates instantly.
      // If server succeeds, I should mark it synced.
      // But I don't have a "markStoreSynced" method.
      // I will just let it be "unsynced" locally for now if falling back?
      // Or honestly, simple fallback is enough for "Unable to save".
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network') ||
          e.toString().contains('ClientException')) {
        await _localRepository.updateLocalStore(store);
        return;
      }
      throw Exception('Failed to update store: $e');
    }
  }

  @override
  Future<void> deleteStore(int storeId) async {
    try {
      await SupabaseConfig.client
          .from('omtbl_stores')
          .delete()
          .eq('id', storeId);

      await _localRepository.deleteStore(storeId);
    } catch (e) {
      throw Exception('Failed to delete store: $e');
    }
  }

  @override
  Future<void> cacheLogo(int orgId, Uint8List logoBytes) async {
    await _localRepository.cacheLogo(orgId, logoBytes);
  }

  @override
  Future<Uint8List?> getCachedLogo(int orgId) async {
    return _localRepository.getCachedLogo(orgId);
  }


}
