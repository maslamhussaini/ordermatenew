// Focused demo-readiness check for the Customer -> Salesman assignment fix.
// Verifies manager_id survives: entity -> local repository write -> read-back,
// exactly the path getLocalPartners()/addPartner()/updatePartner() use in
// production. Not a broad regression suite by design (see conversation).
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const orgId = 97001;

  test('manager_id (Salesman assignment) survives addPartner -> read-back',
      () async {
    final repo = BusinessPartnerLocalRepository();

    final salesmanId = 'salesman-ahmed-97001';
    final customer = BusinessPartner(
      id: 'cust-manageridtest-97001',
      name: 'Manager Id Test Customer',
      phone: '111',
      address: 'test address',
      isCustomer: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      organizationId: orgId,
      storeId: 1,
      managerId: salesmanId,
    );

    await repo.addPartner(customer);

    final partners = await repo.getLocalPartners(
        isCustomer: true, organizationId: orgId);
    final fetched =
        partners.firstWhere((p) => p.id == 'cust-manageridtest-97001');

    expect(fetched.managerId, salesmanId,
        reason: 'manager_id must survive the local write/read round trip');

    // Update path: reassign to a different salesman, confirm it updates.
    final reassigned = customer.copyWith(managerId: 'salesman-bilal-97001');
    await repo.updatePartner(reassigned);

    final partnersAfterUpdate = await repo.getLocalPartners(
        isCustomer: true, organizationId: orgId);
    final fetchedAfterUpdate = partnersAfterUpdate
        .firstWhere((p) => p.id == 'cust-manageridtest-97001');

    expect(fetchedAfterUpdate.managerId, 'salesman-bilal-97001',
        reason: 'manager_id must be updatable via updatePartner');

    // Vendor backward-compatibility check: a Vendor record with no
    // managerId must remain unaffected (stays null, no crash).
    final vendor = BusinessPartner(
      id: 'vendor-manageridtest-97001',
      name: 'Manager Id Test Vendor',
      phone: '222',
      address: 'vendor address',
      isVendor: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      organizationId: orgId,
      storeId: 1,
      // managerId intentionally omitted (null) -- typical vendor record.
    );
    await repo.addPartner(vendor);
    final vendors = await repo.getLocalPartners(
        isVendor: true, organizationId: orgId);
    final fetchedVendor =
        vendors.firstWhere((p) => p.id == 'vendor-manageridtest-97001');
    expect(fetchedVendor.managerId, isNull,
        reason: 'Vendor records must remain unaffected (managerId stays null)');
  });
}
