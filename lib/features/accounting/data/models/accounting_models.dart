// lib/features/accounting/data/models/accounting_models.dart

import '../../domain/entities/chart_of_account.dart';
import '../../domain/entities/invoice.dart';

class ChartOfAccountModel extends ChartOfAccount {
  const ChartOfAccountModel({
    required super.id,
    required super.accountCode,
    required super.accountTitle,
    super.parentId,
    required super.level,
    super.accountTypeId,
    super.accountCategoryId,
    required super.organizationId,
    super.isActive,
    super.isSystem,
    required super.createdAt,
    required super.updatedAt,
    super.openingBalance,
  });

  factory ChartOfAccountModel.fromJson(Map<String, dynamic> json) {
    return ChartOfAccountModel(
      id: (json['id'] ?? '').toString(),
      accountCode: (json['account_code'] ?? '').toString(),
      accountTitle: (json['account_title'] ?? '').toString(),
      parentId: json['parent_id']?.toString(),
      level: (json['level'] ?? 0) as int,
      accountTypeId: json['account_type_id'] as int?,
      accountCategoryId: json['account_category_id'] as int?,
      organizationId: (json['organization_id'] as int?) ?? 0,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          (json['is_active'] == null),
      isSystem: json['is_system'] == true || json['is_system'] == 1,
      createdAt: json['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
          : DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      updatedAt: json['updated_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now(),
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'account_code': accountCode,
      'account_title': accountTitle,
      'parent_id': parentId,
      'level': level,
      'account_type_id': accountTypeId,
      'account_category_id': accountCategoryId,
      'organization_id': organizationId,
      'is_active': isActive,
      'is_system': isSystem,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'opening_balance': openingBalance,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.voucherPrefixId,
    required super.voucherNumber,
    required super.voucherDate,
    required super.accountId,
    super.offsetAccountId,
    required super.amount,
    super.description,
    super.status,
    required super.organizationId,
    required super.storeId,
    super.sYear,
    super.moduleAccount,
    super.offsetModuleAccount,
    super.paymentMode,
    super.referenceNumber,
    super.referenceDate,
    super.referenceBank,
    super.invoiceId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      voucherPrefixId: json['voucher_prefix_id'] as int,
      voucherNumber: json['voucher_number'] as String,
      voucherDate: DateTime.parse(json['voucher_date'] as String),
      accountId: json['account_id'] as String,
      offsetAccountId: json['offset_account_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'posted',
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      sYear: json['syear'] as int?,
      moduleAccount: json['module_account'] as String?,
      offsetModuleAccount: json['offset_module_account'] as String?,
      paymentMode: json['payment_mode'] as String?,
      referenceNumber: json['reference_number'] as String?,
      referenceDate: json['reference_date'] == null
          ? null
          : DateTime.parse(json['reference_date'] as String),
      referenceBank: json['reference_bank'] as String?,
      invoiceId: json['invoice_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_prefix_id': voucherPrefixId,
      'voucher_number': voucherNumber,
      'voucher_date': voucherDate.toIso8601String(),
      'account_id': accountId,
      'offset_account_id': offsetAccountId,
      'amount': amount,
      'description': description,
      'status': status,
      'organization_id': organizationId,
      'store_id': storeId,
      'syear': sYear,
      'module_account': moduleAccount,
      'offset_module_account': offsetModuleAccount,
      'payment_mode': paymentMode,
      'reference_number': referenceNumber,
      'reference_date': referenceDate?.toIso8601String(),
      'reference_bank': referenceBank,
      'invoice_id': invoiceId,
    };
  }
}

class PaymentTermModel extends PaymentTerm {
  const PaymentTermModel({
    required super.id,
    required super.name,
    super.description,
    super.isActive,
    super.days,
    required super.organizationId,
  });

  factory PaymentTermModel.fromJson(Map<String, dynamic> json) {
    return PaymentTermModel(
      id: json['id'] as int,
      name: json['payment_term'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      days: json['days'] as int? ?? 0,
      organizationId: (json['organization_id'] as int?) ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'payment_term': name,
      'description': description,
      'is_active': isActive,
      'days': days,
      'organization_id': organizationId,
    };
    if (id != 0) {
      map['id'] = id;
    }
    return map;
  }
}

class AccountTypeModel extends AccountType {
  const AccountTypeModel({
    required super.id,
    required super.typeName,
    super.status,
    super.isSystem,
    required super.organizationId,
  });

  factory AccountTypeModel.fromJson(Map<String, dynamic> json) {
    return AccountTypeModel(
      id: (json['id'] ?? 0) as int,
      typeName: (json['account_type'] ?? json['type_name'] ?? 'Unknown Type')
          as String,
      status: json['status'] == true ||
          json['status'] == 1 ||
          (json['status'] == null),
      isSystem: json['is_system'] == true || json['is_system'] == 1,
      organizationId: (json['organization_id'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_type': typeName,
      'status': status,
      'is_system': isSystem,
      'organization_id': organizationId,
    };
  }
}

class AccountCategoryModel extends AccountCategory {
  const AccountCategoryModel({
    required super.id,
    required super.categoryName,
    required super.accountTypeId,
    super.status,
    super.isSystem,
    required super.organizationId,
  });

  factory AccountCategoryModel.fromJson(Map<String, dynamic> json) {
    return AccountCategoryModel(
      id: (json['id'] ?? 0) as int,
      categoryName: (json['category_name'] ??
          json['account_category'] ??
          json['name'] ??
          'Unknown Category') as String,
      accountTypeId: (json['account_type_id'] ?? json['type_id'] ?? 1) as int,
      status: json['status'] == true ||
          json['status'] == 1 ||
          (json['status'] == null), // Default true
      isSystem: json['is_system'] == true || json['is_system'] == 1,
      organizationId: (json['organization_id'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      'account_type_id': accountTypeId,
      'status': status,
      'is_system': isSystem,
      'organization_id': organizationId,
    };
  }
}

class BankCashModel extends BankCash {
  const BankCashModel({
    required super.id,
    required super.name,
    required super.chartOfAccountId,
    super.accountNumber,
    super.branchName,
    required super.organizationId,
    required super.storeId,
    super.status,
    super.openingBalance,
  });

  factory BankCashModel.fromJson(Map<String, dynamic> json) {
    return BankCashModel(
      id: json['id']?.toString() ?? '',
      name: (json['bank_name'] ?? json['name'] ?? '').toString(),
      chartOfAccountId:
          (json['account_id'] ?? json['chart_of_account_id'] ?? '').toString(),
      accountNumber: json['account_number']?.toString(),
      branchName: json['branch_name']?.toString(),
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      status: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['status'] == 1 ||
          json['status'] == true,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory BankCashModel.fromEntity(BankCash entity) {
    return BankCashModel(
      id: entity.id,
      name: entity.name,
      chartOfAccountId: entity.chartOfAccountId,
      accountNumber: entity.accountNumber,
      branchName: entity.branchName,
      organizationId: entity.organizationId,
      storeId: entity.storeId,
      status: entity.status,
      openingBalance: entity.openingBalance,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'bank_name': name,
      'account_id': chartOfAccountId,
      'account_number': accountNumber,
      'branch_name': branchName,
      'organization_id': organizationId,
      'store_id': storeId,
      'is_active': status,
      'opening_balance': openingBalance,
    };
    if (id.isNotEmpty && id != '0') {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toLocalMap() {
    final map = {
      'bank_name': name,
      'account_id': chartOfAccountId,
      'account_number': accountNumber,
      'branch_name': branchName,
      'organization_id': organizationId,
      'store_id': storeId,
      'is_active': status ? 1 : 0,
      'opening_balance': openingBalance,
    };
    if (id.isNotEmpty && id != '0') {
      map['id'] = id;
    }
    return map;
  }

  BankCash toEntity() => this;
}

class VoucherPrefixModel extends VoucherPrefix {
  const VoucherPrefixModel({
    required super.id,
    required super.prefixCode,
    super.description,
    required super.voucherType,
    required super.organizationId,
    super.status,
    super.isSystem,
  });

  factory VoucherPrefixModel.fromJson(Map<String, dynamic> json) {
    return VoucherPrefixModel(
      id: json['id'] as int,
      prefixCode: (json['prefix_code'] ?? json['code'] ?? '') as String,
      description: json['description'] as String?,
      voucherType: (json['voucher_type'] ?? json['type'] ?? '') as String,
      organizationId: (json['organization_id'] as int?) ?? 0,
      status: json['status'] == true || json['status'] == 1,
      isSystem: json['is_system'] == true || json['is_system'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'prefix_code': prefixCode,
      'description': description,
      'voucher_type': voucherType,
      'organization_id': organizationId,
      'status': status,
      'is_system': isSystem,
    };
    if (id != 0) {
      map['id'] = id;
    }
    return map;
  }
}

class FinancialSessionModel extends FinancialSession {
  const FinancialSessionModel({
    super.id,
    required super.sYear,
    required super.startDate,
    required super.endDate,
    super.narration,
    super.inUse,
    super.isActive,
    super.isClosed,
    required super.organizationId,
  });

  factory FinancialSessionModel.fromJson(Map<String, dynamic> json) {
    return FinancialSessionModel(
      // `omtbl_financial_sessions.id` is `bigint`, so PostgREST returns it as
      // a JSON number, not a string. `json['id'] as String?` threw a
      // TypeError on every row, which meant getFinancialSessions() never
      // returned normally — callers only ever saw the caught/swallowed
      // exception, which looks identical to "no sessions" in the UI. Always
      // stringify instead of casting so a numeric id round-trips safely.
      id: json['id']?.toString(),
      sYear: (json['syear'] ?? json['s_year'] ?? json['year']) as int,
      startDate: json['start_date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['start_date'] as int)
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['end_date'] as int)
          : DateTime.parse(json['end_date'] as String),
      narration: json['narration'] as String?,
      inUse: json['in_use'] == true || json['in_use'] == 1,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isClosed: json['is_closed'] == true || json['is_closed'] == 1,
      organizationId: (json['organization_id'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // in_use/is_active/is_closed are smallint columns, not boolean — see
    // OrganizationRepositoryImpl.buildFinancialSessionInsertPayload for the
    // same constraint on the registration-flow insert path. Sending Dart
    // bool literals here is rejected by Postgres.
    final map = <String, dynamic>{
      'syear': sYear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'narration': narration,
      'in_use': inUse ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_closed': isClosed ? 1 : 0,
      'organization_id': organizationId,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'syear': sYear,
      'start_date': startDate.millisecondsSinceEpoch,
      'end_date': endDate.millisecondsSinceEpoch,
      'narration': narration,
      'in_use': inUse ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_closed': isClosed ? 1 : 0,
      'organization_id': organizationId,
    };
  }
}

class InvoiceTypeModel extends InvoiceType {
  const InvoiceTypeModel({
    required super.idInvoiceType,
    required super.description,
    required super.forUsed,
    required super.organizationId,
    super.isActive,
  });

  factory InvoiceTypeModel.fromJson(Map<String, dynamic> json) {
    return InvoiceTypeModel(
      idInvoiceType:
          (json['id_invoice_type'] ?? json['type_id'] ?? json['id'] ?? '')
              .toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      forUsed: (json['for_used'] ?? json['usage'] ?? '').toString(),
      organizationId: (json['organization_id'] as int?) ?? 0,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['status'] == 1 ||
          json['status'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_invoice_type': idInvoiceType,
      'description': description,
      'for_used': forUsed,
      'organization_id': organizationId,
      'is_active': isActive,
    };
  }
}

class InvoiceModel extends Invoice {
  const InvoiceModel({
    required super.id,
    required super.invoiceNumber,
    required super.invoiceDate,
    super.dueDate,
    required super.idInvoiceType,
    required super.businessPartnerId,
    super.orderId,
    super.totalAmount,
    super.paidAmount,
    super.status,
    super.notes,
    required super.organizationId,
    required super.storeId,
    super.sYear,
    super.createdAt,
    super.updatedAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      invoiceDate: json['invoice_date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['invoice_date'] as int)
          : DateTime.parse(json['invoice_date'] as String),
      dueDate: json['due_date'] == null
          ? null
          : (json['due_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['due_date'] as int)
              : DateTime.parse(json['due_date'] as String)),
      idInvoiceType: json['id_invoice_type'] as String,
      businessPartnerId: json['business_partner_id'] as String,
      orderId: json['order_id'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Unpaid',
      notes: json['notes'] as String?,
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      sYear: json['syear'] as int?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'id_invoice_type': idInvoiceType,
      'business_partner_id': businessPartnerId,
      'order_id': orderId,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status,
      'notes': notes,
      'organization_id': organizationId,
      'store_id': storeId,
      'syear': sYear,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'id_invoice_type': idInvoiceType,
      'business_partner_id': businessPartnerId,
      'order_id': orderId,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status,
      'notes': notes,
      'organization_id': organizationId,
      'store_id': storeId,
      'syear': sYear,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
