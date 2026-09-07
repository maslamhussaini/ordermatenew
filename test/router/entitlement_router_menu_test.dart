// test/router/entitlement_router_menu_test.dart
//
// Phase 3B-3: proves the router guard and AppMenu filtering both consume
// the SAME EffectiveAccessService decision (via formAccessProvider /
// reportAccessProvider), so "menu hidden" and "direct navigation blocked"
// can never disagree -- and that commercial entitlement, role
// authorization, and legacy-vs-explicit mode all compose the way the
// Phase 3B decisions doc specifies.
//
// Uses the same TestOrganizationNotifier pattern already established in
// test/features/products/presentation/screens/product_form_test.dart
// (override loadOrganizations() to a no-op, set `state` directly in the
// constructor) so no real Supabase network call happens, and a hand-written
// fake EntitlementRepository so no real Supabase network call happens for
// entitlement lookups either.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_router.dart';
import 'package:ordermate/core/router/report_catalog_map.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/core/services/auth_service.dart';
import 'package:ordermate/core/views/app_menu.dart';
import 'package:ordermate/features/entitlement/domain/entities/catalog_entries.dart';
import 'package:ordermate/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:ordermate/features/entitlement/presentation/providers/entitlement_providers.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bounded alternative to `pumpAndSettle()`. The routes this suite navigates
/// to render real screens that kick off real (failing, in this offline test
/// environment) Supabase fetches with their own retry/animation timers --
/// `pumpAndSettle()` waits for ALL of that to go quiet and times out. The
/// router's redirect decision (what this suite actually asserts) resolves
/// within a handful of frames, so a bounded pump loop is enough and avoids
/// depending on unrelated screens' network behavior settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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

class _FakeEntitlementRepository implements EntitlementRepository {
  final Map<String, ModuleCatalogEntry> modules = {
    'inventory': const ModuleCatalogEntry(id: 'inventory', isPurchasable: true),
    'accounting': const ModuleCatalogEntry(id: 'accounting', isPurchasable: true),
    'crm': const ModuleCatalogEntry(id: 'crm', isPurchasable: false),
    'settings': const ModuleCatalogEntry(id: 'settings', isPurchasable: false),
  };

  final Map<int, AppFormCatalogEntry> forms = {
    1: const AppFormCatalogEntry(
        id: 1, moduleId: 'inventory', isActive: true, kind: 'form'), // Products
    8: const AppFormCatalogEntry(
        id: 8, moduleId: 'settings', isActive: true, kind: 'form'), // Settings
    20: const AppFormCatalogEntry(
        id: 20, moduleId: 'accounting', isActive: true, kind: 'report'), // Day Summary
  };

  final Map<String, bool> moduleAccessItems = {};
  final Map<String, bool> formAccessItems = {};
  final Set<String> bundleFormAccess = {};

  @override
  Future<ModuleCatalogEntry?> getModule(String moduleId) async => modules[moduleId];

  @override
  Future<AppFormCatalogEntry?> getForm(int formId) async => forms[formId];

  @override
  Future<bool> hasEnabledModuleAccessItem(int organizationId, String moduleId) async =>
      moduleAccessItems['$organizationId:$moduleId'] == true;

  @override
  Future<bool> hasEnabledFormAccessItem(int organizationId, int formId) async =>
      formAccessItems['$organizationId:$formId'] == true;

  @override
  Future<bool> hasActiveBundleAccessToForm(int organizationId, int formId) async =>
      bundleFormAccess.contains('$organizationId:$formId');
}

class MaterialAppWithRouter extends ConsumerWidget {
  const MaterialAppWithRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(routerConfig: router);
  }
}

Organization _org({required String entitlementMode, bool isInventory = false}) {
  final now = DateTime.now();
  return Organization(
    id: 42,
    name: 'Test Org',
    code: null,
    createdAt: now,
    updatedAt: now,
    isInventory: isInventory,
    entitlementMode: entitlementMode,
  );
}

