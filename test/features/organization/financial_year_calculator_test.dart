// test/features/organization/financial_year_calculator_test.dart
//
// Covers the three registration Financial Year modes (Fiscal/Custom,
// Calendar Year, July->June) added to fix "Financial sessions are missing"
// during registration. Pure logic, no Supabase/Flutter dependency.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/organization/domain/entities/financial_year_option.dart';

void main() {
  group('FinancialYearCalculator.resolve - calendarYear', () {
    test('uses Jan 1 - Dec 31 of the reference year', () {
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.calendarYear,
        referenceDate: DateTime(2026, 8, 31),
      );

      expect(result.startDate, DateTime(2026, 1, 1));
      expect(result.endDate, DateTime(2026, 12, 31));
      expect(result.syear, 2026);
    });
  });

  group('FinancialYearCalculator.resolve - julyToJune', () {
    test(
        '2026-08-31 falls in the 2026-07-01 -> 2027-06-30 period (syear=2026)',
        () {
      // This is the exact example given in the approved patch plan.
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.julyToJune,
        referenceDate: DateTime(2026, 8, 31),
      );

      expect(result.startDate, DateTime(2026, 7, 1));
      expect(result.endDate, DateTime(2027, 6, 30));
      expect(result.syear, 2026);
    });

    test('a date in Jan-Jun falls in the period that started the prior year',
        () {
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.julyToJune,
        referenceDate: DateTime(2026, 3, 15),
      );

      expect(result.startDate, DateTime(2025, 7, 1));
      expect(result.endDate, DateTime(2026, 6, 30));
      expect(result.syear, 2025);
    });

    test('the boundary date July 1 itself starts a new period', () {
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.julyToJune,
        referenceDate: DateTime(2026, 7, 1),
      );

      expect(result.startDate, DateTime(2026, 7, 1));
      expect(result.endDate, DateTime(2027, 6, 30));
      expect(result.syear, 2026);
    });

    test('the boundary date June 30 itself ends the current period', () {
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.julyToJune,
        referenceDate: DateTime(2026, 6, 30),
      );

      expect(result.startDate, DateTime(2025, 7, 1));
      expect(result.endDate, DateTime(2026, 6, 30));
      expect(result.syear, 2025);
    });
  });

  group('FinancialYearCalculator.resolve - fiscalCustom', () {
    test('uses the supplied start/end dates and derives syear from start',
        () {
      final result = FinancialYearCalculator.resolve(
        mode: FinancialYearMode.fiscalCustom,
        customStart: DateTime(2026, 4, 1),
        customEnd: DateTime(2027, 3, 31),
      );

      expect(result.startDate, DateTime(2026, 4, 1));
      expect(result.endDate, DateTime(2027, 3, 31));
      expect(result.syear, 2026);
    });

    test('throws ArgumentError when start/end are missing', () {
      expect(
        () => FinancialYearCalculator.resolve(
          mode: FinancialYearMode.fiscalCustom,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when end date is not after start date', () {
      expect(
        () => FinancialYearCalculator.resolve(
          mode: FinancialYearMode.fiscalCustom,
          customStart: DateTime(2026, 6, 1),
          customEnd: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
