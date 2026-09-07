// test/features/accounting/financial_session_model_test.dart
//
// Regression test for the defect that made Workspace show "No sessions
// found" even for an organization with a correctly-inserted financial
// session: `omtbl_financial_sessions.id` is `bigint`, so PostgREST returns
// it as a JSON number. FinancialSessionModel.fromJson did `json['id'] as
// String?`, which throws a TypeError on every row. That exception was
// caught by AccountingNotifier.loadAll's per-field `.catchError(() => [])`
// and silently turned into an empty list — indistinguishable in the UI from
// "this organization genuinely has no financial sessions yet".
//
// Also covers the sibling defect in toJson(): in_use/is_active/is_closed are
// smallint columns, not boolean, so sending Dart bool literals is rejected
// by Postgres (the same class of bug already fixed for the registration
// path in OrganizationRepositoryImpl.buildFinancialSessionInsertPayload).

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/accounting/data/models/accounting_models.dart';

void main() {
  group('FinancialSessionModel.fromJson', () {
    test('parses a numeric bigint id without throwing', () {
      final json = {
        'id': 42,
        'syear': 2026,
        'start_date': '2026-01-01T00:00:00.000',
        'end_date': '2026-12-31T00:00:00.000',
        'narration': 'Financial Year 2026',
        'in_use': 1,
        'is_active': 1,
        'is_closed': 0,
        'organization_id': 2,
      };

      final model = FinancialSessionModel.fromJson(json);

      expect(model.id, '42');
      expect(model.sYear, 2026);
      expect(model.inUse, isTrue);
      expect(model.isActive, isTrue);
      expect(model.isClosed, isFalse);
      expect(model.organizationId, 2);
    });

    test('still parses a string id (defensive: does not assume shape)', () {
      final json = {
        'id': 'abc-123',
        'syear': 2026,
        'start_date': '2026-01-01T00:00:00.000',
        'end_date': '2026-12-31T00:00:00.000',
        'in_use': 0,
        'is_active': 1,
        'is_closed': 0,
        'organization_id': 2,
      };

      final model = FinancialSessionModel.fromJson(json);
      expect(model.id, 'abc-123');
    });

    test('a null id does not throw', () {
      final json = {
        'id': null,
        'syear': 2026,
        'start_date': '2026-01-01T00:00:00.000',
        'end_date': '2026-12-31T00:00:00.000',
        'in_use': 0,
        'is_active': 1,
        'is_closed': 0,
        'organization_id': 2,
      };

      final model = FinancialSessionModel.fromJson(json);
      expect(model.id, isNull);
    });
  });

  group('FinancialSessionModel.toJson', () {
    test('serializes in_use/is_active/is_closed as integers, not booleans',
        () {
      final model = FinancialSessionModel(
        sYear: 2026,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        inUse: true,
        isActive: true,
        isClosed: false,
        organizationId: 2,
      );

      final json = model.toJson();

      expect(json['in_use'], 1);
      expect(json['is_active'], 1);
      expect(json['is_closed'], 0);
      expect(json['in_use'], isA<int>());
      expect(json['is_active'], isA<int>());
      expect(json['is_closed'], isA<int>());
    });

    test('omits id when absent, includes it (as-is) when present', () {
      final withoutId = FinancialSessionModel(
        sYear: 2026,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        organizationId: 2,
      );
      expect(withoutId.toJson().containsKey('id'), isFalse);

      final withId = FinancialSessionModel(
        id: '42',
        sYear: 2026,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        organizationId: 2,
      );
      expect(withId.toJson()['id'], '42');
    });
  });
}
