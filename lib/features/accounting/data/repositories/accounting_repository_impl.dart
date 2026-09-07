import 'package:flutter/foundation.dart' show debugPrint;
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chart_of_account.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../models/accounting_models.dart';
import '../models/invoice_item_model.dart';
import '../models/gl_setup_model.dart';
import '../models/daily_balance_model.dart';
import '../models/opening_balance_model.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/gl_setup.dart';
import '../../domain/entities/daily_balance.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:ordermate/features/inventory/data/services/inventory_posting_service.dart';
import 'local_accounting_repository.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  final LocalAccountingRepository _localRepo;
  final SupabaseClient _supabase = SupabaseConfig.client;

  AccountingRepositoryImpl(this._localRepo);

  @override
  Future<List<ChartOfAccount>> getChartOfAccounts({int? organizationId}) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepo.getChartOfAccounts(organizationId: organizationId);
    }

    try {
      var query = _supabase.from('omtbl_chart_of_accounts').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      final response = await query
          .order('account_code')
          .timeout(const Duration(seconds: 15));

      final accounts = (response as List)
          .map((e) => ChartOfAccountModel.fromJson(e))
          .toList()
          .cast<ChartOfAccount>();
      await _localRepo.cacheChartOfAccounts(
          accounts.map((e) => e as ChartOfAccountModel).toList(),
          organizationId: organizationId);
      return accounts;
    } catch (e) {
      return _localRepo.getChartOfAccounts(organizationId: organizationId);
    }
  }

  @override
  Future<void> createChartOfAccount(ChartOfAccount account) async {
    final model = ChartOfAccountModel(
      id: account.id,
      accountCode: account.accountCode,
      accountTitle: account.accountTitle,
      parentId: account.parentId,
      level: account.level,
      accountTypeId: account.accountTypeId,
      accountCategoryId: account.accountCategoryId,
      organizationId: account.organizationId,
      isActive: account.isActive,
      isSystem: account.isSystem,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveChartOfAccount(model, isSynced: false);
      return;
    }

    try {
      await _supabase.from('omtbl_chart_of_accounts').upsert(model.toJson());
      await _localRepo.saveChartOfAccount(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveChartOfAccount(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateChartOfAccount(ChartOfAccount account) async {
    final model = ChartOfAccountModel(
      id: account.id,
      accountCode: account.accountCode,
      accountTitle: account.accountTitle,
      parentId: account.parentId,
      level: account.level,
      accountTypeId: account.accountTypeId,
      accountCategoryId: account.accountCategoryId,
      organizationId: account.organizationId,
      isActive: account.isActive,
      isSystem: account.isSystem,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveChartOfAccount(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_chart_of_accounts')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveChartOfAccount(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveChartOfAccount(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<List<AccountType>> getAccountTypes({int? organizationId}) async {
    try {
      // User requested to open up Account Types (no org restriction)
      // var query = _supabase.from('omtbl_account_types').select();
      // if (organizationId != null) {
      //   query = query
      //       .or('organization_id.eq.$organizationId,organization_id.is.null');
      // }
      // final response =
      //     await query.order('id').timeout(const Duration(seconds: 15));

      final response = await _supabase
          .from('omtbl_account_types')
          .select()
          .order('id')
          .timeout(const Duration(seconds: 15));

      final types = (response as List)
          .map((e) => AccountTypeModel.fromJson(e))
          .toList()
          .cast<AccountType>();
      await _localRepo.cacheAccountTypes(
          types.map((e) => e as AccountTypeModel).toList(),
          organizationId: organizationId);
      return types;
    } catch (e) {
      return _localRepo.getAccountTypes(organizationId: organizationId);
    }
  }

  @override
  Future<void> createAccountType(AccountType type) async {
    final model = AccountTypeModel(
      id: type.id,
      typeName: type.typeName,
      status: type.status,
      isSystem: type.isSystem,
      organizationId: type.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveAccountType(model, isSynced: false);
      return;
    }
    try {
      await _supabase.from('omtbl_account_types').upsert(model.toJson());
      await _localRepo.saveAccountType(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveAccountType(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateAccountType(AccountType type) async {
    final model = AccountTypeModel(
      id: type.id,
      typeName: type.typeName,
      status: type.status,
      isSystem: type.isSystem,
      organizationId: type.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveAccountType(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_account_types')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveAccountType(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveAccountType(model, isSynced: false);
    }
  }

  @override
  Future<List<AccountCategory>> getAccountCategories(
      {int? organizationId}) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      return _localRepo.getAccountCategories(organizationId: organizationId);
    }
    try {
      // User requested to open up Account Categories (no org restriction)
      // var query = _supabase.from('omtbl_account_categories').select();
      // if (organizationId != null) {
      //   query = query
      //       .or('organization_id.eq.$organizationId,organization_id.is.null');
      // }
      // final response = await query
      //     .order('category_name')
      //     .timeout(const Duration(seconds: 15));

      final response = await _supabase
          .from('omtbl_account_categories')
          .select()
          .order('category_name')
          .timeout(const Duration(seconds: 15));

      final categories = (response as List)
          .map((e) => AccountCategoryModel.fromJson(e))
          .toList()
          .cast<AccountCategory>();
      await _localRepo.cacheAccountCategories(
          categories.map((e) => e as AccountCategoryModel).toList(),
          organizationId: organizationId);
      return categories;
    } catch (e) {
      return _localRepo.getAccountCategories(organizationId: organizationId);
    }
  }

  @override
  Future<void> createAccountCategory(AccountCategory category) async {
    final model = AccountCategoryModel(
      id: category.id,
      categoryName: category.categoryName,
      accountTypeId: category.accountTypeId,
      status: category.status,
      isSystem: category.isSystem,
      organizationId: category.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveAccountCategory(model, isSynced: false);
      return;
    }
    try {
      await _supabase.from('omtbl_account_categories').upsert(model.toJson());
      await _localRepo.saveAccountCategory(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveAccountCategory(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateAccountCategory(AccountCategory category) async {
    final model = AccountCategoryModel(
      id: category.id,
      categoryName: category.categoryName,
      accountTypeId: category.accountTypeId,
      status: category.status,
      isSystem: category.isSystem,
      organizationId: category.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveAccountCategory(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_account_categories')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveAccountCategory(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveAccountCategory(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> bulkCreateAccountTypes(List<AccountType> types) async {
    final models = types
        .map((e) => AccountTypeModel(
              id: e.id,
              typeName: e.typeName,
              status: e.status,
              isSystem: e.isSystem,
              organizationId: e.organizationId,
            ))
        .toList();

    if (SupabaseConfig.isOfflineLoggedIn) {
      for (var model in models) {
        await _localRepo.saveAccountType(model, isSynced: false);
      }
      return;
    }

    try {
      await _supabase
          .from('omtbl_account_types')
          .upsert(models.map((e) => e.toJson()).toList());
      await _localRepo.cacheAccountTypes(models,
          organizationId: models.firstOrNull?.organizationId);
    } catch (e) {
      for (var model in models) {
        await _localRepo.saveAccountType(model, isSynced: false);
      }
    }
  }

  @override
  Future<void> bulkCreateAccountCategories(
      List<AccountCategory> categories) async {
    final models = categories
        .map((e) => AccountCategoryModel(
              id: e.id,
              categoryName: e.categoryName,
              accountTypeId: e.accountTypeId,
              status: e.status,
              isSystem: e.isSystem,
              organizationId: e.organizationId,
            ))
        .toList();

    if (SupabaseConfig.isOfflineLoggedIn) {
      for (var model in models) {
        await _localRepo.saveAccountCategory(model, isSynced: false);
      }
      return;
    }

    try {
      await _supabase
          .from('omtbl_account_categories')
          .upsert(models.map((e) => e.toJson()).toList());
      await _localRepo.cacheAccountCategories(models,
          organizationId: models.firstOrNull?.organizationId);
    } catch (e) {
      for (var model in models) {
        await _localRepo.saveAccountCategory(model, isSynced: false);
      }
      rethrow;
    }
  }

  @override
  Future<void> bulkCreateChartOfAccounts(List<ChartOfAccount> accounts) async {
    final models = accounts
        .map((e) => ChartOfAccountModel(
              id: e.id,
              accountCode: e.accountCode,
              accountTitle: e.accountTitle,
              parentId: e.parentId,
              level: e.level,
              accountTypeId: e.accountTypeId,
              accountCategoryId: e.accountCategoryId,
              organizationId: e.organizationId,
              isActive: e.isActive,
              isSystem: e.isSystem,
              createdAt: e.createdAt,
              updatedAt: e.updatedAt,
            ))
        .toList();

    if (SupabaseConfig.isOfflineLoggedIn) {
      for (var model in models) {
        await _localRepo.saveChartOfAccount(model, isSynced: false);
      }
      return;
    }

    try {
      await _supabase
          .from('omtbl_chart_of_accounts')
          .upsert(models.map((e) => e.toJson()).toList());
      await _localRepo.cacheChartOfAccounts(models,
          organizationId: models.firstOrNull?.organizationId);
    } catch (e) {
      for (var model in models) {
        await _localRepo.saveChartOfAccount(model, isSynced: false);
      }
    }
  }

  @override
  Future<List<PaymentTerm>> getPaymentTerms({int? organizationId}) async {
    try {
      var query = _supabase.from('omtbl_payment_terms').select();
      if (organizationId != null) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }
      final response = await query.order('payment_term');
      final terms = (response as List)
          .map((e) => PaymentTermModel.fromJson(e))
          .toList()
          .cast<PaymentTerm>();
      await _localRepo.cachePaymentTerms(
          terms.map((e) => e as PaymentTermModel).toList(),
          organizationId: organizationId);
      return terms;
    } catch (e) {
      return _localRepo.getPaymentTerms(organizationId: organizationId);
    }
  }

  @override
  Future<void> createPaymentTerm(PaymentTerm term) async {
    final model = PaymentTermModel(
      id: term.id,
      name: term.name,
      description: term.description,
      isActive: term.isActive,
      days: term.days,
      organizationId: term.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.savePaymentTerm(model, isSynced: false);
      return;
    }

    try {
      await _supabase.from('omtbl_payment_terms').upsert(model.toJson());
      await _localRepo.savePaymentTerm(model, isSynced: true);
    } catch (e) {
      await _localRepo.savePaymentTerm(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updatePaymentTerm(PaymentTerm term) async {
    final model = PaymentTermModel(
      id: term.id,
      name: term.name,
      description: term.description,
      isActive: term.isActive,
      days: term.days,
      organizationId: term.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.savePaymentTerm(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_payment_terms')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.savePaymentTerm(model, isSynced: true);
    } catch (e) {
      await _localRepo.savePaymentTerm(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> createTransaction(Transaction transaction) async {
    final model = TransactionModel(
      id: transaction.id,
      voucherPrefixId: transaction.voucherPrefixId,
      voucherNumber: transaction.voucherNumber,
      voucherDate: transaction.voucherDate,
      accountId: transaction.accountId,
      offsetAccountId: transaction.offsetAccountId,
      amount: transaction.amount,
      description: transaction.description,
      status: transaction.status,
      organizationId: transaction.organizationId,
      storeId: transaction.storeId,
      sYear: transaction.sYear,
      moduleAccount: transaction.moduleAccount,
      offsetModuleAccount: transaction.offsetModuleAccount,
      paymentMode: transaction.paymentMode,
      referenceNumber: transaction.referenceNumber,
      referenceDate: transaction.referenceDate,
      referenceBank: transaction.referenceBank,
      invoiceId: transaction.invoiceId,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveTransaction(model, isSynced: false);
      return;
    }

    try {
      await _supabase.from('omtbl_transactions').upsert(model.toJson());
      await _localRepo.saveTransaction(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveTransaction(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final model = TransactionModel(
      id: transaction.id,
      voucherPrefixId: transaction.voucherPrefixId,
      voucherNumber: transaction.voucherNumber,
      voucherDate: transaction.voucherDate,
      accountId: transaction.accountId,
      offsetAccountId: transaction.offsetAccountId,
      amount: transaction.amount,
      description: transaction.description,
      status: transaction.status,
      organizationId: transaction.organizationId,
      storeId: transaction.storeId,
      sYear: transaction.sYear,
      moduleAccount: transaction.moduleAccount,
      offsetModuleAccount: transaction.offsetModuleAccount,
      paymentMode: transaction.paymentMode,
      referenceNumber: transaction.referenceNumber,
      referenceDate: transaction.referenceDate,
      referenceBank: transaction.referenceBank,
      invoiceId: transaction.invoiceId,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveTransaction(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_transactions')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveTransaction(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveTransaction(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteTransaction(id);
      return;
    }
    try {
      await _supabase.from('omtbl_transactions').delete().eq('id', id);
      await _localRepo.deleteTransaction(id);
    } catch (e) {
      // If we fail to delete online, we should probably not delete local yet or mark for deletion?
      // For now, mirroring other delete methods which try best effort.
      // But unlike inserts, we can't easily "queue" a delete with just save.
      // However, usually we might assume connectivity check.
      // If error is connectivity, we might want to soft delete or similar.
      // For consistency with other methods here:
      await _localRepo.deleteTransaction(id);
      // Wait, if online fails, we delete local? That means next sync it might come back from online?
      // Yes, sync logic usually handles this direction or we need a proper sync queue.
      // Current pattern in this file for delete is: try online, if err, do local.
      // Actually look at deleteChartOfAccount:
      /*
      try {
        await _supabase...
        await _localRepo...
      } catch (e) {
        rethrow;
      }
      */
      // Wait, deleteChartOfAccount in this file rethrows!
      // But deleteBankCashAccount does NOT rethrow in catch block.
      // deleteAccountType rethrows.
      // deleteVoucherPrefix does NOT rethrow.
      // Inconsistent. I will follow deleteBankCashAccount pattern (try best effort) or rethrow if it's critical.
      // Given the user wants to be able to delete, I'll delete local regardless so UI updates.
      // But really we should rethrow if online fails so user knows it's not fully gone?
      // Let's stick to safe pattern: rethrow if online fails so we don't have zombie data coming back.
      rethrow;
    }
  }

  @override
  Future<List<Transaction>> getTransactions(
      {int? organizationId, int? storeId, int? sYear}) async {
    try {
      var query = _supabase.from('omtbl_transactions').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (storeId != null) query = query.eq('store_id', storeId);
      if (sYear != null) query = query.eq('syear', sYear);
      final response = await query
          .order('voucher_date', ascending: false)
          .timeout(const Duration(seconds: 15));
      final txs =
          (response as List).map((e) => TransactionModel.fromJson(e)).toList();

      // CACHE LOCALLY
      await _localRepo.cacheTransactions(txs,
          organizationId: organizationId, storeId: storeId, sYear: sYear);

      return txs.cast<Transaction>();
    } catch (e) {
      return _localRepo
          .getTransactions(
              organizationId: organizationId, storeId: storeId, sYear: sYear)
          .then((list) => list.cast<Transaction>());
    }
  }

  @override
  Future<List<BankCash>> getBankCashAccounts({int? organizationId}) async {
    try {
      var query = _supabase.from('omtbl_bank_cash').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      final response = await query
          .order('bank_name')
          .timeout(const Duration(seconds: 15));

      // DEBUG LOG
      print(
          'DEBUGGING_BANK_CASH: Fetched ${response.length} accounts: ${response.map((e) => "${e['bank_name']} (Org: ${e['organization_id']})").toList()}');

      final accounts = (response as List)
          .map((e) => BankCashModel.fromJson(e))
          .toList()
          .cast<BankCash>();
      await _localRepo.cacheBankCashAccounts(
          accounts.map((e) => BankCashModel.fromEntity(e)).toList(),
          organizationId: organizationId);
      return accounts;
    } catch (e) {
      print('DEBUGGING_BANK_CASH: Error fetching accounts: $e');
      return _localRepo
          .getBankCashAccounts(organizationId: organizationId)
          .then((list) => list.cast<BankCash>());
    }
  }

  @override
  Future<void> createBankCashAccount(BankCash account) async {
    final model = BankCashModel(
      id: account.id,
      name: account.name,
      chartOfAccountId: account.chartOfAccountId,
      accountNumber: account.accountNumber,
      branchName: account.branchName,
      organizationId: account.organizationId,
      storeId: account.storeId,
      status: account.status,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveBankCashAccount(model, isSynced: false);
      return;
    }

    try {
      await _supabase.from('omtbl_bank_cash').upsert(model.toJson());
      await _localRepo.saveBankCashAccount(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveBankCashAccount(model, isSynced: false);
    }
  }

  @override
  Future<void> updateBankCashAccount(BankCash account) async {
    final model = BankCashModel(
      id: account.id,
      name: account.name,
      chartOfAccountId: account.chartOfAccountId,
      accountNumber: account.accountNumber,
      branchName: account.branchName,
      organizationId: account.organizationId,
      storeId: account.storeId,
      status: account.status,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveBankCashAccount(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_bank_cash')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveBankCashAccount(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveBankCashAccount(model, isSynced: false);
    }
  }

  @override
  Future<void> deleteBankCashAccount(String id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteBankCashAccount(id);
      return;
    }
    try {
      await _supabase.from('omtbl_bank_cash').delete().eq('id', id);
      await _localRepo.deleteBankCashAccount(id);
    } catch (e) {
      await _localRepo.deleteBankCashAccount(id);
    }
  }

  @override
  Future<bool> isBankCashUsed(String bankCashId) {
    return _localRepo.isBankCashUsed(bankCashId);
  }

  @override
  Future<List<VoucherPrefix>> getVoucherPrefixes({int? organizationId}) async {
    try {
      var query = _supabase.from('omtbl_voucher_prefixes').select(
          'id, prefix_code, description, voucher_type, organization_id, status, is_system');
      if (organizationId != null) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }
      final response = await query.order('prefix_code');
      final prefixes = (response as List)
          .map((e) => VoucherPrefixModel.fromJson(e))
          .toList()
          .cast<VoucherPrefix>();
      await _localRepo.cacheVoucherPrefixes(
          prefixes.map((e) => e as VoucherPrefixModel).toList(),
          organizationId: organizationId);
      return prefixes;
    } catch (e) {
      print('Error fetching voucher prefixes: $e');
      return _localRepo
          .getVoucherPrefixes(organizationId: organizationId)
          .then((list) => list.cast<VoucherPrefix>());
    }
  }

  @override
  Future<void> createVoucherPrefix(VoucherPrefix prefix) async {
    final model = VoucherPrefixModel(
      id: prefix.id,
      prefixCode: prefix.prefixCode,
      description: prefix.description,
      voucherType: prefix.voucherType,
      organizationId: prefix.organizationId,
      status: prefix.status,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveVoucherPrefix(model, isSynced: false);
      return;
    }
    try {
      await _supabase.from('omtbl_voucher_prefixes').upsert(model.toJson());
      await _localRepo.saveVoucherPrefix(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveVoucherPrefix(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateVoucherPrefix(VoucherPrefix prefix) async {
    final model = VoucherPrefixModel(
      id: prefix.id,
      prefixCode: prefix.prefixCode,
      description: prefix.description,
      voucherType: prefix.voucherType,
      organizationId: prefix.organizationId,
      status: prefix.status,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveVoucherPrefix(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_voucher_prefixes')
          .update(model.toJson())
          .eq('id', model.id);
      await _localRepo.saveVoucherPrefix(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveVoucherPrefix(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> deleteChartOfAccount(String id) async {
    // Check if used locally first (optional optimization)
    // We should probably check usage before deletion regardless of online/offline status if it enforces integrity
    final isUsed = await _localRepo.isAccountUsed(id);
    if (isUsed) {
      throw Exception('Account is in use and cannot be deleted');
    }

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteChartOfAccount(id);
      return;
    }

    try {
      await _supabase.from('omtbl_chart_of_accounts').delete().eq('id', id);
      await _localRepo.deleteChartOfAccount(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAccountType(int id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteAccountType(id);
      return;
    }
    try {
      await _supabase.from('omtbl_account_types').delete().eq('id', id);
      await _localRepo.deleteAccountType(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAccountCategory(int id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteAccountCategory(id);
      return;
    }
    try {
      await _supabase.from('omtbl_account_categories').delete().eq('id', id);
      await _localRepo.deleteAccountCategory(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<FinancialSession>> getFinancialSessions(
      {int? organizationId}) async {
    try {
      debugPrint(
        '[DIAG][getFinancialSessions] '
        'userId=${SupabaseConfig.client.auth.currentUser?.id} '
        'sessionNull=${SupabaseConfig.client.auth.currentSession == null} '
        'expiresAt=${SupabaseConfig.client.auth.currentSession?.expiresAt} '
        'now=${DateTime.now().millisecondsSinceEpoch}',
      );
      var query = _supabase.from('omtbl_financial_sessions').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      final response = await query
          .order('syear', ascending: false)
          .timeout(const Duration(seconds: 15));
      final sessions = (response as List)
          .map((e) => FinancialSessionModel.fromJson(e))
          .toList()
          .cast<FinancialSession>();
      await _localRepo.cacheFinancialSessions(
          sessions.cast<FinancialSessionModel>(),
          organizationId: organizationId);
      return sessions;
    } catch (e) {
      // PROVISIONAL DEBUGGING: Rethrow to see error in UI
      print('DEBUG: getFinancialSessions error: $e');
      // Try local as fallback, but if local is empty and we had an error, we might want to know.
      // For now, let's rethrow if connectivity is present? No, standard pattern is fallback.
      // But user says "no record displayed". 
      // I will add a print and then fallback. But since I can't see print, I will throw.
      throw Exception('Failed to fetch financial sessions: $e');
      // return _localRepo.getFinancialSessions(organizationId: organizationId);
    }
  }

  @override
  Future<FinancialSession?> getActiveFinancialSession({int? organizationId}) {
    return _localRepo.getActiveFinancialSession(organizationId: organizationId);
  }

  @override
  Future<void> createFinancialSession(FinancialSession session) async {
    final model = FinancialSessionModel(
      sYear: session.sYear,
      startDate: session.startDate,
      endDate: session.endDate,
      narration: session.narration,
      inUse: session.inUse,
      isActive: session.isActive,
      organizationId: session.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveFinancialSession(model, isSynced: false);
      return;
    }
    try {
      await _supabase.from('omtbl_financial_sessions').upsert(model.toJson());
      await _localRepo.saveFinancialSession(model, isSynced: true);
    } catch (e) {
      // Matches the createChartOfAccount/etc. pattern above: keep the
      // optimistic local write for offline support, but the caller must
      // still see the failure — a swallowed error here is exactly how
      // "financial session missing" defects went unnoticed before.
      await _localRepo.saveFinancialSession(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateFinancialSession(FinancialSession session) async {
    final model = FinancialSessionModel(
      sYear: session.sYear,
      startDate: session.startDate,
      endDate: session.endDate,
      narration: session.narration,
      inUse: session.inUse,
      isActive: session.isActive,
      organizationId: session.organizationId,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveFinancialSession(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_financial_sessions')
          .update(model.toJson())
          .eq('syear', model.sYear);
      await _localRepo.saveFinancialSession(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveFinancialSession(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<bool> isAccountUsed(String accountId) {
    return _localRepo.isAccountUsed(accountId);
  }

  @override
  Future<bool> isAccountTypeUsed(int typeId) {
    return _localRepo.isAccountTypeUsed(typeId);
  }

  @override
  Future<bool> isAccountCategoryUsed(int categoryId) {
    return _localRepo.isAccountCategoryUsed(categoryId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUnpaidInvoices(String customerId,
      {int? organizationId}) {
    return _localRepo.getUnpaidInvoices(customerId,
        organizationId: organizationId);
  }

  @override
  Future<void> deleteVoucherPrefix(int id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteVoucherPrefix(id);
      return;
    }
    try {
      await _supabase.from('omtbl_voucher_prefixes').delete().eq('id', id);
      await _localRepo.deleteVoucherPrefix(id);
    } catch (e) {
      await _localRepo.deleteVoucherPrefix(id);
    }
  }

  @override
  Future<void> deletePaymentTerm(int id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deletePaymentTerm(id);
      return;
    }
    try {
      await _supabase.from('omtbl_payment_terms').delete().eq('id', id);
      await _localRepo.deletePaymentTerm(id);
    } catch (e) {
      await _localRepo.deletePaymentTerm(id);
    }
  }

  @override
  Future<List<InvoiceType>> getInvoiceTypes({int? organizationId}) async {
    try {
      var query = _supabase.from('omtbl_invoice_types').select();
      if (organizationId != null) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }
      final response = await query
          .order('id_invoice_type')
          .timeout(const Duration(seconds: 15));
      final types = (response as List)
          .map((e) => InvoiceTypeModel.fromJson(e))
          .toList()
          .cast<InvoiceType>();
      await _localRepo.cacheInvoiceTypes(
          types.map((e) => e as InvoiceTypeModel).toList(),
          organizationId: organizationId);
      return types;
    } catch (e) {
      return _localRepo
          .getInvoiceTypes(organizationId: organizationId)
          .then((list) => list.cast<InvoiceType>());
    }
  }

  @override
  Future<void> createInvoiceType(InvoiceType type) async {
    final model = InvoiceTypeModel(
      idInvoiceType: type.idInvoiceType,
      description: type.description,
      forUsed: type.forUsed,
      organizationId: type.organizationId,
      isActive: type.isActive,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveInvoiceType(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_invoice_types')
          .upsert(model.toJson())
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveInvoiceType(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveInvoiceType(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<List<Invoice>> getInvoices(
      {int? organizationId, int? storeId, int? sYear}) async {
    try {
      var query = _supabase.from('omtbl_invoices').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (storeId != null) query = query.eq('store_id', storeId);
      if (sYear != null) query = query.eq('syear', sYear);
      final response = await query
          .order('invoice_date', ascending: false)
          .timeout(const Duration(seconds: 15));
      final invoices = (response as List)
          .map((e) => InvoiceModel.fromJson(e))
          .toList()
          .cast<Invoice>();
      await _localRepo.cacheInvoices(
          invoices.map((e) => e as InvoiceModel).toList(),
          organizationId: organizationId);
      return invoices;
    } catch (e) {
      // Note: LocalRepo needs to be updated to support sYear too, or we filter here if strictly necessary
      // For now passing it if supported or ignoring silently if not (checking local repo next step)
      return _localRepo
          .getInvoices(
              organizationId: organizationId, storeId: storeId, sYear: sYear)
          .then((list) => list.cast<Invoice>());
    }
  }

  @override
  Future<void> createInvoice(Invoice invoice) async {
    final model = InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      dueDate: invoice.dueDate,
      idInvoiceType: invoice.idInvoiceType,
      businessPartnerId: invoice.businessPartnerId,
      orderId: invoice.orderId,
      totalAmount: invoice.totalAmount,
      paidAmount: invoice.paidAmount,
      status: invoice.status,
      notes: invoice.notes,
      organizationId: invoice.organizationId,
      storeId: invoice.storeId,
      sYear: invoice.sYear,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveInvoice(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_invoices')
          .upsert(model.toJson())
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveInvoice(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveInvoice(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> updateInvoice(Invoice invoice) async {
    final model = InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      dueDate: invoice.dueDate,
      idInvoiceType: invoice.idInvoiceType,
      businessPartnerId: invoice.businessPartnerId,
      orderId: invoice.orderId,
      totalAmount: invoice.totalAmount,
      paidAmount: invoice.paidAmount,
      status: invoice.status,
      notes: invoice.notes,
      organizationId: invoice.organizationId,
      storeId: invoice.storeId,
      sYear: invoice.sYear,
    );
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveInvoice(model, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_invoices')
          .update(model.toJson())
          .eq('id', model.id)
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveInvoice(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveInvoice(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> createInvoiceWithItems(
      Invoice invoice, List<InvoiceItem> items) async {
    await createInvoice(invoice);
    await createInvoiceItems(items);

    final postingService = InventoryPostingService();
    final orgId = invoice.organizationId;
    final storeId = invoice.storeId;
    final invoiceId = invoice.id;
    final type = invoice.idInvoiceType.toUpperCase();

    if (type == 'PI') {
      for (final item in items) {
        await postingService.postPurchaseInvoice(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'SI') {
      for (final item in items) {
        await postingService.postSalesInvoice(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'PIR') {
      for (final item in items) {
        await postingService.postPurchaseInvoiceReturn(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'SIR') {
      for (final item in items) {
        await postingService.postSalesInvoiceReturn(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    }
  }

  @override
  Future<void> updateInvoiceWithItems(
      Invoice invoice, List<InvoiceItem> items) async {
    await updateInvoice(invoice);
    await deleteInvoiceItems(invoice.id);
    await createInvoiceItems(items);

    final postingService = InventoryPostingService();
    final orgId = invoice.organizationId;
    final storeId = invoice.storeId;
    final invoiceId = invoice.id;
    final type = invoice.idInvoiceType.toUpperCase();

    await _supabase
        .from('omtbl_inventory_movements')
        .delete()
        .eq('reference_table', 'omtbl_invoices')
        .eq('reference_id', invoiceId)
        .timeout(const Duration(seconds: 15));

    if (type == 'PI') {
      for (final item in items) {
        await postingService.postPurchaseInvoice(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'SI') {
      for (final item in items) {
        await postingService.postSalesInvoice(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'PIR') {
      for (final item in items) {
        await postingService.postPurchaseInvoiceReturn(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    } else if (type == 'SIR') {
      for (final item in items) {
        await postingService.postSalesInvoiceReturn(
          organizationId: orgId,
          invoiceId: invoiceId,
          productId: item.productId,
          storeId: storeId,
          quantity: item.quantity,
        );
      }
    }
  }

  @override
  Future<void> deleteInvoice(String id) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteInvoice(id);
      return;
    }
    try {
      await _supabase
          .from('omtbl_inventory_movements')
          .delete()
          .eq('reference_table', 'omtbl_invoices')
          .eq('reference_id', id)
          .timeout(const Duration(seconds: 15));
      await _supabase
          .from('omtbl_invoice_items')
          .delete()
          .eq('invoice_id', id)
          .timeout(const Duration(seconds: 15));
      await _supabase
          .from('omtbl_invoices')
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 15));
      await _localRepo.deleteInvoice(id);
    } catch (e) {
      await _localRepo.deleteInvoice(id);
      rethrow;
    }
  }

  @override
  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    try {
      final response = await _supabase
          .from('omtbl_invoice_items')
          .select()
          .eq('invoice_id', invoiceId)
          .timeout(const Duration(seconds: 15));

      final items =
          (response as List).map((e) => InvoiceItemModel.fromJson(e)).toList();
      await _localRepo.cacheInvoiceItems(items, invoiceId);
      return items;
    } catch (e) {
      return _localRepo.getInvoiceItems(invoiceId);
    }
  }

  @override
  Future<List<InvoiceItem>> getInvoiceItemsByOrg(int organizationId) async {
    try {
      // Join with invoices to filter by organization
      final response = await _supabase
          .from('omtbl_invoice_items')
          .select('*, omtbl_invoices!inner(organization_id)')
          .eq('omtbl_invoices.organization_id', organizationId)
          .timeout(const Duration(seconds: 15));

      final items =
          (response as List).map((e) => InvoiceItemModel.fromJson(e)).toList();
      await _localRepo.bulkCacheInvoiceItems(items,
          organizationId: organizationId);
      return items;
    } catch (e) {
      // local repository doesn't have by-org getter for items yet, return empty or all?
      // For sync purposes, we usually just want to fill the cache.
      return [];
    }
  }

  @override
  Future<void> createInvoiceItems(List<InvoiceItem> items) async {
    if (items.isEmpty) return;
    final models = items.map((e) => InvoiceItemModel.fromEntity(e)).toList();
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveInvoiceItems(models, isSynced: false);
      return;
    }
    try {
      await _supabase
          .from('omtbl_invoice_items')
          .upsert(models.map((e) => e.toJson()).toList())
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveInvoiceItems(models, isSynced: true);
    } catch (e) {
      await _localRepo.saveInvoiceItems(models, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> deleteInvoiceItems(String invoiceId) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.deleteInvoiceItems(invoiceId);
      return;
    }
    try {
      await _supabase
          .from('omtbl_invoice_items')
          .delete()
          .eq('invoice_id', invoiceId)
          .timeout(const Duration(seconds: 15));
      await _localRepo.deleteInvoiceItems(invoiceId);
    } catch (e) {
      await _localRepo.deleteInvoiceItems(invoiceId);
      rethrow;
    }
  }

  @override
  Future<GLSetup?> getGLSetup(int organizationId) async {
    if (SupabaseConfig.isOfflineLoggedIn) {
      return _localRepo.getGLSetup(organizationId);
    }
    try {
      final response = await _supabase
          .from('omtbl_gl_setup')
          .select()
          .eq('organization_id', organizationId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
        return _localRepo.getGLSetup(organizationId);
      }

      final setup = GLSetupModel.fromJson(response);
      await _localRepo.saveGLSetup(setup, isSynced: true);
      return setup;
    } catch (e) {
      return _localRepo.getGLSetup(organizationId);
    }
  }

  @override
  Future<void> saveGLSetup(GLSetup setup) async {
    final model = GLSetupModel.fromEntity(setup);

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveGLSetup(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_gl_setup')
          .upsert(model.toJson())
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveGLSetup(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveGLSetup(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<DailyBalance?> getLatestDailyBalance(String accountId,
      {int? organizationId}) async {
    try {
      var query = _supabase
          .from('omtbl_daily_balances')
          .select()
          .eq('account_id', accountId);

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (response == null) {
        return _localRepo.getLatestDailyBalance(accountId,
            organizationId: organizationId);
      }

      final balance = DailyBalanceModel.fromJson(response);
      await _localRepo.saveDailyBalance(balance);
      return balance;
    } catch (e) {
      return _localRepo.getLatestDailyBalance(accountId,
          organizationId: organizationId);
    }
  }

  @override
  Future<void> saveDailyBalance(DailyBalance balance) async {
    final model = DailyBalanceModel.fromEntity(balance);
    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveDailyBalance(model, isSynced: false);
      return;
    }

    try {
      await _supabase
          .from('omtbl_daily_balances')
          .upsert(model.toJson())
          .timeout(const Duration(seconds: 15));
      await _localRepo.saveDailyBalance(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveDailyBalance(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<List<OpeningBalance>> getOpeningBalances(
      {int? organizationId, int? sYear}) async {
    try {
      var query = _supabase.from('omtbl_opening_balances').select();
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (sYear != null) {
        query = query.eq('syear', sYear);
      }
      
      final response = await query.timeout(const Duration(seconds: 15));
      final balances = ((response as List?) ?? [])
          .map((e) => OpeningBalanceModel.fromJson(e))
          .toList();

      for (var balance in balances) {
        await _localRepo.saveOpeningBalance(balance, isSynced: true);
      }
      return balances;
    } catch (e) {
      return (await _localRepo.getOpeningBalances(
              organizationId: organizationId, sYear: sYear))
          .cast<OpeningBalance>();
    }
  }

  @override
  Future<void> saveOpeningBalance(OpeningBalance balance) async {
    final model = OpeningBalanceModel(
      id: balance.id,
      sYear: balance.sYear,
      amount: balance.amount,
      entityId: balance.entityId,
      entityType: balance.entityType,
      organizationId: balance.organizationId,
      createdAt: balance.createdAt,
      updatedAt: balance.updatedAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepo.saveOpeningBalance(model, isSynced: false);
      return;
    }

    try {
      await _supabase.from('omtbl_opening_balances').upsert(model.toJson());
      await _localRepo.saveOpeningBalance(model, isSynced: true);
    } catch (e) {
      await _localRepo.saveOpeningBalance(model, isSynced: false);
      rethrow;
    }
  }
}
