// lib/features/accounting/domain/entities/chart_of_account.dart

import 'package:equatable/equatable.dart';

class ChartOfAccount {
  final String id;
  final String accountCode;
  final String accountTitle;
  final String? parentId;
  final int level;
  final int? accountTypeId;
  final int? accountCategoryId;
  final int? organizationId;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double openingBalance;

  const ChartOfAccount({
    required this.id,
    required this.accountCode,
    required this.accountTitle,
    this.parentId,
    required this.level,
    this.accountTypeId,
    this.accountCategoryId,
    this.organizationId,
    this.isActive = true,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
    this.openingBalance = 0.0,
  });

  ChartOfAccount copyWith({
    String? id,
    String? accountCode,
    String? accountTitle,
    String? parentId,
    int? level,
    int? accountTypeId,
    int? accountCategoryId,
    int? organizationId,
    bool? isActive,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? openingBalance,
  }) {
    return ChartOfAccount(
      id: id ?? this.id,
      accountCode: accountCode ?? this.accountCode,
      accountTitle: accountTitle ?? this.accountTitle,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      accountTypeId: accountTypeId ?? this.accountTypeId,
      accountCategoryId: accountCategoryId ?? this.accountCategoryId,
      organizationId: organizationId ?? this.organizationId,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }
}

class AccountType {
  final int id;
  final String typeName;
  final bool status;
  final bool isSystem;
  final int? organizationId;
  const AccountType({
    required this.id,
    required this.typeName,
    this.status = true,
    this.isSystem = false,
    this.organizationId,
  });
}

class AccountCategory {
  final int id;
  final String categoryName;
  final int accountTypeId;
  final bool status;
  final bool isSystem;
  final int? organizationId;
  const AccountCategory({
    required this.id,
    required this.categoryName,
    required this.accountTypeId,
    this.status = true,
    this.isSystem = false,
    this.organizationId,
  });
}

class BankCash {
  final String id;
  final String name;
  final String chartOfAccountId;
  final String? accountNumber;
  final String? branchName;
  final int? organizationId;
  final int? storeId;
  final bool status;
  final double openingBalance;

  const BankCash({
    required this.id,
    required this.name,
    required this.chartOfAccountId,
    this.accountNumber,
    this.branchName,
    this.organizationId,
    this.storeId,

    this.status = true,
    this.openingBalance = 0.0,
  });

  BankCash copyWith({
    String? id,
    String? name,
    String? chartOfAccountId,
    String? accountNumber,
    String? branchName,
    int? organizationId,
    int? storeId,
    bool? status,
    double? openingBalance,
  }) {
    return BankCash(
      id: id ?? this.id,
      name: name ?? this.name,
      chartOfAccountId: chartOfAccountId ?? this.chartOfAccountId,
      accountNumber: accountNumber ?? this.accountNumber,
      branchName: branchName ?? this.branchName,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      status: status ?? this.status,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }
}

class OpeningBalance {
  final String id;
  final int sYear;
  final double amount;
  final String entityId; // ID of Customer, Vendor, Bank, or GL Account
  final String entityType; // 'Customer', 'Vendor', 'Bank', 'GL' (Optional, but good for clarity)
  final int? organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OpeningBalance({
    required this.id,
    required this.sYear,
    required this.amount,
    required this.entityId,
    this.entityType = '',
    this.organizationId,
    required this.createdAt,
    required this.updatedAt,
  });
}

class VoucherPrefix {
  final int id;
  final String prefixCode;
  final String? description;
  final String voucherType;
  final int? organizationId;
  final bool status;
  final bool isSystem;

  const VoucherPrefix({
    required this.id,
    required this.prefixCode,
    this.description,
    required this.voucherType,
    this.organizationId,
    this.status = true,
    this.isSystem = false,
  });
}

class Transaction {
  final String id;
  final int voucherPrefixId;
  final String voucherNumber;
  final DateTime voucherDate;
  final String accountId;
  final String? offsetAccountId;
  final double amount;
  final String? description;
  final String status;
  final int? organizationId;
  final int? storeId;
  final int? sYear;
  final String? moduleAccount;
  final String? offsetModuleAccount;
  final String? paymentMode;
  final String? referenceNumber;
  final DateTime? referenceDate;
  final String? referenceBank;
  final String? invoiceId;

  const Transaction({
    required this.id,
    required this.voucherPrefixId,
    required this.voucherNumber,
    required this.voucherDate,
    required this.accountId,
    this.offsetAccountId,
    required this.amount,
    this.description,
    this.status = 'posted',
    this.organizationId,
    this.storeId,
    this.sYear,
    this.moduleAccount,
    this.offsetModuleAccount,
    this.paymentMode,
    this.referenceNumber,
    this.referenceDate,
    this.referenceBank,
    this.invoiceId,
  });
}

class PaymentTerm {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  final int days;
  final int? organizationId;

  const PaymentTerm({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.days = 0,
    this.organizationId,
  });
}

class FinancialSession extends Equatable {
  final String? id;
  final int sYear;
  final DateTime startDate;
  final DateTime endDate;
  final String? narration;
  final bool inUse;
  final bool isActive;
  final bool isClosed;
  final int? organizationId;

  const FinancialSession({
    this.id,
    required this.sYear,
    required this.startDate,
    required this.endDate,
    this.narration,
    this.inUse = false,
    this.isActive = true,
    this.isClosed = false,
    this.organizationId,
  });

  @override
  List<Object?> get props => [
        id,
        sYear,
        startDate,
        endDate,
        narration,
        inUse,
        isActive,
        isClosed,
        organizationId,
      ];

  /// Resolves which of [sessions] should be pre-selected, without ever
  /// guessing when the choice is genuinely ambiguous — the caller (Workspace,
  /// AccountingNotifier.loadAll) should fall back to asking the user by
  /// leaving its own selection null.
  ///
  /// Priority, matching the schema's own business rules rather than an
  /// arbitrary "first" pick:
  ///  1. [persistedSyear], if it still matches one of [sessions] (restores
  ///     what the user picked previously).
  ///  2. The only session, if there is exactly one.
  ///  3. The session with `in_use = 1` — `omtbl_financial_sessions` enforces
  ///     `UNIQUE (organization_id) WHERE in_use = 1`, so this can only ever
  ///     match zero or one row; it is the authoritative "current" flag.
  ///  4. The session with `is_active = 1`, but only if exactly one qualifies
  ///     (multiple active-but-not-in-use sessions is not a "clear default").
  ///  5. Otherwise null — let the dropdown show and the user choose.
  static FinancialSession? resolveDefault(
    List<FinancialSession> sessions, {
    int? persistedSyear,
  }) {
    if (sessions.isEmpty) return null;

    if (persistedSyear != null) {
      final persisted =
          sessions.where((s) => s.sYear == persistedSyear).firstOrNull;
      if (persisted != null) return persisted;
    }

    if (sessions.length == 1) return sessions.first;

    final inUseMatches = sessions.where((s) => s.inUse).toList();
    if (inUseMatches.length == 1) return inUseMatches.first;

    final activeMatches = sessions.where((s) => s.isActive).toList();
    if (activeMatches.length == 1) return activeMatches.first;

    return null;
  }
}
