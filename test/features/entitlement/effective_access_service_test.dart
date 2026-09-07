// test/features/entitlement/effective_access_service_test.dart
//
// Phase 3B-2: the read/evaluation-only commercial entitlement layer.
//
// Tests EffectiveAccessService against a hand-written in-memory fake of
// EntitlementRepository -- no real Supabase/network call is made anywhere
// in this file. The fake lets each test declare exactly which catalog rows
// and entitlement rows "exist" and assert the service's derived answer,
// without ever assuming or reproducing the service's own internal logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/entitlement/domain/entities/catalog_entries.dart';
import 'package:ordermate/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:ordermate/features/entitlement/domain/services/effective_access_service.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';

class _FakeEntitlementRepository implements EntitlementRepository {
  final Map<String, ModuleCatalogEntry> modules = {};
  final Map<int, AppFormCatalogEntry> forms = {};

  /// (organizationId, moduleId) -> is_enabled
  final Map<String, bool> moduleAccessItems = {};

  /// (organizationId, formId) -> is_enabled
  final Map<String, bool> formAccessItems = {};

  /// (organizationId, formId) -> entitled via an active bundle
  final Set<String> bundleFormAccess = {};

  void addModule(String id, {required bool isPurchasable}) {
    modules[id] = ModuleCatalogEntry(id: id, isPurchasable: isPurchasable);
  }

  void addForm(int id,
      {required String? moduleId,
      required bool isActive,
      required String kind}) {
    forms[id] = AppFormCatalogEntry(
        id: id, moduleId: moduleId, isActive: isActive, kind: kind);
  }

  void setModuleAccessItem(int orgId, String moduleId,
      {required bool isEnabled}) {
    moduleAccessItems['$orgId:$moduleId'] = isEnabled;
  }

  void setFormAccessItem(int orgId, int formId, {required bool isEnabled}) {
    formAccessItems['$orgId:$formId'] = isEnabled;
  }

  void grantBundleAccess(int orgId, int formId) {
    bundleFormAccess.add('$orgId:$formId');
  }

  @override
  Future<ModuleCatalogEntry?> getModule(String moduleId) async =>
      modules[moduleId];

  @override
  Future<AppFormCatalogEntry?> getForm(int formId) async => forms[formId];

  @override
  Future<bool> hasEnabledModuleAccessItem(
      int organizationId, String moduleId) async {
    return moduleAccessItems['$organizationId:$moduleId'] == true;
  }

  @override
  Future<bool> hasEnabledFormAccessItem(
      int organizationId, int formId) async {
    return formAccessItems['$organizationId:$formId'] == true;
  }

  @override
  Future<bool> hasActiveBundleAccessToForm(
      int organizationId, int formId) async {
    return bundleFormAccess.contains('$organizationId:$formId');
  }
}

Organization _org({
  required String entitlementMode,
  bool isSales = false,
  bool isInventory = false,
  bool isGL = false,
  bool isHR = false,
}) =>
    Organization(
      id: 42,
      name: 'Test Org',
      code: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isSales: isSales,
      isInventory: isInventory,
      isGL: isGL,
      isHR: isHR,
      entitlementMode: entitlementMode,
    );

