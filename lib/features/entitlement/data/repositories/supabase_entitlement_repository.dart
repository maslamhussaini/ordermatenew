import 'package:flutter/foundation.dart';

import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/entitlement/domain/entities/catalog_entries.dart';
import 'package:ordermate/features/entitlement/domain/repositories/entitlement_repository.dart';

/// Live Supabase/PostgREST implementation of [EntitlementRepository].
///
/// Every method here is a read (`select`) only -- no `insert`/`update`/
/// `upsert`/`delete` is ever issued, per Phase 3B-2's read/evaluation-only
/// scope. Column names below were independently re-verified against the
/// live PostgREST OpenAPI schema in this session (2026-09-03):
///   omtbl_organization_bundle_entitlement: id, organization_id, bundle_id,
///     price_paid, is_enabled, created_at
///   omtbl_organization_bundle_entitlement_items: id,
///     org_bundle_entitlement_id, form_id, price_at_purchase
/// (The prior architecture doc had flagged the bundle status column name as
/// unconfirmed -- it is `is_enabled`, not `is_active`.)
class SupabaseEntitlementRepository implements EntitlementRepository {
  SupabaseEntitlementRepository();

  // Catalog rows (omtbl_modules/omtbl_app_forms) are static reference data
  // within an app session -- caching them avoids re-querying the same
  // module/form on every router redirect check or menu rebuild. Per-org
  // entitlement rows below are NOT cached: those are the thing an admin can
  // actually change at runtime, so correctness there takes priority over
  // avoiding a query.
  final Map<String, ModuleCatalogEntry?> _moduleCache = {};
  final Map<int, AppFormCatalogEntry?> _formCache = {};

  @override
  Future<ModuleCatalogEntry?> getModule(String moduleId) async {
    if (_moduleCache.containsKey(moduleId)) return _moduleCache[moduleId];

    final response = await SupabaseConfig.client
        .from('omtbl_modules')
        .select('id, is_purchasable')
        .eq('id', moduleId)
        .maybeSingle();

    debugPrint('[ENTITLEMENT-DEBUG] getModule("$moduleId") raw response: $response');
    final entry = response == null ? null : ModuleCatalogEntry.fromJson(response);
    if (entry != null) {
      debugPrint('[ENTITLEMENT-DEBUG] getModule("$moduleId") parsed: id=${entry.id}, isPurchasable=${entry.isPurchasable}');
    } else {
      debugPrint('[ENTITLEMENT-DEBUG] getModule("$moduleId") parsed: null');
    }
    _moduleCache[moduleId] = entry;
    return entry;
  }

  @override
  Future<AppFormCatalogEntry?> getForm(int formId) async {
    if (_formCache.containsKey(formId)) return _formCache[formId];

    final response = await SupabaseConfig.client
        .from('omtbl_app_forms')
        .select('id, module_id, is_active, kind')
        .eq('id', formId)
        .maybeSingle();

    debugPrint('[ENTITLEMENT-DEBUG] getForm($formId) raw response: $response');
    final entry = response == null ? null : AppFormCatalogEntry.fromJson(response);
    if (entry != null) {
      debugPrint('[ENTITLEMENT-DEBUG] getForm($formId) parsed: id=${entry.id}, moduleId=${entry.moduleId}, isActive=${entry.isActive}, kind=${entry.kind}');
    } else {
      debugPrint('[ENTITLEMENT-DEBUG] getForm($formId) parsed: null');
    }
    _formCache[formId] = entry;
    return entry;
  }

  @override
  Future<bool> hasEnabledModuleAccessItem(
      int organizationId, String moduleId) async {
    final response = await SupabaseConfig.client
        .from('omtbl_module_access_items')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('module_id', moduleId)
        .eq('is_enabled', true)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  @override
  Future<bool> hasEnabledFormAccessItem(
      int organizationId, int formId) async {
    final response = await SupabaseConfig.client
        .from('omtbl_module_access_items')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('form_id', formId)
        .eq('is_enabled', true)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  @override
  Future<bool> hasActiveBundleAccessToForm(
      int organizationId, int formId) async {
    // Two-step read (no PostgREST embedded-join assumption): first the
    // organization's active bundle entitlements, then whether any of them
    // includes this form. Kept deliberately simple/explicit over an
    // embedded-resource query so it doesn't depend on an unverified FK
    // relationship name inside PostgREST's schema cache.
    final entitlements = await SupabaseConfig.client
        .from('omtbl_organization_bundle_entitlement')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('is_enabled', true);

    final entitlementIds = (entitlements as List)
        .map((row) => (row as Map<String, dynamic>)['id'])
        .toList();

    if (entitlementIds.isEmpty) return false;

    final items = await SupabaseConfig.client
        .from('omtbl_organization_bundle_entitlement_items')
        .select('id')
        .inFilter('org_bundle_entitlement_id', entitlementIds)
        .eq('form_id', formId)
        .limit(1);

    return (items as List).isNotEmpty;
  }
}
