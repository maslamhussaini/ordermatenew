// test/features/organization/organization_module_access_test.dart
//
// Covers Organization.isModuleEnabled (Phase 2A), the single shared source
// of truth used by AppMenu (menu visibility), the router's redirect guard
// (route access), and PrivilegeManagementScreen (form/privilege listing) to
// decide whether a module is enabled/purchased for an organization.
//
// Proves the six Phase 2A acceptance scenarios at the logic level:
//   1. Org with Sales enabled -> Sales-mapped modules visible
//   2. Org with Inventory disabled -> Inventory-mapped modules not visible
//   3. Disabled modules are excluded consistently across every module key
//      that maps to them (route-vocabulary and app_forms.module_name
//      vocabulary alike)
//   4. An "all modules enabled" org (the demo-org shape) sees everything
//   5. Baseline/administrative and unrecognized module keys are never
//      hidden by this logic (fail-open), so it can't regress existing
//      role/store/form-privilege screens that don't map to a module
//   6. Two organizations with different entitlement never affect each
//      other -- this helper is a pure function of the Organization
//      instance it's called on, so cross-tenant isolation is structural,
//      not incidental

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';

Organization _org({
  bool isGL = false,
  bool isSales = false,
  bool isInventory = false,
  bool isHR = false,
}) =>
    Organization(
      id: 1,
      name: 'Test Org',
      code: null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isGL: isGL,
      isSales: isSales,
      isInventory: isInventory,
      isHR: isHR,
    );

void main() {
  group('Organization.isModuleEnabled', () {
    test('Sales enabled -> Sales-mapped module keys are visible (Scenario 1)', () {
      final org = _org(isSales: true);
      for (final key in ['orders', 'invoices', 'sales', 'customers', 'crm']) {
        expect(org.isModuleEnabled(key), isTrue, reason: 'key: $key');
      }
    });

    test('Inventory disabled -> Inventory-mapped module keys are hidden (Scenario 2)', () {
      final org = _org(isSales: true, isInventory: false);
      for (final key in [
        'products',
        'inventory',
        'vendors',
        'suppliers',
        'purchasing'
      ]) {
        expect(org.isModuleEnabled(key), isFalse, reason: 'key: $key');
      }
      // Sales stays independently visible -- module entitlements don't leak
      // into each other.
      expect(org.isModuleEnabled('orders'), isTrue);
    });

    test(
        'disabled modules excluded consistently across both route and '
        'app_forms.module_name vocabularies (Scenario 3)', () {
      final org = _org(isGL: false, isSales: false, isInventory: false, isHR: false);
      const disabled = [
        'accounting', 'gl', // GL
        'orders', 'invoices', 'sales', 'customers', 'crm', // Sales
        'products', 'inventory', 'vendors', 'suppliers', 'purchasing', // Inventory
        'employees', 'hr', // HR
      ];
      for (final key in disabled) {
        expect(org.isModuleEnabled(key), isFalse, reason: 'key: $key');
      }
    });

    test('all modules enabled (demo-org shape) sees everything (Scenario 4)', () {
      final org = _org(isGL: true, isSales: true, isInventory: true, isHR: true);
      const allKeys = [
        'accounting', 'orders', 'invoices', 'products', 'inventory',
        'vendors', 'customers', 'employees',
        // baseline/unmapped keys must also remain visible
        'dashboard', 'stores', 'settings', 'organization', 'reports',
      ];
      for (final key in allKeys) {
        expect(org.isModuleEnabled(key), isTrue, reason: 'key: $key');
      }
    });

    test(
        'baseline/administrative and unrecognized module keys fail open, '
        'even on an org with every entitlement off (Scenario 5)', () {
      final org = _org(); // everything false
      for (final key in [
        'dashboard',
        'stores',
        'settings',
        'organization',
        'reports',
        'admin',
        'users',
        null,
        'some_future_module_nobody_mapped_yet',
      ]) {
        expect(org.isModuleEnabled(key), isTrue, reason: 'key: $key');
      }
    });

    test(
        'is a pure function of the organization instance -- two orgs with '
        'different entitlement never affect each other (Scenario 6)', () {
      final orgA = _org(isSales: true, isInventory: false);
      final orgB = _org(isSales: false, isInventory: true);

      expect(orgA.isModuleEnabled('orders'), isTrue);
      expect(orgA.isModuleEnabled('inventory'), isFalse);

      expect(orgB.isModuleEnabled('orders'), isFalse);
      expect(orgB.isModuleEnabled('inventory'), isTrue);

      // Re-checking orgA after evaluating orgB proves no shared/static state.
      expect(orgA.isModuleEnabled('orders'), isTrue);
      expect(orgA.isModuleEnabled('inventory'), isFalse);
    });
  });
}
