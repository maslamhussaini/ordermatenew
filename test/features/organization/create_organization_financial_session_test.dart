// test/features/organization/create_organization_financial_session_test.dart
//
// Regression test for the confirmed production defect: `createOrganization()`
// inserted its default financial session with bool literals (true/true/false)
// against smallint/integer columns, and swallowed the resulting Postgres
// error in a bare try/catch — so every organization created through this
// path silently ended up with ZERO financial sessions.
// Confirmed in production: org_id=1 ("Herbmax") has 0 sessions.
//
// `SupabaseConfig.client` is a real static singleton (see
// lib/core/network/supabase_client.dart) with no injection seam, so a live
// call to createOrganization() cannot be exercised against a fake backend in
// this test suite. Following the same approach already used in
// test/security_regression_test.dart for this exact constraint, this test
// verifies the fix at the source level:
//
//   1. createOrganization() no longer contains the old bool literals.
//   2. createOrganization() delegates to createFinancialSession(...), which
//      is unit-tested elsewhere (financial_session_payload_test.dart) to
//      prove it serializes in_use/is_active/is_closed as 1/1/0 — so this
//      test's job is only to prove createOrganization() actually calls that
//      already-correct code path, not to re-derive the values.
//   3. The financial-session insert inside createOrganization() is no
//      longer wrapped in its own try/catch (i.e. no swallowed error path).
//
// Together with financial_session_payload_test.dart, this proves
// createOrganization() creates its financial session successfully whenever
// the underlying insert succeeds, and fails loudly (instead of returning a
// "successful" organization with zero sessions) whenever it doesn't.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('N-6 — createOrganization() financial session', () {
    late String src;
    late String createOrganizationBody;

    setUpAll(() {
      src = File(
        'lib/features/organization/data/repositories/organization_repository_impl.dart',
      ).readAsStringSync();

      // Isolate the createOrganization() method body (up to the next
      // top-level method in the class) so assertions can't accidentally pass
      // by matching something elsewhere in the file.
      final start = src.indexOf('Future<Organization> createOrganization(');
      expect(start, greaterThan(-1),
          reason: 'createOrganization() must still exist with this name');
      final nextMethodMarker =
          src.indexOf('static Map<String, dynamic> buildFinancialSessionInsertPayload');
      expect(nextMethodMarker, greaterThan(start),
          reason: 'expected buildFinancialSessionInsertPayload to follow '
              'createOrganization() in this file');
      createOrganizationBody = src.substring(start, nextMethodMarker);
      // Sanity: make sure we actually captured the method, not an empty slice.
      expect(createOrganizationBody.contains('createFinancialSession'), isTrue,
          reason:
              'test isolation failed to capture the createOrganization() body');
    });

    test('no longer sends bool literals for in_use/is_active/is_closed', () {
      expect(createOrganizationBody.contains("'in_use': true"), isFalse,
          reason: 'must not send bool for the smallint in_use column');
      expect(createOrganizationBody.contains("'is_active': true"), isFalse,
          reason: 'must not send bool for the smallint is_active column');
      expect(createOrganizationBody.contains("'is_closed': false"), isFalse,
          reason: 'must not send bool for the smallint is_closed column');
    });

    test('delegates to the shared, int-safe createFinancialSession(...)', () {
      expect(createOrganizationBody.contains('createFinancialSession('), isTrue,
          reason: 'createOrganization() must reuse the int-safe session '
              'creation path rather than duplicating a raw insert');
    });

    test('does not wrap the financial-session creation in its own try/catch',
        () {
      final sessionCallIndex =
          createOrganizationBody.indexOf('createFinancialSession(');
      expect(sessionCallIndex, greaterThan(-1));

      // The only catch in this method body must be the outer one that wraps
      // the whole method (which rethrows as an Exception) — there must not
      // be a nested catch between the org insert and the session call that
      // swallows a session-creation failure.
      final betweenOrgAndSession =
          createOrganizationBody.substring(0, sessionCallIndex);
      expect(betweenOrgAndSession.contains('catch ('), isFalse,
          reason: 'financial-session creation must not be shielded by its '
              'own swallowing try/catch (that was the root cause of orgs '
              'with zero financial sessions)');
    });

    test('createOrganization() signature is unchanged', () {
      // Line-ending agnostic (source file uses CRLF): normalize before
      // comparing against the expected signature shape.
      final normalized = src.replaceAll('\r\n', '\n');
      expect(
        normalized.contains(
          'Future<Organization> createOrganization(\n'
          '    String name,\n'
          '    String? taxId,\n'
          '    bool hasMultipleBranches,\n'
          '    String? logoUrl, {\n'
          '    int? businessTypeId,\n'
          '  })',
        ),
        isTrue,
        reason: 'public signature must not change unnecessarily',
      );
    });
  });
}
