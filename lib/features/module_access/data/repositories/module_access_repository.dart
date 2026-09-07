import 'package:flutter/foundation.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/module_access/domain/entities/module_models.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/data/models/organization_model.dart'; // Assuming this exists

class ModuleAccessRepository {
  
  Future<List<Organization>> getOrganizations() async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_organizations')
          .select()
          .order('name', ascending: true);
      
      return (response as List).map((json) => OrganizationModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching organizations: $e');
      rethrow;
    }
  }

  Future<List<Module>> getModules() async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_modules')
          .select()
          .order('display_name', ascending: true);
      
      return (response as List).map((json) => Module.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching modules: $e');
      return [];
    }
  }

  Future<List<AppForm>> getForms() async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_app_forms')
          .select()
          .order('form_name', ascending: true);
      
      return (response as List).map((json) => AppForm.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching forms: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAccessData(int organizationId) async {
    try {
      // Fetch Module Access (Org -> Module)
      final accessResponse = await SupabaseConfig.client
          .from('omtbl_module_access')
          .select()
          .eq('organization_id', organizationId);
          
      // Fetch Access Items (Org -> Form)
      final itemsResponse = await SupabaseConfig.client
          .from('omtbl_module_access_items')
          .select()
          .eq('organization_id', organizationId);

      return {
        'access': accessResponse,
        'items': itemsResponse,
      };
    } catch (e) {
      debugPrint('Error fetching access data: $e');
      return {'access': [], 'items': []};
    }
  }

  Future<void> saveConfiguration({
    required int organizationId,
    required List<ModuleAccess> accesses,
    required List<ModuleAccessItem> items,
  }) async {
    try {
      // 1. Upsert Module Access
      if (accesses.isNotEmpty) {
        final accessData = accesses.map((e) => e.toJson()).toList();
        await SupabaseConfig.client
            .from('omtbl_module_access')
            .upsert(accessData, onConflict: 'organization_id, module_id');
      }

      // 2. Upsert Module Access Items
      if (items.isNotEmpty) {
        final itemData = items.map((e) => e.toJson()).toList();
        await SupabaseConfig.client
            .from('omtbl_module_access_items')
            .upsert(itemData, onConflict: 'form_id, module_id, organization_id');
      }
    } catch (e) {
      debugPrint('Error saving configuration: $e');
      rethrow;
    }
  }
}
