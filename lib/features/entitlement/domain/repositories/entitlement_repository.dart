import 'package:ordermate/features/entitlement/domain/entities/catalog_entries.dart';

/// Read-only access to the Phase 3A commercial-entitlement catalog and
/// per-organization grant tables. No method on this interface performs a
/// write (INSERT/UPDATE/DELETE/UPSERT) -- Phase 3B-2 is evaluation only.
abstract class EntitlementRepository {
  /// Looks up one row from `omtbl_modules` by its text id.
  Future<ModuleCatalogEntry?> getModule(String moduleId);

  /// Looks up one row from `omtbl_app_forms` by its numeric id.
  Future<AppFormCatalogEntry?> getForm(int formId);

  /// True if `omtbl_module_access_items` has ANY row for
  /// `(organizationId, moduleId)` with `is_enabled = true`.
  ///
  /// Per PHASE3B_FINAL_COMMERCIAL_ENTITLEMENT_DECISIONS.md §8: this is the
  /// module-purchased check, deliberately ANY (not ALL) so that disabling
  /// one form within an already-purchased module does not un-purchase the
  /// module itself.
  Future<bool> hasEnabledModuleAccessItem(int organizationId, String moduleId);

  /// True if `omtbl_module_access_items` has the EXACT row for
  /// `(organizationId, formId)` with `is_enabled = true`.
  ///
  /// This is the real, final gate for opening a specific form/report in
  /// explicit mode -- never the ANY/module-level check above.
  Future<bool> hasEnabledFormAccessItem(int organizationId, int formId);

  /// True if the organization has an active (`is_enabled=true`) bundle
  /// entitlement (`omtbl_organization_bundle_entitlement` joined to
  /// `omtbl_organization_bundle_entitlement_items`) that includes [formId].
  Future<bool> hasActiveBundleAccessToForm(int organizationId, int formId);
}
