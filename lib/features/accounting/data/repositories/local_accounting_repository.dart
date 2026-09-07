// lib/features/accounting/data/repositories/local_accounting_repository.dart

import 'package:ordermate/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../models/accounting_models.dart';
import '../models/invoice_item_model.dart';
import '../models/gl_setup_model.dart';
import '../models/daily_balance_model.dart';
import '../../domain/entities/chart_of_account.dart';
import '../models/opening_balance_model.dart';

class LocalAccountingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// SECURITY (OFF-01): `organizationId` is `required` (though still
  /// nullable) so every caller must explicitly state its tenant context.
  /// If none is available, this returns an empty list rather than
  /// removing the organization predicate. The predicate is a strict
  /// equality match -- no `OR organization_id IS NULL` wildcard.
  Future<List<ChartOfAccountModel>> getChartOfAccounts(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];

    final List<Map<String, dynamic>> maps = await db.query(
        'local_chart_of_accounts',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'account_code ASC');
    return maps.map((e) => _mapToModel(e)).toList();
  }

  Future<void> cacheChartOfAccounts(List<ChartOfAccountModel> accounts,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_chart_of_accounts',
            where: 'is_synced = 1 AND organization_id = ?',
            whereArgs: [organizationId]);
      } else {
        await txn.delete('local_chart_of_accounts', where: 'is_synced = 1');
      }
      for (var account in accounts) {
        await txn.insert(
            'local_chart_of_accounts', _modelToMap(account)..['is_synced'] = 1,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveChartOfAccount(ChartOfAccountModel account,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = _modelToMap(account);
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert(
      'local_chart_of_accounts',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// SECURITY (OFF-01): see getChartOfAccounts' doc comment -- same fix
  /// shape (required nullable param, fail-safe empty, strict equality).
  Future<List<PaymentTermModel>> getPaymentTerms(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];

    final maps = await db.query(
      'local_payment_terms',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'payment_term ASC',
    );
    return maps
        .map((e) => PaymentTermModel.fromJson({
              'id': e['id'],
              'payment_term': e['payment_term'],
              'description': e['description'],
              'is_active': e['is_active'] == 1,
              'days': e['days'] ?? 0,
              'organization_id': e['organization_id'],
            }))
        .toList();
  }

  Future<void> cachePaymentTerms(List<PaymentTermModel> terms,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_payment_terms',
            where: 'is_synced = 1 AND organization_id = ?',
            whereArgs: [organizationId]);
      } else {
        await txn.delete('local_payment_terms', where: 'is_synced = 1');
      }
      for (var term in terms) {
        await txn.insert(
            'local_payment_terms',
            {
              'id': term.id,
              'payment_term': term.name,
              'description': term.description,
              'is_active': term.isActive ? 1 : 0,
              'days': term.days,
              'organization_id': term.organizationId,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> savePaymentTerm(PaymentTermModel term,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'payment_term': term.name,
      'description': term.description,
      'is_active': term.isActive ? 1 : 0,
      'days': term.days,
      'organization_id': term.organizationId,
      'is_synced': isSynced ? 1 : 0,
    };
    if (term.id != 0) {
      map['id'] = term.id;
    }
    await db.insert('local_payment_terms', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AccountTypeModel>> getAccountTypes({int? organizationId}) async {
    final db = await _dbHelper.database;
    // User requested to open up Account Types (no org restriction)
    String? where;
    List<dynamic>? whereArgs;

    // if (organizationId != null) {
    //   where = 'organization_id = ? OR organization_id IS NULL';
    //   whereArgs = [organizationId];
    // }

    final maps = await db.query('local_account_types',
        where: where, whereArgs: whereArgs, orderBy: 'id ASC');
    return maps
        .map((e) => AccountTypeModel(
              id: e['id'] as int,
              typeName: e['account_type'] as String,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
              organizationId: (e['organization_id'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<void> saveAccountType(AccountTypeModel type,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_account_types',
        {
          'id': type.id,
          'account_type': type.typeName,
          'organization_id': type.organizationId,
          'status': type.status ? 1 : 0,
          'is_system': type.isSystem ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheAccountTypes(List<AccountTypeModel> types,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Since we are fetching ALL types now, clear ALL synced types to accept the new global list
      await txn.delete('local_account_types', where: 'is_synced = 1');
      
      // if (organizationId != null) {
      //   await txn.delete('local_account_types',
      //       where:
      //           '(organization_id = ? OR organization_id IS NULL) AND is_synced = 1',
      //       whereArgs: [organizationId]);
      // } else {
      //   await txn.delete('local_account_types', where: 'is_synced = 1');
      // }

      for (var type in types) {
        await txn.insert(
            'local_account_types',
            {
              'id': type.id,
              'account_type': type.typeName,
              'organization_id': type.organizationId,
              'status': type.status ? 1 : 0,
              'is_system': type.isSystem ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<AccountCategoryModel>> getAccountCategories(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    // User requested to open up Account Categories (no org restriction)
    String? where;
    List<dynamic>? whereArgs;

    // if (organizationId != null) {
    //   where = 'organization_id = ? OR organization_id IS NULL';
    //   whereArgs = [organizationId];
    // }

    final maps = await db.query('local_account_categories',
        where: where, whereArgs: whereArgs, orderBy: 'category_name ASC');
    return maps
        .map((e) => AccountCategoryModel(
              id: e['id'] as int,
              categoryName: e['category_name'] as String,
              accountTypeId: e['account_type_id'] as int,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
              organizationId: (e['organization_id'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<void> saveAccountCategory(AccountCategoryModel cat,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_account_categories',
        {
          'id': cat.id,
          'category_name': cat.categoryName,
          'account_type_id': cat.accountTypeId,
          'organization_id': cat.organizationId,
          'status': cat.status ? 1 : 0,
          'is_system': cat.isSystem ? 1 : 0,
          'is_synced': isSynced ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AccountCategoryModel>> getUnsyncedAccountCategories(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps = await db.query('local_account_categories',
        where: where, whereArgs: args);
    return maps
        .map((e) => AccountCategoryModel(
              id: e['id'] as int,
              categoryName: e['category_name'] as String,
              accountTypeId: e['account_type_id'] as int,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
              organizationId: (e['organization_id'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<void> markAccountCategoryAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_account_categories', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cacheAccountCategories(List<AccountCategoryModel> categories,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Clear all synced categories as we now fetch global list
      await txn.delete('local_account_categories', where: 'is_synced = 1');
      
      // if (organizationId != null) {
      //   await txn.delete('local_account_categories',
      //       where:
      //           '(organization_id = ? OR organization_id IS NULL) AND is_synced = 1',
      //       whereArgs: [organizationId]);
      // } else {
      //   await txn.delete('local_account_categories', where: 'is_synced = 1');
      // }

      for (var cat in categories) {
        await txn.insert(
            'local_account_categories',
            {
              'id': cat.id,
              'category_name': cat.categoryName,
              'account_type_id': cat.accountTypeId,
              'organization_id': cat.organizationId,
              'status': cat.status ? 1 : 0,
              'is_system': cat.isSystem ? 1 : 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// SECURITY (OFF-01): see getChartOfAccounts' doc comment.
  Future<List<BankCashModel>> getBankCashAccounts(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];

    final maps = await db.query(
      'local_bank_cash',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'bank_name ASC',
    );
    return maps
        .map((e) => BankCashModel(
              id: e['id']?.toString() ?? '',
              name: e['bank_name']?.toString() ?? '',
              chartOfAccountId: e['account_id']?.toString() ?? '',
              accountNumber: e['account_number']?.toString(),
              branchName: e['branch_name']?.toString(),
              organizationId: (e['organization_id'] as int?) ?? 0,
              storeId: (e['store_id'] as int?) ?? 0,
              status: e['is_active'] == 1,
            ))
        .toList();
  }

  Future<void> cacheBankCashAccounts(List<BankCashModel> accounts,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Delete only synced records for this organization to avoid wiping local unsynced work
      if (organizationId != null) {
        await txn.delete('local_bank_cash',
            where:
                'is_synced = 1 AND (organization_id = ? OR organization_id IS NULL)',
            whereArgs: [organizationId]);
      } else {
        await txn.delete('local_bank_cash', where: 'is_synced = 1');
      }

      for (var account in accounts) {
        await txn.insert(
            'local_bank_cash',
            {
              ...account.toLocalMap(),
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveBankCashAccount(BankCashModel account,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_bank_cash',
        {
          ...account.toLocalMap(),
          'is_synced': isSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// SECURITY (OFF-01): see getChartOfAccounts' doc comment.
  Future<List<VoucherPrefixModel>> getVoucherPrefixes(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];

    final maps = await db.query(
      'local_voucher_prefixes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'prefix_code ASC',
    );
    return maps
        .map((e) => VoucherPrefixModel(
              id: e['id'] as int,
              prefixCode: e['prefix_code'] as String,
              description: e['description'] as String?,
              voucherType: e['voucher_type'] as String? ?? 'GENERAL',
              organizationId: (e['organization_id'] as int?) ?? 0,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
            ))
        .toList();
  }

  Future<void> cacheVoucherPrefixes(List<VoucherPrefixModel> prefixes,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_voucher_prefixes',
            where:
                'is_synced = 1 AND (organization_id = ? OR organization_id IS NULL)',
            whereArgs: [organizationId]);
      } else {
        await txn.delete('local_voucher_prefixes', where: 'is_synced = 1');
      }
      for (var prefix in prefixes) {
        await txn.insert(
            'local_voucher_prefixes',
            {
              'id': prefix.id,
              'prefix_code': prefix.prefixCode,
              'description': prefix.description,
              'voucher_type': prefix.voucherType,
              'organization_id': prefix.organizationId,
              'status': prefix.status ? 1 : 0,
              'is_system': prefix.isSystem ? 1 : 0,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveVoucherPrefix(VoucherPrefixModel prefix,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'prefix_code': prefix.prefixCode,
      'description': prefix.description,
      'voucher_type': prefix.voucherType,
      'organization_id': prefix.organizationId,
      'status': prefix.status ? 1 : 0,
      'is_system': prefix.isSystem ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
    if (prefix.id != 0) {
      map['id'] = prefix.id;
    }
    await db.insert('local_voucher_prefixes', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveTransaction(TransactionModel transaction,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_transactions',
        {
          'id': transaction.id,
          'voucher_prefix_id': transaction.voucherPrefixId,
          'voucher_number': transaction.voucherNumber,
          'voucher_date': transaction.voucherDate.millisecondsSinceEpoch,
          'account_id': transaction.accountId,
          'offset_account_id': transaction.offsetAccountId,
          'amount': transaction.amount,
          'description': transaction.description,
          'status': transaction.status,
          'organization_id': transaction.organizationId,
          'store_id': transaction.storeId,
          'syear': transaction.sYear,
          'module_account': transaction.moduleAccount,
          'offset_module_account': transaction.offsetModuleAccount,
          'payment_mode': transaction.paymentMode,
          'reference_number': transaction.referenceNumber,
          'reference_date': transaction.referenceDate?.millisecondsSinceEpoch,
          'reference_bank': transaction.referenceBank,
          'invoice_id': transaction.invoiceId,
          'is_synced': isSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.delete('local_transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// SECURITY (OFF-01): organizationId is `required` (still nullable) so
  /// no caller can silently omit tenant context; no organization id means
  /// no data, not an unfiltered read. The predicate itself was already a
  /// strict equality match (no OR-NULL wildcard existed here).
  Future<List<TransactionModel>> getTransactions(
      {required int? organizationId, int? storeId, int? sYear}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    List<String> whereClauses = ['organization_id = ?'];
    List<dynamic> whereArgs = [organizationId];

    if (storeId != null) {
      whereClauses.add('store_id = ?');
      whereArgs.add(storeId);
    }
    if (sYear != null) {
      whereClauses.add('syear = ?');
      whereArgs.add(sYear);
    }

    final maps = await db.query('local_transactions',
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'voucher_date DESC');

    return maps
        .map((e) => TransactionModel(
              id: e['id'] as String,
              voucherPrefixId: e['voucher_prefix_id'] as int,
              voucherNumber: e['voucher_number'] as String,
              voucherDate:
                  DateTime.fromMillisecondsSinceEpoch(e['voucher_date'] as int),
              accountId: e['account_id'] as String,
              offsetAccountId: e['offset_account_id'] as String?,
              amount: (e['amount'] as num).toDouble(),
              description: e['description'] as String?,
              status: e['status'] as String? ?? 'posted',
              organizationId: (e['organization_id'] as int?) ?? 0,
              storeId: (e['store_id'] as int?) ?? 0,
              sYear: e['syear'] as int?,
              moduleAccount: e['module_account'] as String?,
              offsetModuleAccount: e['offset_module_account'] as String?,
              paymentMode: e['payment_mode'] as String?,
              referenceNumber: e['reference_number'] as String?,
              referenceDate: e['reference_date'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      e['reference_date'] as int)
                  : null,
              referenceBank: e['reference_bank'] as String?,
              invoiceId: e['invoice_id'] as String?,
            ))
        .toList();
  }

  Future<void> cacheTransactions(List<TransactionModel> transactions,
      {int? organizationId, int? storeId, int? sYear}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      String where = 'is_synced = 1';
      List<dynamic> whereArgs = [];

      if (organizationId != null) {
        where += ' AND organization_id = ?';
        whereArgs.add(organizationId);
      }
      if (storeId != null) {
        where += ' AND store_id = ?';
        whereArgs.add(storeId);
      }
      if (sYear != null) {
        where += ' AND syear = ?';
        whereArgs.add(sYear);
      }

      // Only delete if we have at least organizationId constraint to avoid wiping everything
      if (organizationId != null) {
        await txn.delete('local_transactions', where: where, whereArgs: whereArgs);
      }

      for (var tx in transactions) {
        final map = _transactionToMap(tx);
        map['is_synced'] = 1;
        await txn.insert('local_transactions', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Map<String, dynamic> _transactionToMap(TransactionModel tx) {
     final map = tx.toJson();
      // In some models toJson() might not include these or have different names,
      // ensures consistency with the table definition
      map['voucher_date'] = tx.voucherDate.millisecondsSinceEpoch;
      if (tx.referenceDate != null) {
        map['reference_date'] = tx.referenceDate!.millisecondsSinceEpoch;
      }
      // Ensure sYear is present
      map['syear'] = tx.sYear;
      return map;
  }

  // ... (Existing sync methods continue) ...

  // Sync Methods for Transactions
  Future<List<TransactionModel>> getUnsyncedTransactions(
      {int? organizationId, int? storeId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    if (storeId != null) {
      where += ' AND store_id = ?';
      args.add(storeId);
    }
    final maps =
        await db.query('local_transactions', where: where, whereArgs: args);
    return maps
        .map((e) => TransactionModel(
              id: e['id'] as String,
              voucherPrefixId: e['voucher_prefix_id'] as int,
              voucherNumber: e['voucher_number'] as String,
              voucherDate:
                  DateTime.fromMillisecondsSinceEpoch(e['voucher_date'] as int),
              accountId: e['account_id'] as String,
              offsetAccountId: e['offset_account_id'] as String?,
              amount: (e['amount'] as num).toDouble(),
              description: e['description'] as String?,
              status: e['status'] as String? ?? 'posted',
              organizationId: (e['organization_id'] as int?) ?? 0,
              storeId: (e['store_id'] as int?) ?? 0,
              sYear: e['syear'] as int?,
              moduleAccount: e['module_account'] as String?,
              offsetModuleAccount: e['offset_module_account'] as String?,
              paymentMode: e['payment_mode'] as String?,
              referenceNumber: e['reference_number'] as String?,
              referenceDate: e['reference_date'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      e['reference_date'] as int)
                  : null,
              referenceBank: e['reference_bank'] as String?,
              invoiceId: e['invoice_id'] as String?,
            ))
        .toList();
  }

  Future<void> markTransactionAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_transactions', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  ChartOfAccountModel _mapToModel(Map<String, dynamic> e) {
    return ChartOfAccountModel(
      id: e['id'] as String,
      accountCode: e['account_code'] as String,
      accountTitle: e['account_title'] as String,
      parentId: e['parent_id'] as String?,
      level: e['level'] as int,
      accountTypeId: e['account_type_id'] as int?,
      accountCategoryId: e['account_category_id'] as int?,
      organizationId: (e['organization_id'] as int?) ?? 0,
      isActive: e['is_active'] == 1,
      isSystem: e['is_system'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          e['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          e['updated_at'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> _modelToMap(ChartOfAccountModel account) {
    return {
      'id': account.id,
      'account_code': account.accountCode,
      'account_title': account.accountTitle,
      'parent_id': account.parentId,
      'level': account.level,
      'account_type_id': account.accountTypeId,
      'account_category_id': account.accountCategoryId,
      'organization_id': account.organizationId,
      'is_active': account.isActive ? 1 : 0,
      'is_system': account.isSystem ? 1 : 0,
      'created_at': account.createdAt.millisecondsSinceEpoch,
      'updated_at': account.updatedAt.millisecondsSinceEpoch,
    };
  }

  Future<void> deleteChartOfAccount(String id) async {
    final db = await _dbHelper.database;
    // Check if it's a system account before deleting
    final result = await db
        .query('local_chart_of_accounts', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty && result.first['is_system'] == 1) {
      throw Exception('System accounts cannot be deleted');
    }
    await db
        .delete('local_chart_of_accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAccountType(int id) async {
    final db = await _dbHelper.database;
    final result =
        await db.query('local_account_types', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty && result.first['is_system'] == 1) {
      throw Exception('System account types cannot be deleted');
    }
    await db.delete('local_account_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAccountCategory(int id) async {
    final db = await _dbHelper.database;
    final result = await db
        .query('local_account_categories', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty && result.first['is_system'] == 1) {
      throw Exception('System account categories cannot be deleted');
    }
    await db
        .delete('local_account_categories', where: 'id = ?', whereArgs: [id]);
  }

  /// SECURITY (OFF-01): see getChartOfAccounts' doc comment.
  Future<List<FinancialSession>> getFinancialSessions(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];
    final maps = await db.query('local_financial_sessions',
        where: where, whereArgs: whereArgs, orderBy: 'syear DESC');
    return maps
        .map((e) => FinancialSessionModel.fromJson(e))
        .toList()
        .cast<FinancialSession>();
  }

  Future<FinancialSessionModel?> getActiveFinancialSession(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'in_use = 1';
    List<dynamic> whereArgs = [];
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      whereArgs.add(organizationId);
    }
    final maps = await db.query('local_financial_sessions',
        where: where, whereArgs: whereArgs, limit: 1);
    if (maps.isEmpty) return null;
    return FinancialSessionModel.fromJson(maps.first);
  }

  Future<void> cacheFinancialSessions(List<FinancialSessionModel> sessions,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_financial_sessions',
            where: 'organization_id = ?', whereArgs: [organizationId]);
      } else {
        await txn.delete('local_financial_sessions');
      }
      for (var session in sessions) {
        await txn.insert('local_financial_sessions', session.toLocalMap());
      }
    });
  }

  Future<void> saveFinancialSession(FinancialSessionModel session,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = session.toLocalMap();
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert('local_financial_sessions', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// SECURITY (OFF-01): organizationId is `required` (still nullable);
  /// no organization id means no data, not an unfiltered read. The
  /// predicate itself was already a strict equality match.
  Future<List<Map<String, dynamic>>> getUnpaidInvoices(String customerId,
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = "business_partner_id = ? AND status != 'Paid' AND organization_id = ?";
    List<dynamic> whereArgs = [customerId, organizationId];
    return await db.query(
      'local_invoices',
      where: where,
      orderBy: 'invoice_date DESC',
      whereArgs: whereArgs,
    );
  }

  Future<bool> isAccountUsed(String accountId) async {
    final db = await _dbHelper.database;
    final result = await db.query('local_transactions',
        where: 'account_id = ? OR offset_account_id = ?',
        whereArgs: [accountId, accountId],
        limit: 1);
    return result.isNotEmpty;
  }

  Future<bool> isAccountTypeUsed(int typeId) async {
    final db = await _dbHelper.database;
    final result = await db.query('local_chart_of_accounts',
        where: 'account_type_id = ?', whereArgs: [typeId], limit: 1);
    return result.isNotEmpty;
  }

  Future<bool> isAccountCategoryUsed(int categoryId) async {
    final db = await _dbHelper.database;
    final result = await db.query('local_chart_of_accounts',
        where: 'account_category_id = ?', whereArgs: [categoryId], limit: 1);
    return result.isNotEmpty;
  }

  Future<void> deleteVoucherPrefix(int id) async {
    final db = await _dbHelper.database;
    await db.delete('local_voucher_prefixes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePaymentTerm(int id) async {
    final db = await _dbHelper.database;
    await db.delete('local_payment_terms', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBankCashAccount(String id) async {
    final db = await _dbHelper.database;
    await db.delete('local_bank_cash', where: 'id = ?', whereArgs: [id]);
  }

  /// SECURITY (OFF-01): organizationId is `required` (still nullable);
  /// no organization id means no data, not an unfiltered read. The
  /// predicate itself was already a strict equality match.
  Future<List<OpeningBalanceModel>> getOpeningBalances(
      {required int? organizationId, int? sYear}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'organization_id = ?';
    List<dynamic> whereArgs = [organizationId];

    if (sYear != null) {
      where += ' AND syear = ?';
      whereArgs.add(sYear);
    }

    final maps = await db.query(
      'local_opening_balances',
      where: where,
      whereArgs: whereArgs,
    );

    return maps.map((e) => OpeningBalanceModel.fromLocalMap(e)).toList();
  }

  Future<void> saveOpeningBalance(OpeningBalanceModel balance,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = balance.toLocalMap();
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert(
      'local_opening_balances',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isBankCashUsed(String bankCashId) async {
    final db = await _dbHelper.database;
    // Get the account_id (chart_of_account_id) first
    final bc = await db
        .query('local_bank_cash', where: 'id = ?', whereArgs: [bankCashId]);
    if (bc.isEmpty) return false;

    final coaId = bc.first['account_id'] as String;
    return await isAccountUsed(coaId);
  }

  // Invoice Methods
  /// SECURITY (OFF-01): see getChartOfAccounts' doc comment.
  Future<List<InvoiceTypeModel>> getInvoiceTypes(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final whereArgs = [organizationId];

    final maps = await db.query('local_invoice_types',
        where: where, whereArgs: whereArgs, orderBy: 'id_invoice_type ASC');
    return maps.map((e) => InvoiceTypeModel.fromJson(e)).toList();
  }

  Future<void> cacheInvoiceTypes(List<InvoiceTypeModel> types,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_invoice_types',
            where: 'organization_id = ?', whereArgs: [organizationId]);
      } else {
        await txn.delete('local_invoice_types',
            where: 'organization_id IS NULL');
      }
      for (var type in types) {
        final map = type.toJson();
        map['is_active'] = (map['is_active'] == true) ? 1 : 0;
        await txn.insert('local_invoice_types', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveInvoiceType(InvoiceTypeModel type,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = type.toJson();
    map['is_active'] = type.isActive ? 1 : 0;
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert('local_invoice_types', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// SECURITY (OFF-01): see getTransactions' doc comment -- same fix
  /// shape, predicate was already strict.
  Future<List<InvoiceModel>> getInvoices(
      {required int? organizationId, int? storeId, int? sYear}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    List<String> whereClauses = ['organization_id = ?'];
    List<dynamic> whereArgs = [organizationId];

    if (storeId != null) {
      whereClauses.add('store_id = ?');
      whereArgs.add(storeId);
    }
    if (sYear != null) {
      whereClauses.add('syear = ?');
      whereArgs.add(sYear);
    }

    final maps = await db.query('local_invoices',
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'invoice_date DESC');
    return maps.map((e) => InvoiceModel.fromJson(e)).toList();
  }

  Future<void> cacheInvoices(List<InvoiceModel> invoices,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (organizationId != null) {
        await txn.delete('local_invoices',
            where: 'is_synced = 1 AND organization_id = ?',
            whereArgs: [organizationId]);
      } else {
        await txn.delete('local_invoices', where: 'is_synced = 1');
      }
      for (var invoice in invoices) {
        await txn.insert(
            'local_invoices', invoice.toLocalMap()..['is_synced'] = 1,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveInvoice(InvoiceModel invoice,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = invoice.toLocalMap();
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert('local_invoices', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<InvoiceModel>> getUnsyncedInvoices(
      {int? organizationId, int? storeId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    if (storeId != null) {
      where += ' AND store_id = ?';
      args.add(storeId);
    }
    final maps =
        await db.query('local_invoices', where: where, whereArgs: args);
    return maps.map((e) => InvoiceModel.fromJson(e)).toList();
  }

  Future<void> markInvoiceAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_invoices', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_invoices', where: 'id = ?', whereArgs: [id]);
      await txn.delete('local_invoice_items',
          where: 'invoice_id = ?', whereArgs: [id]);
    });
  }

  // Invoice Item Methods
  Future<List<InvoiceItemModel>> getInvoiceItems(String invoiceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return maps.map((e) => InvoiceItemModel.fromJson(e)).toList();
  }

  Future<void> cacheInvoiceItems(
      List<InvoiceItemModel> items, String invoiceId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (var item in items) {
        final map = item.toJson();
        _prepareInvoiceItemMap(map, item);
        await txn.insert('local_invoice_items', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> bulkCacheInvoiceItems(List<InvoiceItemModel> items,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // If we had a way to identify which invoices these items belong to (already in item)
      // we could delete items for those invoices.
      // But clearing all for org might be safer if we are doing a full pull.
      if (organizationId != null) {
        // This is tricky because items table doesn't have organization_id.
        // We might just rely on upsert (ConflictAlgorithm.replace).
      }
      for (var item in items) {
        final map = item.toJson();
        _prepareInvoiceItemMap(map, item);
        await txn.insert('local_invoice_items', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  void _prepareInvoiceItemMap(Map<String, dynamic> map, InvoiceItemModel item) {
    if (map['created_at'] is DateTime) {
      map['created_at'] =
          (map['created_at'] as DateTime).millisecondsSinceEpoch;
    } else if (item.createdAt != null) {
      map['created_at'] = item.createdAt!.millisecondsSinceEpoch;
    }
  }

  Future<void> saveInvoiceItems(List<InvoiceItemModel> items,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var item in items) {
        final map = item.toJson();
        if (item.createdAt != null) {
          map['created_at'] = item.createdAt!.millisecondsSinceEpoch;
        }
        map['is_synced'] = isSynced ? 1 : 0;
        await txn.insert('local_invoice_items', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteInvoiceItems(String invoiceId) async {
    final db = await _dbHelper.database;
    await db.delete('local_invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  // GL Setup Methods
  Future<GLSetupModel?> getGLSetup(int organizationId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_gl_setup',
      where: 'organization_id = ?',
      whereArgs: [organizationId],
    );
    if (maps.isEmpty) return null;
    final map = Map<String, dynamic>.from(maps.first);
    map.remove('is_synced');
    return GLSetupModel.fromJson(map);
  }

  Future<void> saveGLSetup(GLSetupModel setup, {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = setup.toJson();
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert('local_gl_setup', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GLSetupModel>> getUnsyncedGLSetups() async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_gl_setup', where: 'is_synced = 0');
    return maps.map((e) {
      final map = Map<String, dynamic>.from(e);
      map.remove('is_synced');
      return GLSetupModel.fromJson(map);
    }).toList();
  }

  Future<void> markGLSetupAsSynced(int organizationId) async {
    final db = await _dbHelper.database;
    await db.update('local_gl_setup', {'is_synced': 1},
        where: 'organization_id = ?', whereArgs: [organizationId]);
  }

  // Daily Balance Methods
  Future<DailyBalanceModel?> getLatestDailyBalance(String accountId,
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_daily_balances',
      where:
          'account_id = ? ${organizationId != null ? 'AND organization_id = ?' : ''}',
      whereArgs: [accountId, if (organizationId != null) organizationId],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyBalanceModel.fromJson(maps.first);
  }

  Future<void> saveDailyBalance(DailyBalanceModel balance,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = balance.toJson();
    map['is_synced'] = isSynced ? 1 : 0;
    await db.insert('local_daily_balances', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DailyBalanceModel>> getUnsyncedDailyBalances(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps =
        await db.query('local_daily_balances', where: where, whereArgs: args);
    return maps.map((e) => DailyBalanceModel.fromJson(e)).toList();
  }

  Future<void> markDailyBalanceAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_daily_balances', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AccountTypeModel>> getUnsyncedAccountTypes(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps =
        await db.query('local_account_types', where: where, whereArgs: args);
    return maps
        .map((e) => AccountTypeModel(
              id: e['id'] as int,
              typeName: e['account_type'] as String,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
              organizationId: e['organization_id'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> markAccountTypeAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_account_types', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FinancialSessionModel>> getUnsyncedFinancialSessions(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps = await db.query('local_financial_sessions',
        where: where, whereArgs: args);
    return maps.map((e) => FinancialSessionModel.fromJson(e)).toList();
  }

  Future<void> markFinancialSessionAsSynced(int sYear) async {
    final db = await _dbHelper.database;
    await db.update('local_financial_sessions', {'is_synced': 1},
        where: 'syear = ?', whereArgs: [sYear]);
  }

  Future<List<InvoiceTypeModel>> getUnsyncedInvoiceTypes(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps =
        await db.query('local_invoice_types', where: where, whereArgs: args);
    return maps.map((e) => InvoiceTypeModel.fromJson(e)).toList();
  }

  Future<void> markInvoiceTypeAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_invoice_types', {'is_synced': 1},
        where: 'id_invoice_type = ?', whereArgs: [id]);
  }

  Future<List<InvoiceItemModel>> getUnsyncedInvoiceItems() async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_invoice_items', where: 'is_synced = 0');
    return maps.map((e) => InvoiceItemModel.fromJson(e)).toList();
  }

  Future<void> markInvoiceItemAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_invoice_items', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ChartOfAccountModel>> getUnsyncedChartOfAccounts(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps = await db.query('local_chart_of_accounts',
        where: where, whereArgs: args);
    return maps.map((e) => _mapToModel(e)).toList();
  }

  Future<List<PaymentTermModel>> getUnsyncedPaymentTerms(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps =
        await db.query('local_payment_terms', where: where, whereArgs: args);
    return maps
        .map((e) => PaymentTermModel.fromJson({
              'id': e['id'],
              'payment_term': e['payment_term'],
              'description': e['description'],
              'is_active': e['is_active'] == 1,
              'days': e['days'] ?? 0,
              'organization_id': e['organization_id'],
            }))
        .toList();
  }

  Future<List<VoucherPrefixModel>> getUnsyncedVoucherPrefixes(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    final maps =
        await db.query('local_voucher_prefixes', where: where, whereArgs: args);
    return maps
        .map((e) => VoucherPrefixModel(
              id: e['id'] as int,
              prefixCode: e['prefix_code'] as String,
              description: e['description'] as String?,
              voucherType: e['voucher_type'] as String? ?? 'GENERAL',
              organizationId: (e['organization_id'] as int?) ?? 0,
              status: e['status'] == 1,
              isSystem: e['is_system'] == 1,
            ))
        .toList();
  }

  Future<List<BankCashModel>> getUnsyncedBankCashAccounts(
      {int? organizationId, int? storeId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    if (storeId != null) {
      where += ' AND store_id = ?';
      args.add(storeId);
    }
    final maps =
        await db.query('local_bank_cash', where: where, whereArgs: args);
    return maps
        .map((e) => BankCashModel(
              id: e['id']?.toString() ?? '',
              name: e['bank_name']?.toString() ?? '',
              chartOfAccountId: e['account_id']?.toString() ?? '',
              accountNumber: e['account_number']?.toString(),
              branchName: e['branch_name']?.toString(),
              organizationId: (e['organization_id'] as int?) ?? 0,
              storeId: (e['store_id'] as int?) ?? 0,
              status: e['is_active'] == 1,
            ))
        .toList();
  }
}
