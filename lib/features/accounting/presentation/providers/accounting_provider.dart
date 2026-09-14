// lib/features/accounting/presentation/providers/accounting_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/chart_of_account.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/gl_setup.dart';
import '../../domain/entities/daily_balance.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';
import '../../data/repositories/local_accounting_repository.dart';

import '../../data/services/accounting_setup_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

import 'package:uuid/uuid.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/services/subscription_service.dart';

final localAccountingRepositoryProvider =
    Provider<LocalAccountingRepository>((ref) {
  return LocalAccountingRepository();
});

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  final localRepo = ref.watch(localAccountingRepositoryProvider);
  return AccountingRepositoryImpl(localRepo);
});

final accountingSetupServiceProvider = Provider<AccountingSetupService>((ref) {
  final repo = ref.watch(accountingRepositoryProvider);
  return AccountingSetupService(repo);
});

class AccountingState {
  final List<ChartOfAccount> accounts;
  final List<AccountType> types;
  final List<AccountCategory> categories;
  final List<PaymentTerm> paymentTerms;
  final List<Transaction> transactions;
  final List<BankCash> bankCashAccounts;
  final List<VoucherPrefix> voucherPrefixes;
  final List<FinancialSession> financialSessions;
  final List<InvoiceType> invoiceTypes;
  final List<Invoice> invoices;
  final List<InvoiceItem> currentInvoiceItems;
  final GLSetup? glSetup;
  final DailyBalance? currentDailyBalance;
  final FinancialSession? selectedFinancialSession;
  final bool isLoading;
  final String? error;

  AccountingState({
    this.accounts = const [],
    this.types = const [],
    this.categories = const [],
    this.paymentTerms = const [],
    this.transactions = const [],
    this.bankCashAccounts = const [],
    this.voucherPrefixes = const [],
    this.financialSessions = const [],
    this.invoiceTypes = const [],
    this.invoices = const [],
    this.currentInvoiceItems = const [],
    this.glSetup,
    this.currentDailyBalance,
    this.selectedFinancialSession,
    this.isLoading = false,
    this.error,
  });

