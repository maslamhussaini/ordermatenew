// test/features/inventory/add_unit_of_measure_by_name_test.dart
//
// Phase QA P0.2: Unit of Measure was the one required Product-form lookup
// (Product Type/Category/Brand already had it) missing the inline
// "+ Create New" wiring, because the existing addUnitOfMeasure(UnitOfMeasure)
// provider method needs a full entity (symbol/type/isDecimalAllowed) while
// LookupField.onAdd only ever supplies a single name string -- the same
// shape addBrand/addCategory/addProductType already accept.
//
// addUnitOfMeasureByName(String) is the new thin wrapper closing that gap.
// This suite proves it builds a valid UnitOfMeasure (symbol defaulting to
// the typed name) and correctly attaches the CURRENTLY SELECTED
// organization's id -- not a hardcoded or missing one -- via a fake
// repository and a real (test-seeded) organizationProvider state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class _NoopOrganizationRepository implements OrganizationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Not stubbed for this test: ${invocation.memberName}');
}

class TestOrganizationNotifier extends OrganizationNotifier {
  TestOrganizationNotifier(super.repo, super.ref, OrganizationState initialState) {
    state = initialState;
  }

  @override
  Future<void> loadOrganizations() async {}
}

class FakeInventoryRepository implements InventoryRepository {
  final List<UnitOfMeasure> uoms = [];
  int? lastCreateOrgId;

  @override
  Future<UnitOfMeasure> createUnitOfMeasure(UnitOfMeasure uom) async {
    lastCreateOrgId = uom.organizationId;
    final created = UnitOfMeasure(
      id: uoms.length + 1,
      name: uom.name,
      symbol: uom.symbol,
      type: uom.type,
      isDecimalAllowed: uom.isDecimalAllowed,
      organizationId: uom.organizationId,
    );
    uoms.add(created);
    return created;
  }

  @override
  Future<List<UnitOfMeasure>> getUnitsOfMeasure({int? organizationId}) async {
    return uoms;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Not stubbed for this test: ${invocation.memberName}');
}

void main() {
  test('addUnitOfMeasureByName creates a UOM with symbol defaulted to the typed name, scoped to the selected org', () async {
    final now = DateTime.now();
    final org = Organization(
        id: 77, name: 'QA Org', code: null, createdAt: now, updatedAt: now);
    final orgState = OrganizationState(
      isInitialized: true,
      organizations: [org],
      selectedOrganization: org,
    );

    final fakeRepo = FakeInventoryRepository();

    final container = ProviderContainer(overrides: [
      organizationProvider.overrideWith(
          (ref) => TestOrganizationNotifier(_NoopOrganizationRepository(), ref, orgState)),
      inventoryRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(inventoryProvider.notifier);
    await notifier.addUnitOfMeasureByName('Pcs');

    expect(fakeRepo.uoms, hasLength(1));
    expect(fakeRepo.uoms.first.name, 'Pcs');
    expect(fakeRepo.uoms.first.symbol, 'Pcs');
    expect(fakeRepo.lastCreateOrgId, 77,
        reason: 'must attach the currently selected organization, never a '
            'hardcoded or missing id -- this is the exact organization-'
            'ownership requirement from the Phase QA P0.2 authorization');

    final state = container.read(inventoryProvider);
    expect(state.unitsOfMeasure.map((u) => u.name), contains('Pcs'));
  });

  test('does not create cross-organization records: a second org gets its own row, scoped separately', () async {
    final now = DateTime.now();
    final orgA = Organization(
        id: 1, name: 'Org A', code: null, createdAt: now, updatedAt: now);
    final orgB = Organization(
        id: 2, name: 'Org B', code: null, createdAt: now, updatedAt: now);

    final fakeRepo = FakeInventoryRepository();

    final containerA = ProviderContainer(overrides: [
      organizationProvider.overrideWith((ref) => TestOrganizationNotifier(
          _NoopOrganizationRepository(),
          ref,
          OrganizationState(selectedOrganization: orgA, organizations: [orgA]))),
      inventoryRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(containerA.dispose);
    await containerA.read(inventoryProvider.notifier).addUnitOfMeasureByName('Box');
    expect(fakeRepo.lastCreateOrgId, 1);

    final containerB = ProviderContainer(overrides: [
      organizationProvider.overrideWith((ref) => TestOrganizationNotifier(
          _NoopOrganizationRepository(),
          ref,
          OrganizationState(selectedOrganization: orgB, organizations: [orgB]))),
      inventoryRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    addTearDown(containerB.dispose);
    await containerB.read(inventoryProvider.notifier).addUnitOfMeasureByName('Box');
    expect(fakeRepo.lastCreateOrgId, 2);
  });
}
