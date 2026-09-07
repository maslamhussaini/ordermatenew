import '../../domain/entities/daily_balance.dart';

class DailyBalanceModel extends DailyBalance {
  const DailyBalanceModel({
    required super.id,
    required super.accountId,
    required super.date,
    super.openingBalance,
    super.closingBalance,
    super.transactionsDebit,
    super.transactionsCredit,
    super.isClosed,
    required super.organizationId,
  });

  factory DailyBalanceModel.fromJson(Map<String, dynamic> json) {
    return DailyBalanceModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      openingBalance: (json['opening_balance'] as num).toDouble(),
      closingBalance: (json['closing_balance'] as num).toDouble(),
      transactionsDebit: (json['transactions_debit'] as num).toDouble(),
      transactionsCredit: (json['transactions_credit'] as num).toDouble(),
      isClosed: (json['is_closed'] as int) == 1,
      organizationId: json['organization_id'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'date': date.millisecondsSinceEpoch,
      'opening_balance': openingBalance,
      'closing_balance': closingBalance,
      'transactions_debit': transactionsDebit,
      'transactions_credit': transactionsCredit,
      'is_closed': isClosed ? 1 : 0,
      'organization_id': organizationId,
    };
  }

  factory DailyBalanceModel.fromEntity(DailyBalance entity) {
    return DailyBalanceModel(
      id: entity.id,
      accountId: entity.accountId,
      date: entity.date,
      openingBalance: entity.openingBalance,
      closingBalance: entity.closingBalance,
      transactionsDebit: entity.transactionsDebit,
      transactionsCredit: entity.transactionsCredit,
      isClosed: entity.isClosed,
      organizationId: entity.organizationId,
    );
  }
}
