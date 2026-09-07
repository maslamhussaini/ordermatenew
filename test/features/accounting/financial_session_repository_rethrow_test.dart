// test/features/accounting/financial_session_repository_rethrow_test.dart
//
// AccountingRepositoryImpl.createFinancialSession/updateFinancialSession
// (used by the "Add Financial Year" screen in Settings > Accounting) caught
// a failed insert/update, saved an "unsynced" local copy, and returned
// normally — the caller (and the SnackBar-driven UI above it) had no way to
// know the write had failed. Every sibling create*/update* method in the
// same file (e.g. createChartOfAccount) follows the same
// "save local fallback, then rethrow" shape; these two were missing the
// rethrow. Source-level check: SupabaseConfig.client has no injection seam
// (see the other source-level tests in this suite for the same constraint).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountingRepositoryImpl financial session writes rethrow on failure', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/accounting/data/repositories/accounting_repository_impl.dart',
      ).readAsStringSync();
    });

    test('createFinancialSession rethrows after the local fallback save', () {
      final start = src.indexOf('Future<void> createFinancialSession(FinancialSession session) async {');
      expect(start, greaterThan(-1));
      final end = src.indexOf(
          'Future<void> updateFinancialSession(FinancialSession session) async {',
          start);
      expect(end, greaterThan(start));
      final body = src.substring(start, end);

      expect(body.contains('rethrow;'), isTrue,
          reason: 'a failed online write must not be silently reported as '
              'success — see the identical pattern in createChartOfAccount');
    });

    test('updateFinancialSession rethrows after the local fallback save', () {
      final start = src.indexOf(
          'Future<void> updateFinancialSession(FinancialSession session) async {');
      expect(start, greaterThan(-1));
      final end = src.indexOf('Future<bool> isAccountUsed(', start);
      expect(end, greaterThan(start));
      final body = src.substring(start, end);

      expect(body.contains('rethrow;'), isTrue);
    });
  });
}
