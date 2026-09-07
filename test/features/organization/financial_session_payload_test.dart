// test/features/organization/financial_session_payload_test.dart
//
// Regression test for the boolean/smallint defect: `omtbl_financial_sessions`
// stores in_use/is_active/is_closed as smallint/integer columns. Sending
// Dart bool literals (as the pre-existing best-effort insert inside
// createOrganization() does) is rejected by Postgres, which — because that
// insert's error was swallowed — silently produced organizations with zero
// financial sessions. This test locks the corrected payload shape in place.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';

void main() {
  group('OrganizationRepositoryImpl.buildFinancialSessionInsertPayload', () {
    test('serializes in_use/is_active/is_closed as integers, not booleans',
        () {
      final payload =
          OrganizationRepositoryImpl.buildFinancialSessionInsertPayload(
        organizationId: 42,
        syear: 2026,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );

      expect(payload['in_use'], 1);
      expect(payload['is_active'], 1);
      expect(payload['is_closed'], 0);

      // Explicitly assert these are NOT bools - a regression here is exactly
      // the defect this patch fixes.
      expect(payload['in_use'], isA<int>());
      expect(payload['is_active'], isA<int>());
      expect(payload['is_closed'], isA<int>());
    });

    test('includes organization_id, syear, and ISO8601 dates', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 12, 31);
      final payload =
          OrganizationRepositoryImpl.buildFinancialSessionInsertPayload(
        organizationId: 7,
        syear: 2026,
        startDate: start,
        endDate: end,
      );

      expect(payload['organization_id'], 7);
      expect(payload['syear'], 2026);
      expect(payload['start_date'], start.toIso8601String());
      expect(payload['end_date'], end.toIso8601String());
    });

    test('defaults narration when not provided, honors it when provided',
        () {
      final withDefault =
          OrganizationRepositoryImpl.buildFinancialSessionInsertPayload(
        organizationId: 1,
        syear: 2026,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );
      expect(withDefault['narration'], 'Financial Year 2026');

      final withCustom =
          OrganizationRepositoryImpl.buildFinancialSessionInsertPayload(
        organizationId: 1,
        syear: 2026,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        narration: 'Custom label',
      );
      expect(withCustom['narration'], 'Custom label');
    });
  });
}
