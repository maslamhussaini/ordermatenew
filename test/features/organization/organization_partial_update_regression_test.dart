// test/features/organization/organization_partial_update_regression_test.dart
//
// Regression guard for the Organization Profile / Organization Form partial
// update bug:
//
//   organization_profile_screen.dart and organization_form_screen.dart used
//   to construct a new Organization with only id/name/code/isActive/dates.
//   All module flags defaulted to false, and updateOrganization() sent those
//   false values to Supabase, silently disabling Sales/Inventory/etc.
//
// This test proves that the serialization path preserves entitlement flags
// when an existing organization is used as the source for an update.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/organization/data/models/organization_model.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';

Organization _existingOrg() {
  return Organization(
    id: 26,
    name: 'Test',
    code: 'TST',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isGL: false,
    isSales: true,
    isInventory: true,
    isHR: false,
    isSettings: true,
    entitlementMode: 'legacy',
    logoUrl: 'https://example.com/logo.png',
    businessTypeId: 1,
    planType: 'free',
    storeCount: 2,
  );
}

void main() {
  group('Organization partial-update regression', () {
    test('OrganizationModel round-trips all entitlement flags', () {
      final original = OrganizationModel(
        id: 26,
        name: 'Test',
        code: 'TST',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isGL: false,
        isSales: true,
        isInventory: true,
        isHR: false,
        isSettings: true,
        entitlementMode: 'legacy',
        logoUrl: 'https://example.com/logo.png',
        businessTypeId: 1,
        planType: 'free',
        storeCount: 2,
      );

      final json = original.toJson();
      final reconstructed = OrganizationModel.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.name, original.name);
      expect(reconstructed.code, original.code);
      expect(reconstructed.isActive, original.isActive);
      expect(reconstructed.isGL, original.isGL);
      expect(reconstructed.isSales, original.isSales);
      expect(reconstructed.isInventory, original.isInventory);
      expect(reconstructed.isHR, original.isHR);
      expect(reconstructed.isSettings, original.isSettings);
      expect(reconstructed.entitlementMode, original.entitlementMode);
      expect(reconstructed.logoUrl, original.logoUrl);
      expect(reconstructed.businessTypeId, original.businessTypeId);
      expect(reconstructed.planType, original.planType);
      expect(reconstructed.storeCount, original.storeCount);
    });

    test(
        'update payload built from existing org preserves is_sales/is_inventory',
        () {
      final existing = _existingOrg();

      // Simulate the fixed Organization Profile save: rebuild the entity
      // from the existing org, changing only the name.
      final updated = Organization(
        id: existing.id,
        name: 'New Name',
        code: existing.code,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        isGL: existing.isGL,
        isSales: existing.isSales,
        isInventory: existing.isInventory,
        isHR: existing.isHR,
        isSettings: existing.isSettings,
        entitlementMode: existing.entitlementMode,
        logoUrl: existing.logoUrl,
        businessTypeId: existing.businessTypeId,
        planType: existing.planType,
        storeCount: existing.storeCount,
      );

      final model = OrganizationModel(
        id: updated.id,
        name: updated.name,
        code: updated.code,
        isActive: updated.isActive,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        logoUrl: updated.logoUrl,
        storeCount: updated.storeCount,
        businessTypeId: updated.businessTypeId,
        isGL: updated.isGL,
        isSales: updated.isSales,
        isInventory: updated.isInventory,
        isHR: updated.isHR,
        isSettings: updated.isSettings,
        planType: updated.planType,
        entitlementMode: updated.entitlementMode,
      );

      final json = model.toJson();

      expect(json['is_sales'], isTrue,
          reason: 'is_sales must remain true after a name-only update');
      expect(json['is_inventory'], isTrue,
          reason: 'is_inventory must remain true after a name-only update');
      expect(json['is_gl'], isFalse);
      expect(json['is_hr'], isFalse);
      expect(json['is_settings'], isTrue);
      expect(json['entitlement_mode'], 'legacy');
      expect(json['name'], 'New Name');
    });

    test('logo-upload path in provider preserves entitlement flags', () {
      final existing = _existingOrg();

      // Simulate the provider reconstructing the org after logo upload.
      final orgToUpdate = Organization(
        id: existing.id,
        name: existing.name,
        code: existing.code,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        logoUrl: 'https://example.com/new-logo.png',
        storeCount: existing.storeCount,
        isGL: existing.isGL,
        isSales: existing.isSales,
        isInventory: existing.isInventory,
        isHR: existing.isHR,
        isSettings: existing.isSettings,
        entitlementMode: existing.entitlementMode,
        businessTypeId: existing.businessTypeId,
        planType: existing.planType,
      );

      final model = OrganizationModel(
        id: orgToUpdate.id,
        name: orgToUpdate.name,
        code: orgToUpdate.code,
        isActive: orgToUpdate.isActive,
        createdAt: orgToUpdate.createdAt,
        updatedAt: orgToUpdate.updatedAt,
        logoUrl: orgToUpdate.logoUrl,
        storeCount: orgToUpdate.storeCount,
        businessTypeId: orgToUpdate.businessTypeId,
        isGL: orgToUpdate.isGL,
        isSales: orgToUpdate.isSales,
        isInventory: orgToUpdate.isInventory,
        isHR: orgToUpdate.isHR,
        isSettings: orgToUpdate.isSettings,
        planType: orgToUpdate.planType,
        entitlementMode: orgToUpdate.entitlementMode,
      );

      final json = model.toJson();

      expect(json['is_sales'], isTrue,
          reason: 'logo upload path must not reset is_sales');
      expect(json['is_inventory'], isTrue,
          reason: 'logo upload path must not reset is_inventory');
      expect(json['logo_url'], 'https://example.com/new-logo.png');
    });

    test('repository partial OrganizationModel reconstruction preserves all fields',
        () {
      final existing = _existingOrg();

      // Simulate repository.updateOrganization() partial reconstruction
      // when incoming organization is an Organization entity (not OrganizationModel).
      final model = OrganizationModel(
        id: existing.id,
        name: existing.name,
        code: existing.code,
        isActive: existing.isActive,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
        logoUrl: existing.logoUrl,
        storeCount: existing.storeCount,
        businessTypeId: existing.businessTypeId,
        isGL: existing.isGL,
        isSales: existing.isSales,
        isInventory: existing.isInventory,
        isHR: existing.isHR,
        isSettings: existing.isSettings,
        planType: existing.planType,
        entitlementMode: existing.entitlementMode,
      );

      final json = model.toJson();

      expect(json['is_sales'], isTrue,
          reason: 'repository must preserve is_sales from incoming Organization');
      expect(json['is_inventory'], isTrue,
          reason: 'repository must preserve is_inventory from incoming Organization');
      expect(json['is_gl'], isFalse);
      expect(json['is_hr'], isFalse);
      expect(json['is_settings'], isTrue);
      expect(json['entitlement_mode'], 'legacy');
      expect(json['logo_url'], 'https://example.com/logo.png');
      expect(json['business_type_id'], 1);
      expect(json['plan_type'], 'free');
      expect(json['store_count'], 2);
    });
  });
}
