import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ordermate/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/screens/product_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/vendors/domain/repositories/vendor_repository.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

class TestOrganizationNotifier extends OrganizationNotifier {
  TestOrganizationNotifier(
      super.repo, super.ref, OrganizationState initialState) {
    state = initialState;
  }
  @override
  Future<void> loadOrganizations() async {}
}

class TestInventoryNotifier extends InventoryNotifier {
  TestInventoryNotifier(super.repo, super.ref, InventoryState initialState) {
    state = initialState;
  }
  @override
  Future<void> loadBrands() async {}
  @override
  Future<void> loadCategories() async {}
  @override
  Future<void> loadProductTypes() async {}
  @override
  Future<void> loadUnitsOfMeasure() async {}
  @override
  Future<void> loadAll() async {}
}

class TestVendorNotifier extends VendorNotifier {
  TestVendorNotifier(super.ref, super.repo, VendorState initialState) {
    state = initialState;
  }
  @override
  Future<void> loadVendors() async {}
  @override
  Future<void> loadSuppliers() async {}
}

class TestAccountingNotifier extends AccountingNotifier {
  TestAccountingNotifier(super.repo, super.ref, AccountingState initialState) {
    state = initialState;
  }
  @override
  Future<void> loadAll({int? organizationId}) async {}
  @override
  Future<void> loadGLSetup({int? organizationId}) async {}
}

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

class MockInventoryRepository extends Mock implements InventoryRepository {}

class MockVendorRepository extends Mock implements VendorRepository {}

class MockAccountingRepository extends Mock implements AccountingRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class FakeProduct extends Fake implements Product {}

void main() {
  late MockProductRepository mockProductRepository;
  late MockOrganizationRepository mockOrganizationRepository;
  late MockInventoryRepository mockInventoryRepository;
  late MockVendorRepository mockVendorRepository;
  late MockAccountingRepository mockAccountingRepository;

  setUpAll(() {
    registerFallbackValue(FakeProduct());
  });

  setUp(() {
    mockProductRepository = MockProductRepository();
    mockOrganizationRepository = MockOrganizationRepository();
    mockInventoryRepository = MockInventoryRepository();
    mockVendorRepository = MockVendorRepository();
    mockAccountingRepository = MockAccountingRepository();

    when(() => mockProductRepository.createProduct(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first as Product);
  });

  testWidgets('Product Form Validation Logic Test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime.now();

    final orgState = OrganizationState(
      selectedOrganization: Organization(
          id: 1, name: 'Org', code: 'O', createdAt: now, updatedAt: now),
    );

    final invState = InventoryState(
      brands: [
        Brand(
            id: 1, name: 'BrandA', status: 1, organizationId: 1, createdAt: now)
      ],
      categories: [
        ProductCategory(
            id: 1, name: 'CatA', status: 1, organizationId: 1, createdAt: now)
      ],
      productTypes: [
        ProductType(
            id: 1, name: 'TypeA', status: 1, organizationId: 1, createdAt: now)
      ],
      unitsOfMeasure: [
        UnitOfMeasure(
            id: 1,
            name: 'UnitA',
            symbol: 'u',
            type: 'count',
            isDecimalAllowed: true,
            organizationId: 1,
            createdAt: now,
            updatedAt: now)
      ],
    );

    const venState = VendorState();

    final accState = AccountingState(
      accounts: [
        ChartOfAccount(
            id: 'acc1',
            accountCode: '1000',
            accountTitle: 'Inventory',
            organizationId: 1,
            level: 3,
            accountCategoryId: 1,
            isActive: true,
            createdAt: now,
            updatedAt: now),
        ChartOfAccount(
            id: 'acc2',
            accountCode: '5000',
            accountTitle: 'COGS',
            organizationId: 1,
            level: 3,
            accountCategoryId: 2,
            isActive: true,
            createdAt: now,
            updatedAt: now),
        ChartOfAccount(
            id: 'acc3',
            accountCode: '4000',
            accountTitle: 'Sales',
            organizationId: 1,
            level: 3,
            accountCategoryId: 3,
            isActive: true,
            createdAt: now,
            updatedAt: now),
        ChartOfAccount(
            id: 'acc4',
            accountCode: '4100',
            accountTitle: 'Discounts',
            organizationId: 1,
            level: 3,
            accountCategoryId: 4,
            isActive: true,
            createdAt: now,
            updatedAt: now),
      ],
      categories: [
        const AccountCategory(
            id: 1,
            categoryName: 'BasicInventory',
            accountTypeId: 1,
            organizationId: 1),
        const AccountCategory(
            id: 2,
            categoryName: 'BasicCOGS',
            accountTypeId: 1,
            organizationId: 1),
        const AccountCategory(
            id: 3,
            categoryName: 'BasicRevenue',
            accountTypeId: 1,
            organizationId: 1),
        const AccountCategory(
            id: 4,
            categoryName: 'Discount',
            accountTypeId: 1,
            organizationId: 1),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organizationProvider.overrideWith((ref) => TestOrganizationNotifier(
              mockOrganizationRepository, ref, orgState)),
          inventoryProvider.overrideWith((ref) =>
              TestInventoryNotifier(mockInventoryRepository, ref, invState)),
          vendorProvider.overrideWith(
              (ref) => TestVendorNotifier(ref, mockVendorRepository, venState)),
          accountingProvider.overrideWith((ref) =>
              TestAccountingNotifier(mockAccountingRepository, ref, accState)),
          productRepositoryProvider.overrideWithValue(mockProductRepository),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Form), findsOneWidget);

    // Helper to find and tap a LookupField by its label text
    Future<void> tapLookup(String label) async {
      final lookup = find
          .ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
                (w) => w.runtimeType.toString().contains('LookupField')),
          )
          .first;
      expect(lookup, findsOneWidget,
          reason: 'Could not find LookupField with label: $label');
      await tester.tap(
          find.descendant(of: lookup, matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
    }

    // Enter name
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Name'), 'ProductA');

    // Enter SKU
    await tester.enterText(find.widgetWithText(TextFormField, 'SKU'), 'SKU-A');

    // Enter Base Qty
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Base Qty'), '1.0');

    // Enter Pricing
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cost Price'), '80');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Sales Price'), '100');

    // Select Type
    await tapLookup('Product Type *');
    await tester.tap(find.text('TypeA').last);
    await tester.pumpAndSettle();

    // Select Category
    await tapLookup('Category *');
    await tester.tap(find.text('CatA').last);
    await tester.pumpAndSettle();

    // Select Brand
    await tapLookup('Brand *');
    await tester.tap(find.text('BrandA').last);
    await tester.pumpAndSettle();

    // Select UOM
    await tapLookup('Base Unit');
    await tester.tap(find.text('UnitA (u)').last);
    await tester.pumpAndSettle();

    // Accounts
    await tapLookup('Inventory Asset Account');
    await tester.tap(find.text('1000 - Inventory').last);
    await tester.pumpAndSettle();

    await tapLookup('COGS Account');
    await tester.tap(find.text('5000 - COGS').last);
    await tester.pumpAndSettle();

    await tapLookup('Revenue/Sales Account');
    await tester.tap(find.text('4000 - Sales').last);
    await tester.pumpAndSettle();

    await tapLookup('Sales Discount Account');
    await tester.tap(find.text('4100 - Discounts').last);
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    // Verify Repository Call (This confirms the form validated and submitted correctly)
    verify(() => mockProductRepository.createProduct(any())).called(1);
  });
}
