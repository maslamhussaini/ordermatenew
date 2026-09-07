/// The three Financial Year modes offered during registration.
enum FinancialYearMode {
  /// User supplies an arbitrary start/end date.
  fiscalCustom,

  /// Jan 1 -> Dec 31 of the current year.
  calendarYear,

  /// Jul 1 -> Jun 30, whichever such period contains "today".
  julyToJune,
}

/// Result of resolving a [FinancialYearMode] into concrete dates.
///
/// `syear` follows the convention already used by `omtbl_financial_sessions`:
/// the calendar year in which the session's `start_date` falls.
class FinancialYearPeriod {
  final DateTime startDate;
  final DateTime endDate;
  final int syear;

  const FinancialYearPeriod({
    required this.startDate,
    required this.endDate,
    required this.syear,
  });
}

/// Pure calculation logic, deliberately kept free of Flutter/Supabase
/// dependencies so it can be unit tested without a widget or DB harness.
class FinancialYearCalculator {
  const FinancialYearCalculator._();

  /// Resolves [mode] into a concrete [FinancialYearPeriod].
  ///
  /// [referenceDate] defaults to `DateTime.now()` and is only used by
  /// [FinancialYearMode.calendarYear] and [FinancialYearMode.julyToJune].
  /// [customStart]/[customEnd] are required for
  /// [FinancialYearMode.fiscalCustom] and are ignored otherwise.
  static FinancialYearPeriod resolve({
    required FinancialYearMode mode,
    DateTime? referenceDate,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = referenceDate ?? DateTime.now();

    switch (mode) {
      case FinancialYearMode.calendarYear:
        return FinancialYearPeriod(
          startDate: DateTime(now.year, 1, 1),
          endDate: DateTime(now.year, 12, 31),
          syear: now.year,
        );

      case FinancialYearMode.julyToJune:
        // The July->June period containing `now`.
        // If we're in Jan-Jun, the period started last calendar year.
        final startYear = now.month >= 7 ? now.year : now.year - 1;
        return FinancialYearPeriod(
          startDate: DateTime(startYear, 7, 1),
          endDate: DateTime(startYear + 1, 6, 30),
          syear: startYear,
        );

      case FinancialYearMode.fiscalCustom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError(
            'customStart and customEnd are required for FinancialYearMode.fiscalCustom',
          );
        }
        if (!customEnd.isAfter(customStart)) {
          throw ArgumentError('End date must be after start date');
        }
        return FinancialYearPeriod(
          startDate: customStart,
          endDate: customEnd,
          syear: customStart.year,
        );
    }
  }
}
