// test/features/accounting/financial_session_default_selection_test.dart
//
// Covers FinancialSession.resolveDefault, the single shared selection rule
// used by both WorkspaceSelectionScreen and AccountingNotifier.loadAll (see
// section 13 of the fix: two independent copies of this logic is how they
// used to drift). Priority:
//   1. a persisted syear, if it still matches a loaded session
//   2. the only session, if there is exactly one
//   3. the session with in_use = 1 (DB-enforced: at most one per org)
//   4. the session with is_active = 1, only if exactly one qualifies
//   5. otherwise null - let the dropdown show, don't guess

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

FinancialSession _session(
  int syear, {
  bool inUse = false,
  bool isActive = false,
}) =>
    FinancialSession(
      sYear: syear,
      startDate: DateTime(syear, 1, 1),
      endDate: DateTime(syear, 12, 31),
      inUse: inUse,
      isActive: isActive,
      organizationId: 1,
    );

void main() {
  group('FinancialSession.resolveDefault', () {
    test('returns null for an empty list', () {
      expect(FinancialSession.resolveDefault(const []), isNull);
    });

    test('auto-selects the only session regardless of its flags', () {
      final session = _session(2026);
      expect(FinancialSession.resolveDefault([session]), session);
    });

    test('prefers the persisted syear over everything else', () {
      final sessions = [
        _session(2025, inUse: true),
        _session(2026),
      ];
      final result =
          FinancialSession.resolveDefault(sessions, persistedSyear: 2026);
      expect(result?.sYear, 2026);
    });

    test('a persisted syear not present in the list is ignored, not thrown',
        () {
      final sessions = [_session(2025, inUse: true), _session(2026)];
      final result =
          FinancialSession.resolveDefault(sessions, persistedSyear: 1999);
      expect(result?.sYear, 2025); // falls through to the in_use session
    });

    test('with multiple sessions, the unique in_use=1 session wins', () {
      final sessions = [
        _session(2024, isActive: true),
        _session(2025, inUse: true, isActive: true),
        _session(2026, isActive: true),
      ];
      final result = FinancialSession.resolveDefault(sessions);
      expect(result?.sYear, 2025);
    });

    test(
        'no in_use session but exactly one is_active=1 -> that one is used',
        () {
      final sessions = [
        _session(2024),
        _session(2025, isActive: true),
        _session(2026),
      ];
      final result = FinancialSession.resolveDefault(sessions);
      expect(result?.sYear, 2025);
    });

    test(
        'multiple sessions with no in_use and several is_active -> null, '
        'never guess an arbitrary one', () {
      final sessions = [
        _session(2024, isActive: true),
        _session(2025, isActive: true),
      ];
      final result = FinancialSession.resolveDefault(sessions);
      expect(result, isNull);
    });

    test('multiple sessions with neither in_use nor is_active set -> null',
        () {
      final sessions = [_session(2024), _session(2025)];
      final result = FinancialSession.resolveDefault(sessions);
      expect(result, isNull);
    });
  });
}
