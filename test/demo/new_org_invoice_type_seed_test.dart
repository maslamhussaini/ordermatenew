// Focused test for the new-organization Invoice Type seeding fix.
//
// Verifies AccountingSetupService.seedInvoiceTypesAndVoucherPrefixes (the
// existing, already-idempotent seeding method reused by both the self-serve
// signup screen and the admin "New Organization" flow) actually seeds
// SI/SIR/PI/PR for a new organization, and that calling it again does not
// create duplicates. Exercises the real local-repository path (offline
// mode, real SQLite via sqflite_common_ffi) -- no live Supabase call.
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/accounting/data/services/accounting_setup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // AccountingRepositoryImpl's constructor touches SupabaseConfig.client
    // (real Supabase singleton) even though this test forces the
    // offline/local-only code path below -- initialize a throwaway client
    // so that access doesn't crash. No network call is made by
    // initialize() itself, and isOfflineLoggedIn ensures no real API call
    // is made by the code under test either.
    await supabase.Supabase.initialize(
      url: 'https://test.invalid.supabase.co',
      anonKey: 'test-anon-key',
    );
    // Force the local-only path in AccountingRepositoryImpl.createInvoiceType
    // / createVoucherPrefix -- no live Supabase call in this test.
    SupabaseConfig.isOfflineLoggedIn = true;
  });

  tearDownAll(() {
    SupabaseConfig.isOfflineLoggedIn = false;
  });

  const newOrgId = 99101;

  test(
      'new organization -> SI/SIR/PI/PR invoice types are seeded, and '
      're-running does not create duplicates', () async {
    final localRepo = LocalAccountingRepository();
    final service = AccountingSetupService(AccountingRepositoryImpl(localRepo));

    // Simulate the moment right after a new organization is created.
    await service.seedInvoiceTypesAndVoucherPrefixes(newOrgId);

    final firstPass =
        await localRepo.getInvoiceTypes(organizationId: newOrgId);
    final firstPassCodes = firstPass.map((t) => t.idInvoiceType).toSet();

    expect(firstPassCodes, {'SI', 'SIR', 'PI', 'PR'},
        reason: 'all four required invoice types must be seeded');
    for (final type in firstPass) {
      expect(type.isActive, isTrue,
          reason: '${type.idInvoiceType} must be seeded active');
    }

    // Confirm expected descriptions are preserved.
    final si = firstPass.firstWhere((t) => t.idInvoiceType == 'SI');
    expect(si.description, 'Sales Invoice');
    final sir = firstPass.firstWhere((t) => t.idInvoiceType == 'SIR');
    expect(sir.description, 'Sales Invoice Return');
    final pi = firstPass.firstWhere((t) => t.idInvoiceType == 'PI');
    expect(pi.description, 'Purchase Invoice');
    final pr = firstPass.firstWhere((t) => t.idInvoiceType == 'PR');
    expect(pr.description, 'Purchase Return');

    // Re-run initialization (mirrors calling it again, e.g. a retried
    // setup) -- must not create duplicates.
    await service.seedInvoiceTypesAndVoucherPrefixes(newOrgId);

    final secondPass =
        await localRepo.getInvoiceTypes(organizationId: newOrgId);
    expect(secondPass.length, firstPass.length,
        reason: 're-running the seed must not duplicate rows');
    expect(secondPass.map((t) => t.idInvoiceType).toSet(),
        {'SI', 'SIR', 'PI', 'PR'});
  });

  test(
      'setupDefaultAccounting seeds invoice types even if an earlier step '
      'in the same method would fail', () async {
    // This mirrors the confirmed bug: an organization missing its invoice
    // types despite setupDefaultAccounting already calling the seed method,
    // because it used to run only after the (fallible) account-types /
    // categories / chart-of-accounts import steps. Those steps read from
    // bundled JSON assets, which are unavailable in this plain `flutter
    // test` (non-widget-test) environment and will throw -- proving the
    // invoice-type seed still completes regardless, since it now runs
    // first, in its own try/catch.
    const orgId = 99102;
    final localRepo = LocalAccountingRepository();
    final service = AccountingSetupService(AccountingRepositoryImpl(localRepo));

    await service.setupDefaultAccounting(orgId);

    final types = await localRepo.getInvoiceTypes(organizationId: orgId);
    expect(types.map((t) => t.idInvoiceType).toSet(), {'SI', 'SIR', 'PI', 'PR'},
        reason:
            'invoice types must be seeded even when the account-types/COA '
            'import steps fail (e.g. asset loading unavailable here)');
  });
}
