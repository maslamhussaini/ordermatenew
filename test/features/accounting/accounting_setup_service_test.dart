// test/features/accounting/accounting_setup_service_test.dart
//
// Phase QA P0.1: AccountingSetupService.seedInvoiceTypesAndVoucherPrefixes
// is the new entry point wired into real self-service signup
// (organization_configure_screen.dart), extracted from the admin-only
// setupDefaultAccounting() so it can run without re-seeding chart of
// accounts (owned by AccountingSeedService on the real signup path).
//
// This suite proves, against a mock repository (no live network):
//   1. Invoice types are created for the organization (4 fixed codes).
//   2. Voucher prefixes are created for the organization (7 fixed codes).
//   3. Re-running is idempotent: voucher prefixes are NOT duplicated on a
//      second run (the confirmed pre-fix bug -- createVoucherPrefix always
//      inserted with id:0, never deduping) -- this is the specific defect
//      this fix addresses, verified here without touching the live DB.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ordermate/features/accounting/data/models/accounting_models.dart';
import 'package:ordermate/features/accounting/data/services/accounting_setup_service.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';

class MockAccountingRepository extends Mock implements AccountingRepository {}

void main() {
  late MockAccountingRepository repo;
  late AccountingSetupService service;

  setUpAll(() {
    registerFallbackValue(const InvoiceTypeModel(
        idInvoiceType: 'X', description: 'x', forUsed: 'x', organizationId: 0));
    registerFallbackValue(
        const VoucherPrefixModel(id: 0, prefixCode: 'X', voucherType: 'x', organizationId: 0));
  });

  setUp(() {
    repo = MockAccountingRepository();
    service = AccountingSetupService(repo);
    when(() => repo.createInvoiceType(any())).thenAnswer((_) async {});
    when(() => repo.createVoucherPrefix(any())).thenAnswer((_) async {});
  });

  group('seedInvoiceTypesAndVoucherPrefixes', () {
    test('creates all 4 fixed invoice types for the organization', () async {
      when(() => repo.getVoucherPrefixes(organizationId: 42))
          .thenAnswer((_) async => []);

      await service.seedInvoiceTypesAndVoucherPrefixes(42);

      final captured = verify(() => repo.createInvoiceType(captureAny()))
          .captured
          .cast<InvoiceType>();
      expect(captured.map((t) => t.idInvoiceType).toSet(),
          {'SI', 'SIR', 'PI', 'PR'});
      expect(captured.every((t) => t.organizationId == 42), isTrue);
    });

    test('creates all 7 voucher prefixes when none exist yet', () async {
      when(() => repo.getVoucherPrefixes(organizationId: 42))
          .thenAnswer((_) async => []);

      await service.seedInvoiceTypesAndVoucherPrefixes(42);

      final captured = verify(() => repo.createVoucherPrefix(captureAny()))
          .captured
          .cast<VoucherPrefix>();
      expect(captured.map((p) => p.prefixCode).toSet(),
          {'CRV', 'BRV', 'SI', 'SIR', 'CPV', 'BPV', 'JV'});
    });

    test('idempotency: re-running with all prefixes already present creates zero duplicates',
        () async {
      // Simulates the second run of onboarding (retry) for an org that
      // already has all 7 prefixes from a first successful run.
      when(() => repo.getVoucherPrefixes(organizationId: 42)).thenAnswer(
          (_) async => const [
                VoucherPrefix(id: 1, prefixCode: 'CRV', voucherType: 'Receipt', organizationId: 42),
                VoucherPrefix(id: 2, prefixCode: 'BRV', voucherType: 'Receipt', organizationId: 42),
                VoucherPrefix(id: 3, prefixCode: 'SI', voucherType: 'Sales', organizationId: 42),
                VoucherPrefix(id: 4, prefixCode: 'SIR', voucherType: 'Returns', organizationId: 42),
                VoucherPrefix(id: 5, prefixCode: 'CPV', voucherType: 'Payment', organizationId: 42),
                VoucherPrefix(id: 6, prefixCode: 'BPV', voucherType: 'Payment', organizationId: 42),
                VoucherPrefix(id: 7, prefixCode: 'JV', voucherType: 'Journal', organizationId: 42),
              ]);

      await service.seedInvoiceTypesAndVoucherPrefixes(42);

      verifyNever(() => repo.createVoucherPrefix(any()));
    });

    test('idempotency: partial re-run only creates the still-missing prefixes', () async {
      when(() => repo.getVoucherPrefixes(organizationId: 42)).thenAnswer(
          (_) async => const [
                VoucherPrefix(id: 1, prefixCode: 'CRV', voucherType: 'Receipt', organizationId: 42),
                VoucherPrefix(id: 2, prefixCode: 'BRV', voucherType: 'Receipt', organizationId: 42),
              ]);

      await service.seedInvoiceTypesAndVoucherPrefixes(42);

      final captured = verify(() => repo.createVoucherPrefix(captureAny()))
          .captured
          .cast<VoucherPrefix>();
      expect(captured.map((p) => p.prefixCode).toSet(),
          {'SI', 'SIR', 'CPV', 'BPV', 'JV'});
      expect(captured.any((p) => p.prefixCode == 'CRV'), isFalse);
      expect(captured.any((p) => p.prefixCode == 'BRV'), isFalse);
    });

    test('aborts voucher-prefix seeding (does not guess) if the existing-check itself fails',
        () async {
      when(() => repo.getVoucherPrefixes(organizationId: 42))
          .thenThrow(Exception('network error'));

      await service.seedInvoiceTypesAndVoucherPrefixes(42);

      verifyNever(() => repo.createVoucherPrefix(any()));
    });
  });
}
