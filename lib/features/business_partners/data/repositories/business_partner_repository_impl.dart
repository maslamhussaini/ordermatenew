import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/business_partners/data/models/business_partner_model.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/domain/repositories/business_partner_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/services/email_service.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class BusinessPartnerRepositoryImpl implements BusinessPartnerRepository {
  final _localRepository = BusinessPartnerLocalRepository();

  @override
  Future<List<BusinessPartner>> getPartners({
    bool? isCustomer,
    bool? isVendor,
    bool? isEmployee,
    bool? isSupplier,
    int? storeId,
    int? organizationId,
  }) async {
    // 1. Connectivity Check & Offline Mode Check
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
       // SECURITY (OFF-01): organizationId must be forwarded -- omitting it
       // previously caused the offline read to return every cached
       // organization's partners.
       return _localRepository.getLocalPartners(
          isCustomer: isCustomer ?? false,
          isVendor: isVendor ?? false,
          isEmployee: isEmployee ?? false,
          isSupplier: isSupplier ?? false,
          storeId: storeId,
          organizationId: organizationId,
       );
    }
    
    try {
      var query = SupabaseConfig.client
          .from('omtbl_businesspartners')
          .select('*, omtbl_roles(role_name), omtbl_business_types(business_type), omtbl_depts(name)')
          .eq('is_active', true);
      
      // Store Filter
      if (storeId != null) {
        // Match specific store OR organization-wide (null store_id)
        query = query.or('store_id.eq.$storeId,store_id.is.null');
      }

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      if (isCustomer == true) {
        query = query.eq('is_customer', 1);
      }
      if (isVendor == true) {
        query = query.eq('is_vendor', 1);
      }
      if (isEmployee == true) {
        query = query.eq('is_employee', 1);
      }
      if (isSupplier == true) {
        query = query.eq('is_supplier', 1);
      }

      final response = await query;
      final data = response as List<dynamic>;
      final partners = data.map((json) => BusinessPartnerModel.fromJson(json)).toList();
      
      // Cache
      await _localRepository.cachePartners(partners);
      
      return partners;
    } catch (e) {
      debugPrint('Online fetch failed: $e. Falling back to local.');
      return _localRepository.getLocalPartners(
          isCustomer: isCustomer ?? false,
          isVendor: isVendor ?? false,
          isEmployee: isEmployee ?? false,
          isSupplier: isSupplier ?? false,
          storeId: storeId,
          organizationId: organizationId,
       );
    }
  }

  @override
  Future<BusinessPartner> createPartner(BusinessPartner partner) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.addPartner(partner);
      return partner;
    }
    try {
      final model = _toModel(partner);
      final json = model.toJson();
      _prepareJsonForInsert(json, partner);

      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .upsert(json)
          .select('*, omtbl_roles(role_name), omtbl_business_types(business_type), omtbl_depts(name)')
          .single()
          .timeout(const Duration(seconds: 15));

      return BusinessPartnerModel.fromJson(response);
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        debugPrint('Network error creating partner, falling back to local: $e');
        await _localRepository.addPartner(partner);
        return partner;
      }
      debugPrint('Structural error creating partner (e.g. FK violation): $e');
      rethrow;
    }
  }

  @override
  Future<int> createPartners(List<BusinessPartner> partners) async {
    if (partners.isEmpty) return 0;
    if (SupabaseConfig.isOfflineLoggedIn) {
      for (final p in partners) {
        await _localRepository.addPartner(p);
      }
      return partners.length;
    }
    try {
       final batchData = partners.map((p) {
        final model = _toModel(p);
        final json = model.toJson();
        _prepareJsonForInsert(json, p);
        return json;
      }).toList();

      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .upsert(batchData)
          .select();

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to create business partners batch: $e');
    }
  }

  // Helper to standardise model creation
  BusinessPartnerModel _toModel(BusinessPartner partner) {
    if (partner is BusinessPartnerModel) return partner;
    return BusinessPartnerModel(
      id: partner.id,
      name: partner.name,
      phone: partner.phone,
      email: partner.email,
      address: partner.address,
      contactPerson: partner.contactPerson,
      latitude: partner.latitude,
      longitude: partner.longitude,
      businessTypeId: partner.businessTypeId,
      businessTypeName: partner.businessTypeName,
      cityId: partner.cityId,
      stateId: partner.stateId,
      countryId: partner.countryId,
      postalCode: partner.postalCode,
      organizationId: partner.organizationId,
      storeId: partner.storeId,
      createdBy: partner.createdBy,
      isCustomer: partner.isCustomer,
      isVendor: partner.isVendor,
      isEmployee: partner.isEmployee,
      isSupplier: partner.isSupplier,
      isActive: partner.isActive,
      createdAt: partner.createdAt,
      updatedAt: partner.updatedAt,
      roleId: partner.roleId,
      roleName: partner.roleName,
      departmentId: partner.departmentId,
      departmentName: partner.departmentName,
      chartOfAccountId: partner.chartOfAccountId,
      paymentTermId: partner.paymentTermId,
      managerId: partner.managerId,
    );
  }

  void _prepareJsonForInsert(Map<String, dynamic> json, BusinessPartner partner) {
    // Only remove ID if it's null or empty, preserving client-generated UUIDs
    if (json['id'] == null || json['id'].toString().isEmpty) {
      json.remove('id');
    }
    json.remove('created_at');
    json.remove('updated_at');

    json['is_customer'] = partner.isCustomer ? 1 : 0;
    json['is_vendor'] = partner.isVendor ? 1 : 0;
    json['is_employee'] = partner.isEmployee ? 1 : 0;
    json['is_supplier'] = partner.isSupplier ? 1 : 0;
    json['is_active'] = partner.isActive;
    
    // Sanitize role_id to prevent FK violations
    if (json.containsKey('role_id')) {
      if (json['role_id'] == 0) {
        json['role_id'] = null;
      }
      // If not an employee, force role_id to null to enforce clean data
      if (!partner.isEmployee) {
        json['role_id'] = null;
      }
    }

    // Remove fields not yet in DB schema or managed elsewhere
    json.remove('role_name');
    json.remove('payment_term_id');
    json.remove('password'); // Password belongs in AppUser/Auth, not BusinessPartner CRM table
    // json.remove('chart_of_account_id'); // Re-enabled per user request
  }

  @override
  Future<void> updatePartner(BusinessPartner partner) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.updatePartner(partner);
      return;
    }
    try {
      final model = _toModel(partner);

      final json = model.toJson();
      _prepareJsonForInsert(json, partner); // Use _prepareJsonForInsert for consistency

      await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .update(json)
          .eq('id', partner.id)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Network') || e.toString().contains('TimeoutException')) { // Added TimeoutException
        debugPrint('Network error updating partner, falling back to local: $e');
        await _localRepository.updatePartner(partner);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> deletePartner(String id) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
       // Offline Delete
       await _localRepository.deletePartner(id);
       return;
    }

    try {
      // Soft Delete
      await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .update({'is_active': false}) // Soft delete
          .eq('id', id);
      
      // Also delete from local if successful
      await _localRepository.deletePartner(id);

    } catch (e) {
      debugPrint('Delete partner failed online: $e. Falling back to local.');
      try {
        await _localRepository.deletePartner(id);
      } catch (localE) {
        throw Exception('Failed to delete business partner: $e');
      }
    }
  }

  @override
  Future<BusinessPartner?> getPartnerById(String id) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .select('*, omtbl_roles(role_name), omtbl_business_types(business_type), omtbl_depts(name)')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return BusinessPartnerModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get partner: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchBusinessTypes(String query) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_business_types')
          .select()
          .ilike('business_type', '%$query%')
          .eq('status', 1) 
          .limit(10);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBusinessTypes() async {
     try {
      final response = await SupabaseConfig.client
          .from('omtbl_business_types')
          .select()
          .eq('status', 1) 
          .order('business_type', ascending: true)
          .timeout(const Duration(seconds: 3));
      
      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheBusinessTypes(list);
      return list;
    } catch (e) {
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Network') || 
          e.toString().contains('TimeoutException')) {
        return _localRepository.getBusinessTypes();
      }
      // If we can't reach server and no local cache? Return empty or throw?
      // Better to return local if we have it, else valid caching ensures we do.
      // But if it's another error, we might still want local.
      try {
        return await _localRepository.getBusinessTypes();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<void> addBusinessType(String name) async {
    try {
      await SupabaseConfig.client.from('omtbl_business_types').insert({
        'business_type': name,
        'status': 1,
      });
      // We don't cache here immediately, assuming reload will be called.
      // But to be safe offline? 
      // If offline, we can't add to Supabase.
      // The requirement didn't explicitly ask for Offline Creation of *Metadata*, mostly viewing.
      // So I'll stick to online-only creation for now as per code structure.
    } catch (e) {
      throw Exception('Failed to add business type: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCities() async {
     try {
      final response = await SupabaseConfig.client
          .from('omtbl_cities')
          .select()
          .eq('status', 1) 
          .order('city_name', ascending: true)
          .timeout(const Duration(seconds: 3));
      
      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheCities(list);
      return list;
    } catch (e) {
      return await _localRepository.getCities();
    }
  }

  @override
  Future<void> addCity(String name) async {
    try {
      await SupabaseConfig.client.from('omtbl_cities').insert({
        'city_name': name,
        'status': 1,
      });
    } catch (e) {
      throw Exception('Failed to add city: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getStates() async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_states')
          .select()
          .eq('status', 1)
          .order('state_name', ascending: true)
          .timeout(const Duration(seconds: 3));
      
      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheStates(list);
      return list;
    } catch (e) {
      return await _localRepository.getStates();
    }
  }

  @override
  Future<void> addState(String name) async {
    await SupabaseConfig.client.from('omtbl_states').insert({
      'state_name': name,
      'status': 1,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getCountries() async {
     try {
      final response = await SupabaseConfig.client
          .from('omtbl_countries')
          .select()
          .eq('status', 1) 
          .order('country_name', ascending: true)
          .timeout(const Duration(seconds: 3));
      
      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheCountries(list);
      return list;
    } catch (e) {
      return await _localRepository.getCountries();
    }
  }

  @override
  Future<void> addCountry(String name) async {
    try {
      await SupabaseConfig.client.from('omtbl_countries').insert({
        'country_name': name,
        'status': 1,
      });
    } catch (e) {
      throw Exception('Failed to add country: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRoles({int? organizationId}) async {
    if (organizationId == null) {
      // Fail closed: without a known organization, return nothing rather
      // than risk returning roles across every tenant.
      return [];
    }
    try {
      final query = SupabaseConfig.client
          .from('omtbl_roles')
          .select()
          // status is a live smallint column (default 1), not boolean.
          .eq('status', 1)
          .eq('organization_id', organizationId);

      final response = await query.timeout(const Duration(seconds: 3));

      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheRoles(list);
      return list;
    } catch (e) {
      return await _localRepository.getRoles(organizationId: organizationId);
    }
  }

  @override
  Future<void> createAppUser({
    required String partnerId,
    required String email,
    required int roleId,
    String? fullName,
    int? organizationId,
    int? storeId,
    String? password,
  }) async {
    // 1. Connectivity Check
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) ||
        SupabaseConfig.isOfflineLoggedIn;

    // 2. Prepare Data (password intentionally not persisted locally either)
    if (isOffline) {
      await _localRepository.createAppUser(
        partnerId: partnerId,
        email: email,
        fullName: fullName,
        roleId: roleId,
        organizationId: organizationId ?? 0,
        storeId: storeId ?? 0,
      );
      debugPrint('AppUser created locally (Offline). Invitation not sent.');
      return;
    }

    // Flag to check if we managed to create the user with the correct Auth ID
    String? createdAuthUserId;

    try {
      // 1. Call Edge Function to create Auth User & Send Email
      debugPrint('Calling Edge Function to invite employee: $email');
      
      final response = await SupabaseConfig.client.functions.invoke(
        'invite-employee',
        body: {
          'email': email,
          'full_name': fullName ?? '',
          'role_id': roleId,
          'organization_id': organizationId,
          'store_id': storeId,
          'password': password,
          'generate_link': true,
          'redirect_to': SupabaseConfig.frontendUrl,
          'smtp_settings': {
             'username': EmailService().smtpUsername,
             'password': EmailService().smtpPassword,
          },
          'email_subject': 'Welcome to OrderMate!',
          'email_html': """
            <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px; max-width: 600px;">
              <h2 style="color: #2196F3;">Welcome to OrderMate, ${fullName ?? 'Employee'}!</h2>
              <p>An account has been created for you. You can log in using your email:</p>
              <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #dee2e6;">
                <p style="margin: 0 0 10px 0;"><strong>Username:</strong> $email</p>
              </div>
              <p>Please click the link below to access the application:</p>
              <div style="text-align: center; margin: 30px 0;">
                <a href="{{ACTION_URL}}" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Access OrderMate</a>
              </div>
              <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
              <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
            </div>
          """
        },
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to invite employee via Edge Function');
      }

      debugPrint('Edge Function success: ${response.data}');
      
      // Capture the ID returned by the Edge Function
      createdAuthUserId = response.data['user_id'];
    } catch (e) {
      debugPrint('Online AppUser invitation failed: $e. Falling back to offline-like creation.');
      // Proceed but we won't have the correct Auth ID :(
      // This user will likely need manual fix-up or re-invite later.
    }

    // 2. Create the App User (omtbl_users) using the Auth ID if available
    try {
        final userId = createdAuthUserId ?? const Uuid().v4();
        
        final data = {
          'id': userId,
          'auth_id': userId, // Ensure Auth link is established
          'business_partner_id': partnerId,
          'email': email,
          'full_name': fullName,
          'role_id': roleId,
          'is_active': true,
          // 'password' is intentionally NOT sent: omtbl_users has no such
          // column, and authentication passwords are handled by Supabase
          // Auth (set via the invite-employee Edge Function above), never
          // stored in OrderMate's own application database.
          'organization_id': organizationId,
          'store_id': storeId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Upsert based on email to handle duplicates gracefully
        await SupabaseConfig.client.from('omtbl_users').upsert(data, onConflict: 'email');
        debugPrint('AppUser upserted to omtbl_users with ID: $userId');

        // Sync local cache (password intentionally not persisted locally either)
        await _localRepository.createAppUser(
          partnerId: partnerId,
          email: email,
          fullName: fullName,
          roleId: roleId,
          organizationId: organizationId,
          storeId: storeId,
        );

    } catch (dbError) {
        debugPrint('Error creating AppUser in DB: $dbError');
        // If this fails, we have an orphan Auth User. 
    }

  }

  @override
  Future<List<AppUser>> getAppUsers(int organizationId) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn;

    if (isOffline) {
       final maps = await _localRepository.getAppUsersByOrg(organizationId);
       return maps.map((m) => AppUser.fromJson(m)).toList();
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_users')
          .select('*, omtbl_roles(role_name)')
          .eq('organization_id', organizationId);
      
      final data = response as List<dynamic>;
      await _localRepository.cacheAppUsers(data);
      return data.map((json) => AppUser.fromJson(json)).toList();
    } catch (e) {
       final maps = await _localRepository.getAppUsersByOrg(organizationId);
       return maps.map((m) => AppUser.fromJson(m)).toList();
    }
  }

  @override
  Future<AppUser?> getAppUser(String partnerId) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn;

    if (isOffline) {
      final map = await _localRepository.getAppUser(partnerId);
      if (map == null) return null;
      return AppUser.fromJson(map);
    }
    
    try {
      final res = await SupabaseConfig.client
          .from('omtbl_users')
          .select('*, omtbl_roles(role_name)')
          .eq('business_partner_id', partnerId)
          .maybeSingle(); // maybeSingle returns null if not found
          
      if (res == null) {
        // Fallback to check local? Maybe just return null.
        return null;
      }
      return AppUser.fromJson(res);
    } catch (e) {
      // Fallback
       final map = await _localRepository.getAppUser(partnerId);
       if (map == null) return null;
       return AppUser.fromJson(map);
    }
  }

  @override
  Future<void> updateAppUser(AppUser user, {String? password}) async {
    // NOTE: `password` is intentionally not written anywhere from this
    // method. omtbl_users has no password column, and this method does not
    // call the invite-employee Edge Function (unlike createAppUser), so
    // there is currently no Supabase-Auth-backed way to change an existing
    // user's password from here. Resetting an existing user's password is
    // a separate, not-yet-implemented flow (out of scope for this phase),
    // not something this method should silently attempt via plaintext
    // storage.
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn;

    if (isOffline) {
      await _localRepository.updateAppUser(user.toJson());
      return;
    }

    try {
      final data = user.toJson();
      // Remove local-only fields if any, or map correctly
      data.remove('id'); // Usually DB handles ID or we use UUID. If we update, we need PK?
      // Supabase update usually needs PK match?
      // Actually `update` query needs filtering.

      // Wait, user.id might be local ID?
      // If it exists in Supabase, we update by business_partner_id or ID?
      // Assuming 'id' in AppUser matches Supabase 'id'.
      // If we created it locally, ID might be UUID.

      final upsertData = {
        'id': user.id,
        'email': user.email,
        'full_name': user.fullName,
        'role_id': user.roleId,
        'is_active': user.isActive,
        'organization_id': user.organizationId,
        'store_id': user.storeId,
        'business_partner_id': user.businessPartnerId,
      };

      await SupabaseConfig.client
          .from('omtbl_users')
          .upsert(upsertData, onConflict: 'email');

      // Also update local
      await _localRepository.updateAppUser(user.toJson());
    } catch (e) {
      debugPrint('Online AppUser update failed: $e. Saving locally.');
      await _localRepository.updateAppUser(user.toJson());
    }
  }
  @override
  Future<List<Map<String, dynamic>>> getDepartments(int organizationId) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_depts')
          .select()
          .eq('organization_id', organizationId)
          .eq('status', 1)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 3));
      
      final list = List<Map<String, dynamic>>.from(response);
      await _localRepository.cacheDepartments(list);
      return list;
    } catch (e) {
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Network') || 
          e.toString().contains('TimeoutException') || 
          SupabaseConfig.isOfflineLoggedIn) {
        // Filter local departments by organization
        final allLocal = await _localRepository.getDepartments();
        // Since sqlite is untyped often, ensure types match or just filter
        return allLocal.where((d) => d['organization_id'] == organizationId).toList();
      }
      // Try local anyway
      try {
        final allLocal = await _localRepository.getDepartments();
        return allLocal.where((d) => d['organization_id'] == organizationId).toList();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<void> addDepartment(String name, int organizationId) async {
    // Check connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
       // Online-only for now unless sync queue handles metadata creation.
       // But user request implied "both online and offline" CRUD for parent table.
       // So I should save to local with is_synced=0?
       // My Local Repository addDepartment handles basic insert but ID generation?
       // For now, let's insert locally.
       await _localRepository.addDepartment({
         'name': name,
         'organization_id': organizationId
       });
       return;
    }

    try {
      final res = await SupabaseConfig.client.from('omtbl_depts').insert({
        'name': name,
        'organization_id': organizationId,
        'status': 1,
      }).select().single();
      
      // Cache the result
      await _localRepository.cacheDepartments([res]);
    } catch (e) {
      debugPrint('Failed to add department online: $e. Saving locally.');
      await _localRepository.addDepartment({
         'name': name,
         'organization_id': organizationId
       });
    }
  }

  @override
  Future<void> addRole(String name, int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
    bool isSystem = false,
    int? organizationId,
  }) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn;

    final Map<String, dynamic> data = {
      'role_name': name,
      'organization_id': organizationId,
      'department_id': departmentId,
      'can_read': canRead,
      'can_write': canWrite,
      'can_edit': canEdit,
      'can_print': canPrint,
      // 'is_system' is intentionally NOT sent: the live omtbl_roles table
      // has no such column (it was only ever added by the un-applied,
      // flagged-dangerous update_roles_schema.sql). The isSystem parameter
      // is kept for callers/local cache use, just not sent to PostgREST.
    };
    if (storeId != null) data['store_id'] = storeId;
    if (syear != null) data['syear'] = syear;

    if (isOffline) {
      await _localRepository.addRole(data);
      return;
    }

    try {
      final res = await SupabaseConfig.client.from('omtbl_roles').insert(data).select().single();
      await _localRepository.cacheRoles([res]);
    } catch (e) {
      debugPrint('Failed to add role online (Attempt 1): $e');
      if (e.toString().contains('Column') || e.toString().contains('column')) {
         try {
           data.remove('store_id');
           data.remove('syear');
           final res = await SupabaseConfig.client.from('omtbl_roles').insert(data).select().single();
           await _localRepository.cacheRoles([res]);
           return;
         } catch (e2) {
             debugPrint('Failed to add role online (Attempt 2): $e2. Saving locally.');
             await _localRepository.addRole(data);
         }
      } else {
         debugPrint('Saving locally due to error.');
         await _localRepository.addRole(data);
      }
    }
  }

  @override
  Future<void> updateRole(int id, String name, int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
  }) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn;

    final Map<String, dynamic> data = {
      'role_name': name,
      'department_id': departmentId,
      'can_read': canRead,
      'can_write': canWrite,
      'can_edit': canEdit,
      'can_print': canPrint,
    };
    // Keep local copy full
    final localData = Map<String, dynamic>.from(data);
     if (storeId != null) {
      data['store_id'] = storeId;
      localData['store_id'] = storeId;
    }
    if (syear != null) {
      data['syear'] = syear;
      localData['syear'] = syear;
    }

    if (isOffline) {
      await _localRepository.updateRole(id, name, departmentId,
          canRead: canRead, canWrite: canWrite, canEdit: canEdit, canPrint: canPrint,
          storeId: storeId, syear: syear);
      return;
    }

    try {
      await SupabaseConfig.client.from('omtbl_roles').update(data).eq('id', id);
      await _localRepository.updateRole(id, name, departmentId,
          canRead: canRead, canWrite: canWrite, canEdit: canEdit, canPrint: canPrint,
          storeId: storeId, syear: syear);
    } catch (e) {
      debugPrint('Failed to update role online (Attempt 1): $e.');
      if (e.toString().contains('Column') || e.toString().contains('column')) {
        try {
           data.remove('store_id');
           data.remove('syear');
           await SupabaseConfig.client.from('omtbl_roles').update(data).eq('id', id);
           // Still save locally with full data if possible, or simplified? 
           // Better to save full locally.
           await _localRepository.updateRole(id, name, departmentId,
              canRead: canRead, canWrite: canWrite, canEdit: canEdit, canPrint: canPrint,
              storeId: storeId, syear: syear);
           return;
        } catch (e2) {
           debugPrint('Failed to update role online (Attempt 2): $e2. Updating locally.');
        }
      }
      await _localRepository.updateRole(id, name, departmentId,
          canRead: canRead, canWrite: canWrite, canEdit: canEdit, canPrint: canPrint,
          storeId: storeId, syear: syear);
    }
  }

  @override
  Future<void> deleteRole(int id) async {
    try {
      await SupabaseConfig.client.from('omtbl_roles').delete().eq('id', id);
      await _localRepository.deleteRole(id);
    } catch (e) {
      debugPrint('Failed to delete role online: $e. Deleting locally.');
      await _localRepository.deleteRole(id);
    }
  }

  @override
  Future<void> updateDepartment(int id, String name) async {
    try {
      await SupabaseConfig.client.from('omtbl_depts').update({
        'name': name,
      }).eq('id', id);
      await _localRepository.updateDepartment(id, name);
    } catch (e) {
      debugPrint('Failed to update department online: $e. Updating locally.');
      await _localRepository.updateDepartment(id, name);
    }
  }

  @override
  Future<void> deleteDepartment(int id) async {
    try {
      await SupabaseConfig.client.from('omtbl_depts').update({
        'status': 0,
      }).eq('id', id);
      await _localRepository.deleteDepartment(id);
    } catch (e) {
      debugPrint('Failed to delete department online: $e. Deleting locally.');
      await _localRepository.deleteDepartment(id);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAppForms() async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
      return await _localRepository.getAppForms();
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_app_forms')
          .select()
          .eq('is_active', true)
          .order('module_name', ascending: true)
          .order('form_name', ascending: true);
      
      final list = List<Map<String, dynamic>>.from(response);
      // Update local cache
      await _localRepository.cacheAppForms(list); 
      return list;
    } catch (e) {
      debugPrint('Error fetching app forms online: $e');
      return await _localRepository.getAppForms();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFormPrivileges({int? roleId, String? employeeId}) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
      return await _localRepository.getFormPrivileges(roleId: roleId, employeeId: employeeId);
    }

    try {
      var query = SupabaseConfig.client.from('omtbl_role_form_privileges').select();
    
    if (roleId != null && employeeId != null) {
      query = query.or('role_id.eq.$roleId,employee_id.eq."$employeeId"');
    } else if (roleId != null) {
      query = query.eq('role_id', roleId);
    } else if (employeeId != null) {
      query = query.eq('employee_id', employeeId);
    } else {
      return [];
    }

      final response = await query;
      final list = List<Map<String, dynamic>>.from(response);
      
      // Normalize to 0/1 for UI consistency if needed, or just return as is.
      // Better to return as is but ensure UI handles both.
      // However, for local cache we MUST use 0/1.
      final normalized = list.map((p) => {
        ...p,
        'can_view': (p['can_view'] == true || p['can_view'] == 1) ? 1 : 0,
        'can_add': (p['can_add'] == true || p['can_add'] == 1) ? 1 : 0,
        'can_edit': (p['can_edit'] == true || p['can_edit'] == 1) ? 1 : 0,
        'can_delete': (p['can_delete'] == true || p['can_delete'] == 1) ? 1 : 0,
        'can_read': (p['can_read'] == true || p['can_read'] == 1) ? 1 : 0,
        'can_print': (p['can_print'] == true || p['can_print'] == 1) ? 1 : 0,
      }).toList();
      
      await _localRepository.saveBatchFormPrivileges(normalized);
      return normalized;
    } catch (e) {
      debugPrint('Error fetching privileges online: $e');
      return await _localRepository.getFormPrivileges(roleId: roleId, employeeId: employeeId);
    }
  }

  @override
  Future<void> saveBatchFormPrivileges(List<Map<String, dynamic>> privileges) async {
    if (privileges.isEmpty) return;

    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveBatchFormPrivileges(privileges);
      return;
    }

    try {
      // Upsert to Supabase - Ensure boolean values
      final supabaseData = privileges.map((p) => {
        ...p,
        'can_view': (p['can_view'] == 1 || p['can_view'] == true) ? 1 : 0,
        'can_add': (p['can_add'] == 1 || p['can_add'] == true) ? 1 : 0,
        'can_edit': (p['can_edit'] == 1 || p['can_edit'] == true) ? 1 : 0,
        'can_delete': (p['can_delete'] == 1 || p['can_delete'] == true) ? 1 : 0,
        'can_read': (p['can_read'] == 1 || p['can_read'] == true) ? 1 : 0,
        'can_print': (p['can_print'] == 1 || p['can_print'] == true) ? 1 : 0,
      }).toList();

      debugPrint('Saving ${supabaseData.length} privileges to Supabase');
      
      // We try to upsert. If ID is present, it uses ID. 
      // If not, we rely on our unique constraints (organization_id, role_id/employee_id, form_id).
      // Since we can't easily specify multiple complex onConflict targets in one call,
      // we'll rely on the fact that if ID is present it works, and if not, the unique constraints 
      // we added to the DB will handle the conflict if we specify them.
      // However, we'll split them to be safe.
      
      final rolePrivs = supabaseData.where((p) => p['role_id'] != null).toList();
      final empPrivs = supabaseData.where((p) => p['employee_id'] != null).toList();
      
      if (rolePrivs.isNotEmpty) {
        await SupabaseConfig.client.from('omtbl_role_form_privileges')
          .upsert(rolePrivs, onConflict: 'organization_id,role_id,form_id');
      }
      
      if (empPrivs.isNotEmpty) {
        await SupabaseConfig.client.from('omtbl_role_form_privileges')
          .upsert(empPrivs, onConflict: 'organization_id,employee_id,form_id');
      }
      
      // Also update local - Ensure integer values
      final localData = privileges.map((p) => {
        ...p,
        'can_view': (p['can_view'] == 1 || p['can_view'] == true) ? 1 : 0,
        'can_add': (p['can_add'] == 1 || p['can_add'] == true) ? 1 : 0,
        'can_edit': (p['can_edit'] == 1 || p['can_edit'] == true) ? 1 : 0,
        'can_delete': (p['can_delete'] == 1 || p['can_delete'] == true) ? 1 : 0,
        'can_read': (p['can_read'] == 1 || p['can_read'] == true) ? 1 : 0,
        'can_print': (p['can_print'] == 1 || p['can_print'] == true) ? 1 : 0,
      }).toList();

      await _localRepository.saveBatchFormPrivileges(localData);
    } catch (e) {
      debugPrint('Error saving privileges online: $e. Saving locally.');
      await _localRepository.saveBatchFormPrivileges(privileges);
    }
  }

  @override
  Future<List<int>> getRoleStoreAccess(int roleId) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_role_store_access')
          .select('store_id')
          .eq('role_id', roleId);
      final list = (response as List).map((e) => e['store_id'] as int).toList();
      // Cache locally
      final orgId = (await SupabaseConfig.client.from('omtbl_roles').select('organization_id').eq('id', roleId).single())['organization_id'];
      await _localRepository.saveRoleStoreAccess(roleId, list, orgId);
      return list;
    } catch (e) {
      return await _localRepository.getRoleStoreAccess(roleId);
    }
  }

  @override
  Future<void> saveRoleStoreAccess(int roleId, List<int> storeIds, int organizationId) async {
    try {
      await SupabaseConfig.client.from('omtbl_role_store_access').delete().eq('role_id', roleId);
      if (storeIds.isNotEmpty) {
        await SupabaseConfig.client.from('omtbl_role_store_access').insert(
          storeIds.map((sid) => {
            'role_id': roleId,
            'store_id': sid,
            'organization_id': organizationId
          }).toList()
        );
      }
      await _localRepository.saveRoleStoreAccess(roleId, storeIds, organizationId);
    } catch (e) {
      await _localRepository.saveRoleStoreAccess(roleId, storeIds, organizationId);
    }
  }

  @override
  Future<List<int>> getUserStoreAccess(String employeeId) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_user_store_access')
          .select('store_id')
          .eq('employee_id', employeeId);
      final list = (response as List).map((e) => e['store_id'] as int).toList();
      // Cache locally
      // Assuming we can get orgId from app_users
      final user = await getAppUser(employeeId);
      if (user != null) {
        await _localRepository.saveUserStoreAccess(employeeId, list, user.organizationId);
      }
      return list;
    } catch (e) {
      return await _localRepository.getUserStoreAccess(employeeId);
    }
  }

  @override
  Future<void> saveUserStoreAccess(String employeeId, List<int> storeIds, int organizationId) async {
    try {
      await SupabaseConfig.client.from('omtbl_user_store_access').delete().eq('employee_id', employeeId);
      if (storeIds.isNotEmpty) {
        await SupabaseConfig.client.from('omtbl_user_store_access').insert(
          storeIds.map((sid) => {
            'employee_id': employeeId,
            'store_id': sid,
            'organization_id': organizationId
          }).toList()
        );
      }
      await _localRepository.saveUserStoreAccess(employeeId, storeIds, organizationId);
    } catch (e) {
      await _localRepository.saveUserStoreAccess(employeeId, storeIds, organizationId);
    }
  }

  @override
  Future<void> sendEmployeeCredentials(BusinessPartner employee, String password) async {
    // 1. Connectivity Check
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
       throw Exception('Internet connection required to send credentials.');
    }

    if (employee.email == null || employee.email!.isEmpty) {
       throw Exception('Employee has no email address.');
    }

    try {
      // 1. Call Edge Function to create Auth User with specified password
      final response = await SupabaseConfig.client.functions.invoke(
        'invite-employee',
        body: {
          'email': employee.email,
          'full_name': employee.name,
          'role_id': employee.roleId ?? 0,
          'organization_id': employee.organizationId,
          'store_id': employee.storeId,
          'password': password,
          'generate_link': true,
          'redirect_to': SupabaseConfig.frontendUrl, 
          'smtp_settings': {
             'username': EmailService().smtpUsername,
             'password': EmailService().smtpPassword,
          },
          'email_subject': 'OrderMate App - Your Login Credentials',
          'email_html': """
            <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px; max-width: 600px;">
              <h2 style="color: #2196F3;">Hello, ${employee.name}!</h2>
              <p>Your OrderMate account is ready. Use the credentials below to log in.</p>
              <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #dee2e6;">
                <p style="margin: 0 0 10px 0;"><strong>Username:</strong> ${employee.email}</p>
                <p style="margin: 0;"><strong>Password:</strong> <code style="background: #eee; padding: 2px 5px; border-radius: 4px;">$password</code></p>
              </div>
              <p>After clicking the link below, you will be redirected to the app to set your permanent password.</p>
              <div style="text-align: center; margin: 30px 0;">
                <a href="{{ACTION_URL}}" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Set Credentials & Login</a>
              </div>
              <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
              <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
            </div>
          """
        },
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Edge function failed');
      }

      debugPrint('Edge Function Response: ${response.data}');

      String? authUserId = response.data['user_id'];
      if (authUserId == null && response.data['user'] != null) {
          authUserId = response.data['user']['id'];
      }
      
      if (authUserId == null) {
         // Attempt to find existing user by email if Edge Function didn't return ID (e.g. user already exists but script didn't pass ID back)
         final existingUser = await SupabaseConfig.client
             .from('omtbl_users')
             .select('id')
             .eq('email', employee.email!)
             .maybeSingle();
             
         if (existingUser != null) {
            authUserId = existingUser['id'];
         } else {
            // Cannot proceed without an ID
            throw Exception('Server returned success but no User ID provided, and user does not exist locally.');
         }
      }
      
      // 2. Update/Upsert omtbl_users
      await SupabaseConfig.client.from('omtbl_users').upsert({
        'id': authUserId,
        'email': employee.email,
        'full_name': employee.name,
        'role_id': employee.roleId ?? 0,
        'business_partner_id': employee.id,
        'organization_id': employee.organizationId,
        'store_id': employee.storeId,
        'is_active': true,
        'password': password, // Sync password as requested
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'email');

    } catch (e) {
      debugPrint('Error sending credentials: $e');
      throw Exception('Failed to send credentials: $e');
    }
  }
}
