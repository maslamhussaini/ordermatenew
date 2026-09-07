import 'package:equatable/equatable.dart';

class DailyBalance extends Equatable {
  final String id;
  final String accountId; // COA Account ID (Bank or Cash)
  final DateTime date;
  final double openingBalance;
  final double closingBalance;
  final double transactionsDebit;
  final double transactionsCredit;
  final bool isClosed;
  final int organizationId;

  const DailyBalance({
    required this.id,
    required this.accountId,
    required this.date,
    this.openingBalance = 0.0,
    this.closingBalance = 0.0,
    this.transactionsDebit = 0.0,
    this.transactionsCredit = 0.0,
    this.isClosed = false,
    required this.organizationId,
  });

  @override
  List<Object?> get props => [
        id,
        accountId,
        date,
        openingBalance,
        closingBalance,
        transactionsDebit,
        transactionsCredit,
        isClosed,
        organizationId,
      ];

  DailyBalance copyWith({
    String? id,
    String? accountId,
    DateTime? date,
    double? openingBalance,
    double? closingBalance,
    double? transactionsDebit,
    double? transactionsCredit,
    bool? isClosed,
    int? organizationId,
  }) {
    return DailyBalance(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      transactionsDebit: transactionsDebit ?? this.transactionsDebit,
      transactionsCredit: transactionsCredit ?? this.transactionsCredit,
      isClosed: isClosed ?? this.isClosed,
      organizationId: organizationId ?? this.organizationId,
    );
  }
}
