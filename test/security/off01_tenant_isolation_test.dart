// test/security/off01_tenant_isolation_test.dart
//
// OFF-01 P0 security fix regression suite. Exercises the ACTUAL repository
// methods that previously leaked cross-organization data offline (not just
// low-level SQL helpers) against a real SQLite database (sqflite_common_ffi,
// same pattern as test/offline_capability_test.dart) -- proving the fix at
// the exact layer the vulnerability lived in.
//
// Uses high, test-reserved organization ids (90001/90002) to avoid
// colliding with other test files' fixture data in the shared
// DatabaseHelper singleton.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/products/data/repositories/product_local_repository.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/accounting/data/models/accounting_models.dart';
import 'package:ordermate/features/inventory/data/repositories/inventory_local_repository.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const orgA = 90001;
const orgB = 90002;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Test A -- Business Partner cross-org isolation', () {
    test('org A query returns only org A customers, never org B', () async {
      final repo = BusinessPartnerLocalRepository();

      await repo.addPartner(BusinessPartner(
        id: 'off01-bp-a',
        name: 'Customer A',
        phone: '1',
        email: 'a@test.com',
        address: 'addr',
        isCustomer: true,
        isVendor: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: orgA,
        storeId: 1,
      ));
      await repo.addPartner(BusinessPartner(
        id: 'off01-bp-b',
        name: 'Customer B',
        phone: '2',
        email: 'b@test.com',
        address: 'addr',
        isCustomer: true,
        isVendor: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: orgB,
        storeId: 2,
      ));

      // Exercise the ACTUAL method the vulnerability lived in.
      final result = await repo.getLocalPartners(
          isCustomer: true, organizationId: orgA);

      expect(result.any((p) => p.id == 'off01-bp-a'), isTrue);
      expect(result.any((p) => p.id == 'off01-bp-b'), isFalse,
          reason: 'org B customer must never appear in an org A query');
    });
  });

  group('Test B -- Product cross-org isolation', () {
    test('org A query returns only org A products, never org B', () async {
      final repo = ProductLocalRepository();

      await repo.cacheProducts([
        Product(
          id: 'off01-prod-a',
          name: 'Product A',
          sku: 'SKU-A',
          rate: 10,
          cost: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          organizationId: orgA,
          storeId: 1,
        ),
        Product(
          id: 'off01-prod-b',
          name: 'Product B',
          sku: 'SKU-B',
          rate: 20,
          cost: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          organizationId: orgB,
          storeId: 2,
        ),
      ]);

      final result = await repo.getLocalProducts(organizationId: orgA);

      expect(result.any((p) => p.id == 'off01-prod-a'), isTrue);
      expect(result.any((p) => p.id == 'off01-prod-b'), isFalse,
          reason: 'org B product must never appear in an org A query');
    });
  });

  group('Test C -- Orders cross-org isolation', () {
    test('org A query returns only org A orders, never org B', () async {
      final repo = OrderLocalRepository();

      await repo.addOrder(Order(
        id: 'off01-ord-a',
        orderNumber: 'A-1',
        businessPartnerId: 'off01-bp-a',
        orderType: 'SO',
        createdBy: 'tester',
        status: OrderStatus.approved,
        totalAmount: 100,
        orderDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: orgA,
        storeId: 1,
      ));
      await repo.addOrder(Order(
        id: 'off01-ord-b',
        orderNumber: 'B-1',
        businessPartnerId: 'off01-bp-b',
        orderType: 'SO',
        createdBy: 'tester',
        status: OrderStatus.approved,
        totalAmount: 200,
        orderDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: orgB,
        storeId: 2,
      ));

      final result = await repo.getLocalOrders(organizationId: orgA);

      expect(result.any((o) => o.id == 'off01-ord-a'), isTrue);
      expect(result.any((o) => o.id == 'off01-ord-b'), isFalse,
          reason: 'org B order must never appear in an org A query');
    });
  });

  group('Test D -- Accounting isolation (representative entities)', () {
    test('Chart of Accounts: org A query excludes org B', () async {
      final repo = LocalAccountingRepository();
      await repo.saveChartOfAccount(
        ChartOfAccountModel(
          id: 'off01-coa-a',
          accountCode: 'A-1000',
          accountTitle: 'Cash A',
          level: 1,
          organizationId: orgA,
          isActive: true,
          isSystem: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        isSynced: true,
      );
      await repo.saveChartOfAccount(
        ChartOfAccountModel(
          id: 'off01-coa-b',
          accountCode: 'B-1000',
          accountTitle: 'Cash B',
          level: 1,
          organizationId: orgB,
          isActive: true,
          isSystem: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        isSynced: true,
      );

      final result = await repo.getChartOfAccounts(organizationId: orgA);
      expect(result.any((a) => a.id == 'off01-coa-a'), isTrue);
      expect(result.any((a) => a.id == 'off01-coa-b'), isFalse);
    });

    test('Invoice Types: org A query excludes org B', () async {
      final repo = LocalAccountingRepository();
      await repo.saveInvoiceType(
        const InvoiceTypeModel(
            idInvoiceType: 'OFF01A',
            description: 'A',
            forUsed: 'A',
            organizationId: orgA,
            isActive: true),
        isSynced: true,
      );
      await repo.saveInvoiceType(
        const InvoiceTypeModel(
            idInvoiceType: 'OFF01B',
            description: 'B',
            forUsed: 'B',
            organizationId: orgB,
            isActive: true),
        isSynced: true,
      );

      final result = await repo.getInvoiceTypes(organizationId: orgA);
      expect(result.any((t) => t.idInvoiceType == 'OFF01A'), isTrue);
      expect(result.any((t) => t.idInvoiceType == 'OFF01B'), isFalse);
    });

    test('Voucher Prefixes: org A query excludes org B', () async {
      final repo = LocalAccountingRepository();
      await repo.saveVoucherPrefix(
        const VoucherPrefixModel(
            id: 0,
            prefixCode: 'OFF01PA',
            voucherType: 'Receipt',
            organizationId: orgA,
            status: true),
        isSynced: true,
      );
      await repo.saveVoucherPrefix(
        const VoucherPrefixModel(
            id: 0,
            prefixCode: 'OFF01PB',
            voucherType: 'Receipt',
            organizationId: orgB,
            status: true),
        isSynced: true,
      );

      final result = await repo.getVoucherPrefixes(organizationId: orgA);
      expect(result.any((p) => p.prefixCode == 'OFF01PA'), isTrue);
      expect(result.any((p) => p.prefixCode == 'OFF01PB'), isFalse);
    });
  });

  group('Test E -- Inventory isolation (representative master data)', () {
    test('Brands: org A query excludes org B', () async {
      final repo = InventoryLocalRepository();
      final idA = await repo.saveBrand(
        Brand(id: 0, name: 'OFF01-Brand-A', status: 1, organizationId: orgA, createdAt: DateTime.now()),
        isSynced: true,
      );
      final idB = await repo.saveBrand(
        Brand(id: 0, name: 'OFF01-Brand-B', status: 1, organizationId: orgB, createdAt: DateTime.now()),
        isSynced: true,
      );

      final result = await repo.getLocalBrands(organizationId: orgA);
      expect(result.any((b) => b.id == idA), isTrue);
      expect(result.any((b) => b.id == idB), isFalse,
          reason: 'org B brand must never appear in an org A query');
    });
  });

  group('Test F -- NULL organization safety', () {
    test('a row with organization_id = NULL is never returned for org A',
        () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'local_businesspartners',
        {
          'id': 'off01-null-org',
          'name': 'Null Org Partner',
          'phone': '0',
          'email': '',
          'address': '',
          'is_customer': 1,
          'is_vendor': 0,
          'is_employee': 0,
          'is_active': 1,
          'is_synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          // organization_id intentionally omitted -> NULL
        },
        // The shared DatabaseHelper singleton persists to a real file
        // across test runs (not just within one run) -- replace, don't
        // fail, on a re-run with the same fixture id.
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final repo = BusinessPartnerLocalRepository();
      final result = await repo.getLocalPartners(
          isCustomer: true, organizationId: orgA);

      expect(result.any((p) => p.id == 'off01-null-org'), isFalse,
          reason: 'NULL organization_id must not act as a wildcard match');
    });
  });

  group('Test G -- organization_id = 0 safety', () {
    test('a row with organization_id = 0 is never returned for org A',
        () async {
      final repo = InventoryLocalRepository();
      final zeroId = await repo.saveBrand(
        Brand(id: 0, name: 'OFF01-Brand-Zero', status: 1, organizationId: 0, createdAt: DateTime.now()),
        isSynced: true,
      );

      final result = await repo.getLocalBrands(organizationId: orgA);
      expect(result.any((b) => b.id == zeroId), isFalse,
          reason: 'organization_id = 0 must not act as a wildcard match '
              '(this was the most permissive pre-fix pattern found)');
    });
  });

  group('Test H -- Store filter does not weaken tenant filter', () {
    test('org A / store X vs org B / store Y: org A store-scoped query never returns org B data',
        () async {
      final repo = ProductLocalRepository();
      const storeX = 90101;
      const storeY = 90102;

      await repo.cacheProducts([
        Product(
          id: 'off01-store-a',
          name: 'Store A Product',
          sku: 'SX-1',
          rate: 10,
          cost: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          organizationId: orgA,
          storeId: storeX,
        ),
        Product(
          id: 'off01-store-b',
          name: 'Store B Product',
          sku: 'SY-1',
          rate: 10,
          cost: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          organizationId: orgB,
          storeId: storeY,
        ),
      ]);

      // Even without supplying storeId, org filtering alone must exclude
      // org B. This is the core assertion: store filtering is never relied
      // upon as the tenant boundary.
      final result =
          await repo.getLocalProducts(organizationId: orgA);
      expect(result.any((p) => p.id == 'off01-store-b'), isFalse);

      // And even if a caller also supplies a store filter, an org-B-only
      // store id must never leak org B data into an org-A-scoped query.
      final resultWithStore = await repo.getLocalProducts(
          organizationId: orgA, storeId: storeY);
      expect(resultWithStore.any((p) => p.id == 'off01-store-b'), isFalse,
          reason: 'organization filtering must apply even when a store '
              'filter belonging to a different organization is supplied');
    });
  });

  group('Missing tenant context fails safe (not open)', () {
    test('getLocalPartners(organizationId: null) returns empty, not everything',
        () async {
      final repo = BusinessPartnerLocalRepository();
      // Seed at least one row so an unfiltered query would NOT be empty --
      // proving the empty result below is the null-guard, not coincidence.
      await repo.addPartner(BusinessPartner(
        id: 'off01-safety-seed',
        name: 'Safety Seed',
        phone: '1',
        email: 'x@test.com',
        address: 'addr',
        isCustomer: true,
        isVendor: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: orgA,
        storeId: 1,
      ));

      final result =
          await repo.getLocalPartners(isCustomer: true, organizationId: null);
      expect(result, isEmpty,
          reason: 'no tenant context must mean no tenant-scoped data, '
              'never an unfiltered read');
    });

    test('getLocalProducts(organizationId: null) returns empty, not everything',
        () async {
      final result =
          await ProductLocalRepository().getLocalProducts(organizationId: null);
      expect(result, isEmpty);
    });

    test('getLocalOrders(organizationId: null) returns empty, not everything',
        () async {
      final result =
          await OrderLocalRepository().getLocalOrders(organizationId: null);
      expect(result, isEmpty);
    });
  });
}