  AccountingState copyWith({
    List<ChartOfAccount>? accounts,
    List<AccountType>? types,
    List<AccountCategory>? categories,
    List<PaymentTerm>? paymentTerms,
    List<Transaction>? transactions,
    List<BankCash>? bankCashAccounts,
    List<VoucherPrefix>? voucherPrefixes,
    List<FinancialSession>? financialSessions,
    List<InvoiceType>? invoiceTypes,
    List<Invoice>? invoices,
    List<InvoiceItem>? currentInvoiceItems,
    GLSetup? glSetup,
    DailyBalance? currentDailyBalance,
    FinancialSession? selectedFinancialSession,
    bool? isLoading,
    String? error,
  }) {
    return AccountingState(
      accounts: accounts ?? this.accounts,
      types: types ?? this.types,
      categories: categories ?? this.categories,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      transactions: transactions ?? this.transactions,
      bankCashAccounts: bankCashAccounts ?? this.bankCashAccounts,
      voucherPrefixes: voucherPrefixes ?? this.voucherPrefixes,
      financialSessions: financialSessions ?? this.financialSessions,
      invoiceTypes: invoiceTypes ?? this.invoiceTypes,
      invoices: invoices ?? this.invoices,
      currentInvoiceItems: currentInvoiceItems ?? this.currentInvoiceItems,
      glSetup: glSetup ?? this.glSetup,
      currentDailyBalance: currentDailyBalance ?? this.currentDailyBalance,
      selectedFinancialSession:
          selectedFinancialSession ?? this.selectedFinancialSession,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AccountingNotifier extends StateNotifier<AccountingState> {
  final AccountingRepository _repository;
  final Ref _ref;

  AccountingNotifier(this._repository, this._ref) : super(AccountingState()) {
    _listenToSync();
  }

  void _listenToSync() {
    _ref.listen<SyncStatus>(syncProgressProvider, (previous, next) async {
      if (previous?.isSyncing == true && next.isSyncing == false) {
        if (!mounted) return;

        final orgId = _ref.read(organizationProvider).selectedOrganizationId;
        final storeId = _ref.read(organizationProvider).selectedStore?.id;
        final sYear = state.selectedFinancialSession?.sYear;

        if (orgId != null) {
          await loadTransactions(
              organizationId: orgId, storeId: storeId, sYear: sYear);
          await loadInvoices(
              organizationId: orgId, storeId: storeId, sYear: sYear);
        }
      }
    });
  }

  Future<void> loadAll({int? organizationId}) async {
    final orgId = organizationId ??
        _ref.read(organizationProvider).selectedOrganizationId;
    
    // Preserve the currently selected session
    final currentSession = state.selectedFinancialSession;
    final sYear = currentSession?.sYear ??
        _ref.read(organizationProvider).selectedFinancialYear;

    state = state.copyWith(isLoading: true, error: null);
    
    try {
      debugPrint('AccountingNotifier: Loading all metadata for org $orgId, year $sYear');
      
      final results = await Future.wait([
        _repository.getChartOfAccounts(organizationId: orgId).catchError((e) {
          debugPrint('Error loading accounts: $e');
          return <ChartOfAccount>[];
        }),
        _repository.getAccountTypes(organizationId: orgId).catchError((e) {
          debugPrint('Error loading account types: $e');
          return <AccountType>[];
        }),
        _repository.getAccountCategories(organizationId: orgId).catchError((e) {
          debugPrint('Error loading account categories: $e');
          return <AccountCategory>[];
        }),
        _repository.getPaymentTerms(organizationId: orgId).catchError((e) {
          debugPrint('Error loading payment terms: $e');
          return <PaymentTerm>[];
        }),
        _repository.getBankCashAccounts(organizationId: orgId).catchError((e) {
          debugPrint('Error loading bank/cash: $e');
          return <BankCash>[];
        }),
        _repository.getVoucherPrefixes(organizationId: orgId).catchError((e) {
          debugPrint('Error loading voucher prefixes: $e');
          return <VoucherPrefix>[];
        }),
        _repository.getFinancialSessions(organizationId: orgId).catchError((e) {
          debugPrint('Error loading financial sessions: $e');
          return <FinancialSession>[];
        }),
        _repository.getInvoiceTypes(organizationId: orgId).catchError((e) {
          debugPrint('Error loading invoice types: $e');
          return <InvoiceType>[];
        }),
        _repository.getGLSetup(orgId ?? 0).catchError((e) {
          debugPrint('Error loading GL Setup: $e');
          return null;
        }),
        (sYear != null
                ? _repository.getOpeningBalances(
                    organizationId: orgId, sYear: sYear)
                : Future.value(<OpeningBalance>[]))
            .catchError((e) {
          debugPrint('Error loading opening balances: $e');
          return <OpeningBalance>[];
        }),
      ]);

      if (!mounted) return;

      final loadedSessions = List<FinancialSession>.from(results[6] as Iterable);
      final persistedYear = _ref.read(organizationProvider).selectedFinancialYear;
      
      debugPrint('AccountingNotifier: Loaded ${loadedSessions.length} financial sessions');

      // Restore/resolve the selected session. Delegates to
      // FinancialSession.resolveDefault so this stays in lockstep with
      // WorkspaceSelectionScreen's identical need to pick a session — two
      // independent implementations of "pick the current session" is how
      // they drift and one silently overrides the other's correct pick.
      final restoredSession = FinancialSession.resolveDefault(
        loadedSessions,
        persistedSyear: currentSession?.sYear ?? persistedYear,
      );

      final rawAccounts = List<ChartOfAccount>.from(results[0] as Iterable);
      final openingBalances = List<OpeningBalance>.from(results[9] as Iterable);

      final mergedAccounts = rawAccounts.map((a) {
        final bal = openingBalances
            .where((b) => b.entityId == a.id && b.entityType == 'Account')
            .firstOrNull;
        return bal != null ? a.copyWith(openingBalance: bal.amount) : a;
      }).toList();
      
      final rawBankCash = List<BankCash>.from(results[4] as Iterable);
      final mergedBankCash = rawBankCash.map((b) {
         final bal = openingBalances
            .where((ob) => ob.entityId == b.id && ob.entityType == 'BankCash')
            .firstOrNull;
         return bal != null ? b.copyWith(openingBalance: bal.amount) : b;
      }).toList();

      state = state.copyWith(
        accounts: mergedAccounts,
        types: List<AccountType>.from(results[1] as Iterable),
        categories: List<AccountCategory>.from(results[2] as Iterable),
        paymentTerms: List<PaymentTerm>.from(results[3] as Iterable),
        bankCashAccounts: mergedBankCash,
        voucherPrefixes: List<VoucherPrefix>.from(results[5] as Iterable),
        financialSessions: loadedSessions,
        invoiceTypes: List<InvoiceType>.from(results[7] as Iterable),
        glSetup: results[8] as GLSetup?,
        selectedFinancialSession: restoredSession,
        isLoading: false,
      );
      
      debugPrint('AccountingNotifier: State updated. Selected Year: ${state.selectedFinancialSession?.sYear}');
    } catch (e) {
      debugPrint('AccountingNotifier: Critical error in loadAll: $e');
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectFinancialSession(FinancialSession? session) {
    debugPrint('AccountingNotifier: Selecting session ${session?.sYear}');
    state = state.copyWith(selectedFinancialSession: session);
    
    // Sync with OrganizationProvider for persistence is now handled by WorkspaceSelectionScreen
    // calling setWorkspace before this. If called from elsewhere, we may need a check.
    // However, OrganizationProvider.selectFinancialYear is essentially redundant if 
    // we use AccountingNotifier as the source of truth for the year.
    
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;
    final sYear = session?.sYear;

    // Reload dependent data
    if (orgId != null) {
      loadTransactions(organizationId: orgId, storeId: storeId, sYear: sYear);
      loadInvoices(organizationId: orgId, storeId: storeId, sYear: sYear);
    }

    // Reload Orders
    try {
      _ref.read(orderProvider.notifier).loadOrders(sYear: sYear);
    } catch (e) {
      debugPrint('AccountingNotifier: Could not reload orders: $e');
    }
  }

  Future<void> loadBankCashAccounts({int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final accounts =
          await _repository.getBankCashAccounts(organizationId: orgId);
      if (!mounted) return;
      state = state.copyWith(bankCashAccounts: accounts);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadVoucherPrefixes({int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final prefixes =
          await _repository.getVoucherPrefixes(organizationId: orgId);
      if (!mounted) return;
      state = state.copyWith(voucherPrefixes: prefixes);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadPaymentTerms({int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final terms = await _repository.getPaymentTerms(organizationId: orgId);
      if (!mounted) return;
      state = state.copyWith(paymentTerms: terms);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadTransactions(
      {int? organizationId, int? storeId, int? sYear}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final txs = await _repository.getTransactions(
          organizationId: orgId, storeId: storeId, sYear: sYear);
      if (!mounted) return;
      state = state.copyWith(transactions: txs);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  int validateAndGetSYear(DateTime date) {
    if (state.financialSessions.isEmpty) {
      throw Exception(
          'No financial years configured. Please configure a financial session first.');
    }

    if (state.selectedFinancialSession == null) {
      throw Exception(
          'No Financial Year selected. Please select a Financial Session from the settings or dashboard.');
    }

    // Find a session that covers this date
    final session =
        state.financialSessions.cast<FinancialSession?>().firstWhere(
              (s) =>
                  s != null &&
                  (date.isAtSameMomentAs(s.startDate) ||
                      date.isAfter(s.startDate)) &&
                  (date.isAtSameMomentAs(s.endDate) ||
                      date.isBefore(
                          s.endDate.add(const Duration(days: 1)))), // inclusive
              orElse: () => null,
            );

    if (session == null) {
      final dateStr = date.toIso8601String().split('T')[0];
      throw Exception(
          'Date $dateStr does not fall within any configured Financial Year.');
    }

    if (session.isClosed) {
      throw Exception(
          'Financial Year ${session.sYear} is closed. Cannot transact.');
    }

    if (session.sYear != state.selectedFinancialSession!.sYear) {
      throw Exception(
          'Date falls in Financial Year ${session.sYear}, but you have selected ${state.selectedFinancialSession!.sYear}. Please switch financial years to Transact.');
    }

    return session.sYear;
  }

  Future<void> createTransaction(Transaction transaction) async {
    try {
      // Validate SYear
      final sYear = validateAndGetSYear(transaction.voucherDate);

      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      await _ref.read(subscriptionServiceProvider).checkAction(
          orgId ?? 0, 'transaction',
          extra: {'prefixId': transaction.voucherPrefixId});

      final txWithYear = Transaction(
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
        sYear: sYear, // Enforce correct sYear
        moduleAccount: transaction.moduleAccount,
        offsetModuleAccount: transaction.offsetModuleAccount,
        paymentMode: transaction.paymentMode,
        referenceNumber: transaction.referenceNumber,
        referenceDate: transaction.referenceDate,
        referenceBank: transaction.referenceBank,
        invoiceId: transaction.invoiceId,
      );

      await _repository.createTransaction(txWithYear);
      final storeId = _ref.read(organizationProvider).selectedStore?.id;
      await loadTransactions(organizationId: orgId, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      // Validate SYear
      final sYear = validateAndGetSYear(transaction.voucherDate);

      final txWithYear = Transaction(
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
        sYear: sYear,
      );

      await _repository.updateTransaction(txWithYear);
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      final storeId = _ref.read(organizationProvider).selectedStore?.id;
      await loadTransactions(organizationId: orgId, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      final storeId = _ref.read(organizationProvider).selectedStore?.id;
      await loadTransactions(organizationId: orgId ?? 0, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addAccount(ChartOfAccount account, {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final accountWithOrg = ChartOfAccount(
        id: account.id,
        accountCode: account.accountCode,
        accountTitle: account.accountTitle,
        parentId: account.parentId,
        level: account.level,
        accountTypeId: account.accountTypeId,
        accountCategoryId: account.accountCategoryId,
        organizationId: orgId ?? 0,
        isActive: account.isActive,
        isSystem: account.isSystem,
        createdAt: account.createdAt,
        updatedAt: account.updatedAt,
      );
      await _repository.createChartOfAccount(accountWithOrg);
      if (account.openingBalance != 0) {
        await _saveOpeningBalance(account.id, 'Account', account.openingBalance);
      }
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> _saveOpeningBalance(
      String entityId, String entityType, double amount) async {
    if (state.selectedFinancialSession == null) return;
    final orgId = state.selectedFinancialSession!.organizationId;
    final sYear = state.selectedFinancialSession!.sYear;

    try {
      final existingBalances = await _repository.getOpeningBalances(
          organizationId: orgId, sYear: sYear);
      
      final existing = existingBalances
          .where((b) => b.entityId == entityId && b.entityType == entityType)
          .firstOrNull;

      final balance = OpeningBalance(
        id: existing?.id ?? const Uuid().v4(),
        sYear: sYear,
        amount: amount,
        entityId: entityId,
        entityType: entityType,
        organizationId: orgId,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.saveOpeningBalance(balance);
    } catch (e) {
      print('Error saving opening balance: $e');
      // Non-blocking error, just log
    }
  }

  Future<void> updateAccount(ChartOfAccount account,
      {int? organizationId}) async {
    try {
      await _repository.updateChartOfAccount(account);
      if (account.openingBalance != 0) {
        await _saveOpeningBalance(account.id, 'Account', account.openingBalance);
      }
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAccount(String id, {int? organizationId}) async {
    try {
      await _repository.deleteChartOfAccount(id);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addVoucherPrefix(VoucherPrefix prefix,
      {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final prefixWithOrg = VoucherPrefix(
        id: prefix.id,
        prefixCode: prefix.prefixCode,
        description: prefix.description,
        voucherType: prefix.voucherType,
        organizationId: orgId ?? 0,
        status: prefix.status,
      );
      await _repository.createVoucherPrefix(prefixWithOrg);
      await loadVoucherPrefixes(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateVoucherPrefix(VoucherPrefix prefix,
      {int? organizationId}) async {
    try {
      await _repository.updateVoucherPrefix(prefix);
      await loadVoucherPrefixes(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteVoucherPrefix(int id, {int? organizationId}) async {
    try {
      await _repository.deleteVoucherPrefix(id);
      await loadVoucherPrefixes(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addPaymentTerm(PaymentTerm term, {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final termWithOrg = PaymentTerm(
        id: term.id,
        name: term.name,
        description: term.description,
        isActive: term.isActive,
        days: term.days,
        organizationId: orgId ?? 0,
      );
      await _repository.createPaymentTerm(termWithOrg);
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePaymentTerm(PaymentTerm term,
      {int? organizationId}) async {
    try {
      await _repository.updatePaymentTerm(term);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deletePaymentTerm(int id, {int? organizationId}) async {
    try {
      await _repository.deletePaymentTerm(id);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addAccountType(AccountType type, {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final typeWithOrg = AccountType(
        id: type.id,
        typeName: type.typeName,
        status: type.status,
        isSystem: type.isSystem,
        organizationId: orgId ?? 0,
      );
      await _repository.createAccountType(typeWithOrg);
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateAccountType(AccountType type,
      {int? organizationId}) async {
    try {
      await _repository.updateAccountType(type);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAccountType(int id, {int? organizationId}) async {
    try {
      await _repository.deleteAccountType(id);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addAccountCategory(AccountCategory category,
      {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final categoryWithOrg = AccountCategory(
        id: category.id,
        categoryName: category.categoryName,
        accountTypeId: category.accountTypeId,
        status: category.status,
        isSystem: category.isSystem,
        organizationId: orgId ?? 0,
      );
      await _repository.createAccountCategory(categoryWithOrg);
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateAccountCategory(AccountCategory category,
      {int? organizationId}) async {
    try {
      await _repository.updateAccountCategory(category);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAccountCategory(int id, {int? organizationId}) async {
    try {
      await _repository.deleteAccountCategory(id);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> bulkAddAccountTypes(List<AccountType> types,
      {int? organizationId}) async {
    try {
      await _repository.bulkCreateAccountTypes(types);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> bulkAddAccountCategories(List<AccountCategory> categories,
      {int? organizationId}) async {
    try {
      await _repository.bulkCreateAccountCategories(categories);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addFinancialSession(FinancialSession session,
      {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final sessionWithOrg = FinancialSession(
        sYear: session.sYear,
        startDate: session.startDate,
        endDate: session.endDate,
        narration: session.narration,
        inUse: session.inUse,
        isActive: session.isActive,
        organizationId: orgId ?? 0,
      );
      await _repository.createFinancialSession(sessionWithOrg);
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateFinancialSession(FinancialSession session,
      {int? organizationId}) async {
    try {
      await _repository.updateFinancialSession(session);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> createBankCashAccount(BankCash account,
      {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final accountWithOrg = BankCash(
        id: account.id,
        name: account.name,
        chartOfAccountId: account.chartOfAccountId,
        accountNumber: account.accountNumber,
        branchName: account.branchName,
        organizationId: orgId ?? 0,
        storeId: account.storeId,
        status: account.status,
      );
      await _repository.createBankCashAccount(accountWithOrg);
      if (account.openingBalance != 0) {
        await _saveOpeningBalance(account.id, 'BankCash', account.openingBalance);
      }
      await loadAll(organizationId: orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateBankCashAccount(BankCash account,
      {int? organizationId}) async {
    try {
      await _repository.updateBankCashAccount(account);
      if (account.openingBalance != 0) {
        await _saveOpeningBalance(account.id, 'BankCash', account.openingBalance);
      }
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteBankCashAccount(String id, {int? organizationId}) async {
    try {
      await _repository.deleteBankCashAccount(id);
      await loadAll(organizationId: organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<bool> isBankCashUsed(String id) async {
    return await _repository.isBankCashUsed(id);
  }

  // Invoice Methods
  Future<void> loadInvoices(
      {int? organizationId, int? storeId, int? sYear}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      if (orgId == null) {
        state = state.copyWith(isLoading: false, invoices: []);
        return;
      }
      final invoices = await _repository.getInvoices(
          organizationId: orgId, storeId: storeId, sYear: sYear);
      if (!mounted) return;
      state = state.copyWith(invoices: invoices, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addInvoice(Invoice invoice) async {
    try {

      final sYear = validateAndGetSYear(invoice.invoiceDate);
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      await _ref.read(subscriptionServiceProvider).checkAction(orgId ?? 0, 'invoice');
      final storeId = _ref.read(organizationProvider).selectedStore?.id;
      final invoiceWithOrg = Invoice(
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
        organizationId: orgId ?? 0,
        storeId: storeId ?? 0,
        sYear: sYear,
      );
      await _repository.createInvoice(invoiceWithOrg);
      await loadInvoices(organizationId: orgId ?? 0, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> createInvoiceWithItems(
      Invoice invoice, List<Map<String, dynamic>> itemMaps) async {
    try {

      final sYear = validateAndGetSYear(invoice.invoiceDate);
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      await _ref.read(subscriptionServiceProvider).checkAction(orgId ?? 0, 'invoice');
      final storeId = _ref.read(organizationProvider).selectedStore?.id;

      final invoiceWithOrg = Invoice(
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
        organizationId: orgId ?? 0,
        storeId: storeId ?? 0,
        sYear: sYear,
      );

      final items = itemMaps
          .map((m) => InvoiceItem(
                id: const Uuid().v4(),
                invoiceId: invoice.id,
                productId: m['product_id'],
                quantity: m['quantity'] as double,
                rate: m['rate'] as double,
                total: m['total'] as double,
                productName: m['product_name'],
                uomId: m['uom_id'],
                uomSymbol: m['uom_symbol'],
                discountPercent:
                    (m['discount_percent'] as num?)?.toDouble() ?? 0.0,
                createdAt: DateTime.now(),
              ))
          .toList();

      await _repository.createInvoiceWithItems(invoiceWithOrg, items);

      // --- GL TRANSACTION GENERATION ---
      try {
        await _createOrUpdateGLForInvoice(invoice, items: items);
      } catch (glError) {
        // Don't fail the invoice creation if GL fails, but log it
        debugPrint('GL Transaction creation failed: $glError');
      }
      // ---------------------------------

      // ---------------------------------

      final currentSYear = state.selectedFinancialSession?.sYear;
      await loadInvoices(
          organizationId: orgId ?? 0, storeId: storeId, sYear: currentSYear);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateInvoiceWithItems(
      Invoice invoice, List<Map<String, dynamic>> itemMaps) async {
    try {
      final sYear = validateAndGetSYear(invoice.invoiceDate);
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      final storeId = _ref.read(organizationProvider).selectedStore?.id;

      final invoiceWithOrg = Invoice(
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
        organizationId: orgId ?? 0,
        storeId: storeId ?? 0,
        sYear: sYear,
      );

      final items = itemMaps
          .map((m) => InvoiceItem(
                id: const Uuid().v4(),
                invoiceId: invoice.id,
                productId: m['product_id'],
                quantity: m['quantity'] is int
                    ? (m['quantity'] as int).toDouble()
                    : m['quantity'] as double,
                rate: m['rate'] is int
                    ? (m['rate'] as int).toDouble()
                    : m['rate'] as double,
                total: m['total'] is int
                    ? (m['total'] as int).toDouble()
                    : m['total'] as double,
                productName: m['product_name'],
                uomId: m['uom_id'],
                uomSymbol: m['uom_symbol'],
                discountPercent:
                    (m['discount_percent'] as num?)?.toDouble() ?? 0.0,
                createdAt: DateTime.now(),
              ))
          .toList();

      await _repository.updateInvoiceWithItems(invoiceWithOrg, items);

      // --- GL TRANSACTION UPDATE/REPAIR ---
      try {
        await _createOrUpdateGLForInvoice(invoice, items: items);
      } catch (glError) {
        debugPrint('GL Transaction update failed: $glError');
      }
      // ---------------------------------

      await loadInvoices(organizationId: orgId ?? 0, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateInvoice(Invoice invoice,
      {int? organizationId, int? storeId}) async {
    try {
      final sYear = validateAndGetSYear(invoice.invoiceDate);

      final invoiceWithYear = Invoice(
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
        sYear: sYear, // enforced
      );

      await _repository.updateInvoice(invoiceWithYear);
      await loadInvoices(organizationId: organizationId, storeId: storeId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> addInvoiceType(InvoiceType type, {int? organizationId}) async {
    try {
      await _repository.createInvoiceType(type);
      final types =
          await _repository.getInvoiceTypes(organizationId: organizationId);
      state = state.copyWith(invoiceTypes: types);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    try {
      final items = await _repository.getInvoiceItems(invoiceId);
      state = state.copyWith(currentInvoiceItems: items);
      return items;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadGLSetup({int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      if (orgId == null) return;
      final setup = await _repository.getGLSetup(orgId);
      if (!mounted) return;
      state = state.copyWith(glSetup: setup);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> saveGLSetup(GLSetup setup) async {
    try {
      await _repository.saveGLSetup(setup);
      state = state.copyWith(glSetup: setup);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> loadDailyBalance(String accountId, {int? organizationId}) async {
    try {
      final orgId = organizationId ??
          _ref.read(organizationProvider).selectedOrganizationId;
      final balance = await _repository.getLatestDailyBalance(accountId,
          organizationId: orgId);
      state = state.copyWith(currentDailyBalance: balance);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> saveDailyBalance(DailyBalance balance) async {
    try {
      await _repository.saveDailyBalance(balance);
      state = state.copyWith(currentDailyBalance: balance);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> postInvoice(Invoice invoice) async {
    try {
      final items = await getInvoiceItems(invoice.id);
      await _createOrUpdateGLForInvoice(invoice, items: items);
      final updated = invoice.copyWith(status: 'Posted');
      await updateInvoice(updated);
    } catch (e) {
      state = state.copyWith(error: 'Failed to post invoice: $e');
      rethrow;
    }
  }

  Future<void> _createOrUpdateGLForInvoice(Invoice invoice,
      {List<InvoiceItem>? items}) async {
    try {
      // Only post if status is posted or we are about to post (which implies we check correctness)
      // Actually user might want to preview impact, but usually we do this on "Post".
      // The caller ensures context. Here we blindly execute.

      final partnersState = _ref.read(businessPartnerProvider);
      // Find partner in customers or vendors list
      final partner = partnersState.customers
              .where((p) => p.id == invoice.businessPartnerId)
              .firstOrNull ??
          partnersState.vendors
              .where((p) => p.id == invoice.businessPartnerId)
              .firstOrNull;

      if (partner != null && partner.chartOfAccountId != null) {
        final orgId = _ref.read(organizationProvider).selectedOrganizationId;
        final storeId = _ref.read(organizationProvider).selectedStore?.id;
        final sYear = validateAndGetSYear(invoice.invoiceDate);

        // Ensure GL Setup is loaded
        if (state.glSetup == null) {
          await loadGLSetup(organizationId: orgId);
        }
        final glSetup = state.glSetup;

        if (glSetup != null) {
          String? debitAccount;
          String? creditAccount;
          String prefix = 'JV'; // fallback
          bool isSales = false;

          if (invoice.idInvoiceType == 'SI' ||
              invoice.idInvoiceType == 'SINV') {
            // Sales Invoice: Debit Customer, Credit Sales
            debitAccount = partner.chartOfAccountId;
            creditAccount = glSetup.salesAccountId;
            prefix = 'SINV';
            isSales = true;
          } else if (invoice.idInvoiceType == 'SIR' ||
              invoice.idInvoiceType == 'SR') {
            // Sales Return: Debit Sales Return (or Sales), Credit Customer
            debitAccount = glSetup.salesAccountId;
            creditAccount = partner.chartOfAccountId;
            prefix = 'SIR'; // Or Credit Note prefix if different
            // COGS Return Logic could be added here (Debit Inventory, Credit COGS)
          }
          // Add Purchase Invoice Logic as well if needed
          else if (invoice.idInvoiceType == 'PI') {
            debitAccount = glSetup.inventoryAccountId; // Or purchase account
            creditAccount = partner.chartOfAccountId;
            prefix = 'PI';
          }

          // Get Voucher Prefix ID - Ensure we get fresh list if empty
          List<VoucherPrefix> prefixes = state.voucherPrefixes;
          if (prefixes.isEmpty) {
            prefixes =
                await _repository.getVoucherPrefixes(organizationId: orgId);
          }

          final prefixModel =
              prefixes.where((p) => p.prefixCode == prefix).firstOrNull;

          if (prefixModel == null) {
            throw Exception(
                'Voucher Prefix "$prefix" not found. Please configure Voucher Prefixes in setup.');
          }

          if (debitAccount != null && creditAccount != null) {
            // 1. DELETE EXISTING TRANSACTIONS for this Invoice Logic
            // We replace all entries to handle updates cleanly, and to support multiple entries (Sales + COGS)
            final allTxs = state.transactions.isEmpty
                ? await _repository.getTransactions(organizationId: orgId)
                : state.transactions;
            final existingTxs = allTxs
                .where((t) =>
                    t.invoiceId == invoice.id ||
                    t.voucherNumber == invoice.invoiceNumber)
                .toList();

            for (var tx in existingTxs) {
              await _repository.deleteTransaction(tx.id);
            }

            // 2. CREATE MAIN SALES/PURCHASE TRANSACTION
            final mainTx = Transaction(
              id: const Uuid().v4(),
              voucherPrefixId: prefixModel.id,
              voucherNumber: invoice.invoiceNumber,
              voucherDate: invoice.invoiceDate,
              accountId: debitAccount,
              moduleAccount: invoice.businessPartnerId, // Customer/Vendor ID
              offsetAccountId: creditAccount,
              offsetModuleAccount: creditAccount, // Sales/Purchase GL Account
              amount: invoice.totalAmount,
              description: 'Invoice ${invoice.invoiceNumber} - ${partner.name}',
              status: 'posted',
              organizationId: orgId ?? 0,
              storeId: storeId ?? 0,
              sYear: sYear,
              invoiceId: invoice.id,
            );
            await _repository.createTransaction(mainTx);

            // 3. CREATE COGS TRANSACTION (For Sales Invoices)
            if (isSales && items != null && items.isNotEmpty) {
              double totalCost = 0;

              // Get products to calculate cost accurately
               var productList = _ref.read(productProvider).products;
               if (productList.isEmpty) {
                 await _ref
                     .read(productProvider.notifier)
                     .loadProducts();
                 productList = _ref.read(productProvider).products;
               }

              for (var item in items) {
                final product = productList
                    .where((p) => p.id == item.productId)
                    .firstOrNull;
                if (product != null) {
                  totalCost += (product.cost * item.quantity);
                } else {
                  // Fallback: try to fetch individual product if list is incomplete
                  try {
                    final p = await _ref
                        .read(productRepositoryProvider)
                        .getProductById(item.productId);
                    totalCost += (p.cost * item.quantity);
                  } catch (_) {}
                }
              }

              if (totalCost > 0) {
                final jvPrefix = state.voucherPrefixes
                    .where((p) => p.prefixCode == 'JV')
                    .firstOrNull;
                final cogsTx = Transaction(
                  id: const Uuid().v4(),
                  voucherPrefixId: jvPrefix?.id ?? prefixModel.id,
                  voucherNumber: jvPrefix != null
                      ? 'SIJV-${invoice.invoiceNumber}'
                      : invoice.invoiceNumber,
                  voucherDate: invoice.invoiceDate,
                  accountId: glSetup.cogsAccountId, // Debit COGS
                  offsetAccountId:
                      glSetup.inventoryAccountId, // Credit Inventory
                  amount: totalCost,
                  description:
                      'Cost of Sales - Invoice ${invoice.invoiceNumber}',
                  status: 'posted',
                  organizationId: orgId ?? 0,
                  storeId: storeId ?? 0,
                  sYear: sYear,
                  invoiceId: invoice.id,
                );
                await _repository.createTransaction(cogsTx);
              }
            }
          } else {
            throw Exception(
                'GL Accounts not configured for this transaction type.');
          }
        } else {
          throw Exception('GL Setup missing.');
        }
      } else {
        throw Exception('Partner or Partner GL Account missing.');
      }
    } catch (glError) {
      debugPrint('GL Transaction Op failed: $glError');
      rethrow;
    }
  }
}

final accountingProvider =
    StateNotifierProvider<AccountingNotifier, AccountingState>((ref) {
  final repo = ref.watch(accountingRepositoryProvider);
  final notifier = AccountingNotifier(repo, ref);

  // Watch organization to trigger refresh
  final orgId = ref.watch(organizationProvider).selectedOrganizationId;
  if (orgId != null) {
    Future.microtask(() => notifier.loadAll(organizationId: orgId));
  }

  return notifier;
});