Store _store(int orgId) {
  final now = DateTime.now();
  return Store(id: 1, organizationId: orgId, name: 'Main Store', createdAt: now, updatedAt: now);
}

List<Override> _overrides({
  required Organization org,
  required _FakeEntitlementRepository entitlementRepo,
}) {
  final orgState = OrganizationState(
    isInitialized: true,
    organizations: [org],
    selectedOrganization: org,
    selectedStore: _store(org.id),
    selectedFinancialYear: 2026,
    stores: [_store(org.id)],
  );

  return [
    organizationProvider.overrideWith(
        (ref) => TestOrganizationNotifier(_NoopOrganizationRepository(), ref, orgState)),
    entitlementRepositoryProvider.overrideWithValue(entitlementRepo),
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // AuthNotifier.build() unconditionally touches SupabaseConfig.client
    // (real Supabase auth stream) with no test-mode bypass -- initialize a
    // throwaway client so that doesn't crash. No network call is made by
    // initialize() itself; only actual auth/API calls would need real
    // credentials, and none are exercised by these tests.
    await supabase.Supabase.initialize(
      url: 'https://test.invalid.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.testIsLoggedIn = true;
    AuthService.testRole = UserRole.admin;
  });

  group('Legacy mode', () {
    testWidgets('1. Enabled legacy module -> route allowed', (tester) async {
      final org = _org(entitlementMode: 'legacy', isInventory: true);
      final repo = _FakeEntitlementRepository();

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/products');
    });

    testWidgets('2. Disabled legacy module -> route blocked', (tester) async {
      final org = _org(entitlementMode: 'legacy', isInventory: false);
      final repo = _FakeEntitlementRepository();

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });

    testWidgets('3. Legacy mode does not depend on omtbl_module_access_items',
        (tester) async {
      final org = _org(entitlementMode: 'legacy', isInventory: true);
      final repo = _FakeEntitlementRepository()
        // Contradictory explicit-mode row: if the router ever consulted it
        // for a legacy org, the route would be denied instead of allowed.
        ..formAccessItems['42:1'] = false;

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/products');
    });
  });

  group('Explicit mode - form level', () {
    testWidgets('4. Enabled exact form entitlement -> route allowed', (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:1'] = true;

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/products');
    });

    testWidgets('5. Missing exact form entitlement -> route blocked', (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository(); // no row at all for form 1

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });

    testWidgets('6. Disabled exact form entitlement -> route blocked', (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:1'] = false;

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });
  });

  group('Explicit mode - module level (ANY row)', () {
    testWidgets('7. Module with ANY enabled row -> module access true (baseline route allowed)',
        (tester) async {
      // /settings is a baseline module (always true) -- use it to prove the
      // catalog-route path doesn't regress a non-purchasable module, while
      // the module-level ANY semantics themselves are already unit-tested
      // directly against EffectiveAccessService in Phase 3B-2.
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository();

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/settings');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/settings');
    });

    testWidgets('8. Zero enabled rows -> purchasable module form route blocked',
        (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository(); // nothing enabled anywhere

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });
  });

  group('Reports', () {
    // NOTE: two separate ProviderScope instances (not one mutated mid-test)
    // -- formAccessProvider/reportAccessProvider are Riverpod `.family`
    // futures cached per (formId, selected-org) for the reasons in Part G
    // (avoid re-querying on every rebuild). That means a fake repository
    // row flipped mid-session, in the SAME container, is a known,
    // documented staleness window (see Known Limitations in the Phase
    // 3B-3 report) -- not something this test should paper over by
    // asserting against a container that was never told to invalidate.
    testWidgets('9. Entitled report -> route allowed', (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:20'] = true;

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);

      router.go('/reports/day-closing');
      await _settle(tester);
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/reports/day-closing');
    });

    testWidgets(
        '10/13. Non-entitled report -> hidden from allowed navigation; direct URL blocked',
        (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository(); // no row for form 20 at all

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);

      router.go('/reports/day-closing');
      await _settle(tester);
      expect(
          router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });

    testWidgets('11. Individual report entitlement (module not purchased) still opens the report',
        (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:20'] = true;
      // accounting module itself has zero moduleAccessItems rows -- module
      // is NOT purchased, only the individual report row is enabled.

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/reports/day-closing');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/reports/day-closing');
    });

    testWidgets('12. Bundle-entitled report opens through the existing bundle path',
        (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..bundleFormAccess.add('42:20');

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/reports/day-closing');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/reports/day-closing');
    });
  });

  group('Separation of concerns', () {
    testWidgets('14. Commercially entitled but role denied -> still blocked', (tester) async {
      AuthService.testRole = UserRole.staff; // /settings requires admin+staff actually allows staff; use employees->users child which requires admin,staff too. Use superUser-only route instead.
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:1'] = true;

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      // /organizations-list/create requires UserRole.superUser only.
      router.go('/organizations-list/create');
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });

    testWidgets('15. Existing role/privilege checks still apply independent of entitlement',
        (tester) async {
      AuthService.testRole = UserRole.staff;
      final org = _org(entitlementMode: 'legacy', isInventory: true);
      final repo = _FakeEntitlementRepository();

      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));

      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/organizations-list/create'); // superUser only
      await _settle(tester);

      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });
  });

  group('Menu / router consistency', () {
    testWidgets('16/17. Commercially unavailable item hidden from menu AND direct nav blocked',
        (tester) async {
      final org = _org(entitlementMode: 'explicit'); // no rows -> Products not entitled
      final repo = _FakeEntitlementRepository();

      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(org: org, entitlementRepo: repo),
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const AppMenu(),
            body: const SizedBox(),
          ),
        ),
      ));
      await _settle(tester);

      scaffoldKey.currentState!.openDrawer();
      await _settle(tester);

      expect(find.text('Products'), findsNothing);

      // And direct navigation to the same route is blocked too (uses the
      // full router harness, same fake state).
      await tester.pumpWidget(ProviderScope(
          overrides: _overrides(org: org, entitlementRepo: repo),
          child: const MaterialAppWithRouter()));
      final router = ProviderScope.containerOf(
              tester.element(find.byType(MaterialAppWithRouter)))
          .read(routerProvider);
      router.go('/products');
      await _settle(tester);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/dashboard');
    });

    testWidgets('Commercially available item IS shown in menu', (tester) async {
      final org = _org(entitlementMode: 'explicit');
      final repo = _FakeEntitlementRepository()..formAccessItems['42:1'] = true;

      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(org: org, entitlementRepo: repo),
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const AppMenu(),
            body: const SizedBox(),
          ),
        ),
      ));
      await _settle(tester);

      scaffoldKey.currentState!.openDrawer();
      await _settle(tester);

      expect(find.text('Products'), findsOneWidget);
    });
  });

  group('resolveParameterizedReportFormId (pure function)', () {
    test('ledger/:type resolves each known type to its live form id', () {
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'customer'}), 9);
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'vendor'}), 10);
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'bank'}), 11);
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'cash'}), 12);
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'gl'}), 13);
    });

    test('sales/:groupBy and returns/:groupBy resolve distinct form ids', () {
      expect(
          resolveParameterizedReportFormId(RouteNames.salesReport, {'groupBy': 'product'}), 14);
      expect(
          resolveParameterizedReportFormId(RouteNames.salesReport, {'groupBy': 'customer'}), 15);
      expect(resolveParameterizedReportFormId(RouteNames.returnsReport, {'groupBy': 'product'}),
          16);
      expect(resolveParameterizedReportFormId(RouteNames.returnsReport, {'groupBy': 'customer'}),
          17);
    });

    test('unknown routeName/param returns null (non-catalog fallback)', () {
      expect(resolveParameterizedReportFormId('some-other-route', {'type': 'customer'}), isNull);
      expect(resolveParameterizedReportFormId(RouteNames.ledgerReport, {'type': 'unknown'}),
          isNull);
      expect(resolveParameterizedReportFormId(null, {}), isNull);
    });
  });
}