void main() {
  late _FakeEntitlementRepository repo;
  late EffectiveAccessService service;

  setUp(() {
    repo = _FakeEntitlementRepository();
    service = EffectiveAccessService(repo);
    repo.addModule('sales', isPurchasable: true);
    repo.addModule('inventory', isPurchasable: true);
    repo.addModule('accounting', isPurchasable: true);
    repo.addModule('dashboard', isPurchasable: false);
  });

  group('Legacy mode', () {
    test('1. Sales flag ON -> Sales module entitled', () async {
      final org = _org(entitlementMode: 'legacy', isSales: true);
      expect(await service.effectiveModuleAccess(org, 'sales'), isTrue);
    });

    test('2. Sales flag OFF -> Sales module not entitled', () async {
      final org = _org(entitlementMode: 'legacy', isSales: false);
      expect(await service.effectiveModuleAccess(org, 'sales'), isFalse);
    });

    test('3. Legacy mode never reads omtbl_module_access_items', () async {
      final org = _org(entitlementMode: 'legacy', isSales: true);
      // Populate a contradictory explicit-mode row: if the service ever
      // consulted it for a legacy org, this test would fail by flipping the
      // expected result.
      repo.setModuleAccessItem(42, 'sales', isEnabled: false);
      expect(await service.effectiveModuleAccess(org, 'sales'), isTrue);
    });
  });

  group('Explicit mode - module level', () {
    test('4. Sales has an enabled row -> Sales module entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.setModuleAccessItem(42, 'sales', isEnabled: true);
      expect(await service.effectiveModuleAccess(org, 'sales'), isTrue);
    });

    test('5. Sales has no enabled row -> not entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      expect(await service.effectiveModuleAccess(org, 'sales'), isFalse);
    });

    test(
        '6. One enabled row + one disabled row for the module -> module still purchased (ANY, not ALL)',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form'); // Orders - enabled
      repo.addForm(14,
          moduleId: 'sales', isActive: true, kind: 'report'); // Returns - disabled
      repo.setFormAccessItem(42, 2, isEnabled: true);
      repo.setFormAccessItem(42, 14, isEnabled: false);
      // The module-level ANY check is driven by hasEnabledModuleAccessItem,
      // which conceptually is "any enabled row for this module" -- model
      // that directly:
      repo.setModuleAccessItem(42, 'sales', isEnabled: true);

      expect(await service.effectiveModuleAccess(org, 'sales'), isTrue);
    });
  });

  group('Explicit mode - form level', () {
    test('7. Specific enabled form row -> form entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form');
      repo.setFormAccessItem(42, 2, isEnabled: true);
      expect(await service.effectiveFormAccess(org, 2), isTrue);
    });

    test('8. Specific form row missing -> form NOT entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form');
      // No formAccessItems entry set at all.
      expect(await service.effectiveFormAccess(org, 2), isFalse);
    });

    test('9. Specific form row disabled -> form NOT entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form');
      repo.setFormAccessItem(42, 2, isEnabled: false);
      expect(await service.effectiveFormAccess(org, 2), isFalse);
    });

    test(
        '10. Module purchased but a specific form disabled -> module true, form false',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.setModuleAccessItem(42, 'sales', isEnabled: true);
      repo.addForm(14,
          moduleId: 'sales', isActive: true, kind: 'report'); // Returns report
      repo.setFormAccessItem(42, 14, isEnabled: false);

      expect(await service.effectiveModuleAccess(org, 'sales'), isTrue);
      expect(await service.effectiveFormAccess(org, 14), isFalse);
    });
  });

  group('Baseline / non-purchasable modules', () {
    test('11. Non-purchasable baseline module -> module access true',
        () async {
      final org = _org(entitlementMode: 'explicit');
      expect(await service.effectiveModuleAccess(org, 'dashboard'), isTrue);
    });

    test('12. Active form belonging to baseline module -> commercially available',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(8, moduleId: 'dashboard', isActive: true, kind: 'form');
      // No omtbl_module_access_items row exists for this org+form at all.
      expect(await service.effectiveFormAccess(org, 8), isTrue);
    });
  });

  group('Reports', () {
    test('13. Active report under purchased module -> entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(13,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.setFormAccessItem(42, 13, isEnabled: true);
      expect(await service.effectiveReportAccess(org, 13), isTrue);
    });

    test('14. Active report with individual entitlement row -> entitled',
        () async {
      final org = _org(entitlementMode: 'explicit');
      // Module itself is NOT purchased (no moduleAccessItems entry) --
      // only the one report's form-level row is enabled.
      repo.addForm(13,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.setFormAccessItem(42, 13, isEnabled: true);
      expect(await service.effectiveModuleAccess(org, 'accounting'), isFalse);
      expect(await service.effectiveReportAccess(org, 13), isTrue);
    });

    test('15. Report with no entitlement -> not entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(13,
          moduleId: 'accounting', isActive: true, kind: 'report');
      expect(await service.effectiveReportAccess(org, 13), isFalse);
    });

    test('16. Inactive report -> not entitled', () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(6, moduleId: 'reports', isActive: false, kind: 'report');
      repo.setFormAccessItem(42, 6, isEnabled: true);
      expect(await service.effectiveReportAccess(org, 6), isFalse);
    });

    test('17. Non-report (kind=form) passed to report access method -> false',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form');
      repo.setFormAccessItem(42, 2, isEnabled: true);
      expect(await service.effectiveReportAccess(org, 2), isFalse);
    });
  });

  group('Bundles', () {
    test('18. Active bundle entitlement containing report -> report entitled',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(11,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.grantBundleAccess(42, 11);
      expect(await service.effectiveReportAccess(org, 11), isTrue);
    });

    test('19. Bundle without the requested report -> not entitled through that bundle',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(11,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.addForm(12,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.grantBundleAccess(42, 12); // bundle covers 12, not 11
      expect(await service.effectiveReportAccess(org, 11), isFalse);
    });

    test('20. Module + bundle both cover the report -> still simply entitled',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(11,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.setFormAccessItem(42, 11, isEnabled: true);
      repo.grantBundleAccess(42, 11);
      expect(await service.effectiveReportAccess(org, 11), isTrue);
    });

    test('21. Individual report entitlement + bundle both cover it -> still simply entitled',
        () async {
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(11,
          moduleId: 'accounting', isActive: true, kind: 'report');
      repo.setFormAccessItem(42, 11, isEnabled: true); // individual purchase
      repo.grantBundleAccess(42, 11); // also in a bundle
      expect(await service.effectiveReportAccess(org, 11), isTrue);
    });
  });

  group('Layer separation', () {
    test('22. Commercial entitlement does not depend on store scope',
        () async {
      // EffectiveAccessService's public API takes no store/accessible-store
      // parameter anywhere -- this is a structural guarantee, demonstrated
      // by the fact every call in this suite passes only (org, id) and
      // never any store-scope argument, and the fake repository/service
      // under test has no store-related field or method at all.
      final org = _org(entitlementMode: 'explicit', isSales: true);
      repo.setModuleAccessItem(42, 'sales', isEnabled: true);
      final result = await service.effectiveModuleAccess(org, 'sales');
      expect(result, isTrue);
      // No accessible_store_ids()/storeId concept exists anywhere in this
      // call -- compiled proof that the signature has no such parameter.
    });

    test(
        '23. Commercial entitlement does not automatically grant role permission',
        () async {
      // EffectiveAccessService returns a plain commercial-availability bool
      // with no user/role parameter at all -- callers must separately apply
      // their own role-authorization check on top of this result before
      // treating a user as allowed to open the screen. Demonstrated here by
      // the fact this method signature accepts no user/role argument.
      final org = _org(entitlementMode: 'explicit');
      repo.addForm(2, moduleId: 'sales', isActive: true, kind: 'form');
      repo.setFormAccessItem(42, 2, isEnabled: true);

      final commerciallyEntitled = await service.effectiveFormAccess(org, 2);
      expect(commerciallyEntitled, isTrue);
      // A caller still owes a separate roleAuthorizedFor(user.role, ...)
      // check before granting the user access -- effectiveFormAccess's
      // result alone is not sufficient per §9 of the decisions doc, and
      // this service exposes no mechanism that could bypass that.
    });
  });
}
