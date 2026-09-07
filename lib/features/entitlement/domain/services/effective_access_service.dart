import 'package:flutter/foundation.dart';

import 'package:ordermate/features/entitlement/domain/entities/catalog_entries.dart';
import 'package:ordermate/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';

/// The single authoritative commercial-entitlement evaluation path.
///
/// Implements exactly `effectiveModuleAccess`, `effectiveFormAccess`, and
/// `effectiveReportAccess` as specified in
/// `audit_results/PHASE3B_FINAL_COMMERCIAL_ENTITLEMENT_DECISIONS.md` §11.
///
/// This class answers ONE question only: "is this commercially available to
/// this organization." It never consults role authorization
/// (`roleAuthorizedFor`) and never consults store/data scope
/// (`accessible_store_ids()`) -- those remain separate layers a caller
/// applies afterward. See §9/§10 of the decisions doc for why collapsing
/// them would be wrong.
class EffectiveAccessService {
  const EffectiveAccessService(this._repository);

  final EntitlementRepository _repository;

  /// §11 `effectiveModuleAccess`.
  ///
  /// - Non-purchasable/baseline module (or a module id the catalog doesn't
  ///   recognize as purchasable) -> always true.
  /// - `entitlement_mode == 'legacy'` -> `Organization.isModuleEnabled()`,
  ///   unchanged, `omtbl_module_access_items` is never consulted.
  /// - `entitlement_mode == 'explicit'` -> ANY enabled
  ///   `omtbl_module_access_items` row for this org+module (fail-closed if
  ///   the module is unknown to the catalog).
  Future<bool> effectiveModuleAccess(Organization org, String moduleId) async {
    final module = await _repository.getModule(moduleId);
    if (module == null) return false;
    if (!module.isPurchasable) return true;

    if (org.entitlementMode == 'legacy') {
      return org.isModuleEnabled(moduleId);
    }

    return _repository.hasEnabledModuleAccessItem(org.id, moduleId);
  }

  /// §11 `effectiveFormAccess`.
  ///
  /// - Form must exist and be `is_active`.
  /// - Baseline/non-purchasable module -> always true (once form checks
  ///   pass).
  /// - Legacy mode -> the org's boolean-flag module entitlement.
  /// - Explicit mode -> the EXACT `(org, form_id)` enabled row, never the
  ///   ANY/module-level check (§7/§11: "Sales purchased, Returns disabled"
  ///   must yield module=true, form=false).
  Future<bool> effectiveFormAccess(Organization org, int formId) async {
    debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess START: organizationId=${org.id}, formId=$formId');
    try {
      final form = await _repository.getForm(formId);
      if (form == null || !form.isActive) {
        debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess EARLY RETURN false: form=${form != null}, isActive=${form?.isActive}');
        return false;
      }
      debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess form OK: id=${form.id}, moduleId=${form.moduleId}, isActive=${form.isActive}');
      final result = await _formEntitled(org, form);
      debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess END: formId=$formId, result=$result');
      return result;
    } catch (e, stack) {
      debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess EXCEPTION: org=${org.id}, formId=$formId, error=$e');
      debugPrint('[ENTITLEMENT-DEBUG] effectiveFormAccess STACK: $stack');
      rethrow;
    }
  }

  /// §11 `effectiveReportAccess`.
  ///
  /// A report is a `kind='report'` row in the same `omtbl_app_forms` table.
  /// Entitlement is the additive OR of three paths (§6/§11):
  ///   A) module purchase / individual form-level row (same check as
  ///      `effectiveFormAccess`, reused rather than duplicated),
  ///   B) covered by path A -- an individually-purchased report is just an
  ///      enabled `omtbl_module_access_items` row for that one form_id,
  ///   C) an active bundle entitlement containing this report.
  /// None of the three paths override or cancel another.
  Future<bool> effectiveReportAccess(Organization org, int reportFormId) async {
    final form = await _repository.getForm(reportFormId);
    if (form == null || !form.isActive || !form.isReport) return false;

    if (await _formEntitled(org, form)) return true;

    // Bundle entitlement is an explicit-mode-only acquisition path: legacy
    // orgs have no bundle rows and are fully governed by the boolean flags,
    // which _formEntitled already evaluated above.
    if (org.entitlementMode == 'explicit') {
      return _repository.hasActiveBundleAccessToForm(org.id, reportFormId);
    }

    return false;
  }

  /// Shared module/form-level entitlement check for an already-fetched
  /// [form], reused by both `effectiveFormAccess` and `effectiveReportAccess`
  /// so a report lookup never re-queries the same form row twice.
  Future<bool> _formEntitled(Organization org, AppFormCatalogEntry form) async {
    final moduleId = form.moduleId;
    debugPrint('[ENTITLEMENT-DEBUG] _formEntitled START: organizationId=${org.id}, formId=${form.id}, moduleId=$moduleId');
    if (moduleId == null) {
      debugPrint('[ENTITLEMENT-DEBUG] _formEntitled RETURN false: moduleId is null');
      return false;
    }

    final module = await _repository.getModule(moduleId);
    if (module == null) {
      debugPrint('[ENTITLEMENT-DEBUG] _formEntitled RETURN false: module is null for moduleId=$moduleId');
      return false;
    }
    debugPrint('[ENTITLEMENT-DEBUG] _formEntitled module: id=${module.id}, isPurchasable=${module.isPurchasable}');
    if (!module.isPurchasable) {
      debugPrint('[ENTITLEMENT-DEBUG] _formEntitled RETURN true: module is not purchasable (baseline)');
      return true;
    }

    if (org.entitlementMode == 'legacy') {
      final legacyResult = org.isModuleEnabled(moduleId);
      debugPrint('[ENTITLEMENT-DEBUG] _formEntitled legacy check: entitlementMode=${org.entitlementMode}, isModuleEnabled("$moduleId")=$legacyResult');
      return legacyResult;
    }

    final explicitResult = await _repository.hasEnabledFormAccessItem(org.id, form.id);
    debugPrint('[ENTITLEMENT-DEBUG] _formEntitled explicit check: hasEnabledFormAccessItem(orgId=${org.id}, formId=${form.id})=$explicitResult');
    return explicitResult;
  }
}
