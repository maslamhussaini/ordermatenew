import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/business_partners/domain/repositories/business_partner_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_local_repository.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';
import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/features/orders/domain/repositories/order_repository.dart';
import 'package:ordermate/features/inventory/data/repositories/inventory_local_repository.dart';
import 'package:ordermate/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/inventory/domain/repositories/stock_transfer_repository.dart';
import 'package:ordermate/features/inventory/data/repositories/stock_transfer_local_repository.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';
import 'package:ordermate/features/inventory/data/models/stock_transfer_model.dart';
import 'package:ordermate/features/products/domain/repositories/product_recipe_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_recipe_local_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_recipe_repository_impl.dart';
import 'package:ordermate/features/products/domain/repositories/recipe_sale_repository.dart';
import 'package:ordermate/features/products/data/repositories/recipe_sale_repository_impl.dart';
import 'package:ordermate/features/products/data/repositories/recipe_sale_local_repository.dart';

// Recipe Providers
final productRecipeRepositoryProvider = Provider<ProductRecipeRepository>((ref) {
  return ProductRecipeRepositoryImpl();
});

final productRecipeLocalRepositoryProvider =
    Provider<ProductRecipeLocalRepository>((ref) {
  return ProductRecipeLocalRepository();
});

final recipeSaleRepositoryProvider = Provider<RecipeSaleRepository>((ref) {
  return RecipeSaleRepositoryImpl();
});

final recipeSaleLocalRepositoryProvider =
    Provider<RecipeSaleLocalRepository>((ref) {
  return RecipeSaleLocalRepository();
});

// Inventory Providers
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl();
});

final inventoryLocalRepositoryProvider =
    Provider<InventoryLocalRepository>((ref) {
  return InventoryLocalRepository();
});

final localAccountingRepositoryProvider =
    Provider<LocalAccountingRepository>((ref) {
  return LocalAccountingRepository();
});

final syncProgressProvider =
    StateNotifierProvider<SyncProgressNotifier, SyncStatus>((ref) {
  return SyncProgressNotifier();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref,
    ref.watch(productRepositoryProvider),
    ref.watch(productLocalRepositoryProvider),
    ref.watch(businessPartnerRepositoryProvider),
    ref.watch(businessPartnerLocalRepositoryProvider),
    ref.watch(orderRepositoryProvider),
    ref.watch(orderLocalRepositoryProvider),
    ref.watch(inventoryRepositoryProvider),
    ref.watch(inventoryLocalRepositoryProvider),
    ref.watch(accountingRepositoryProvider),
    ref.watch(localAccountingRepositoryProvider),
    ref.watch(stockTransferRepositoryProvider),
    ref.watch(stockTransferLocalRepositoryProvider),
    ref.watch(productRecipeRepositoryProvider),
    ref.watch(productRecipeLocalRepositoryProvider),
    ref.watch(recipeSaleRepositoryProvider),
    ref.watch(recipeSaleLocalRepositoryProvider),
  );
});

/// Outcome of the most recent sync attempt.
///
/// FIX (C-4): previously a sync that threw was reported to the UI as
/// 'Sync Complete' because the message was set unconditionally in a `finally`
/// block. Callers can now distinguish success from partial and total failure.
enum SyncOutcome { idle, success, partial, failed }

class SyncStatus {
  final bool isSyncing;
  final String message;
  final double progress; // 0.0 to 1.0
  final DateTime? lastSyncTime;
  final SyncOutcome outcome;

  /// Human-readable errors collected during the last run (one per failed step).
  final List<String> errors;

  SyncStatus({
    this.isSyncing = false,
    this.message = '',
    this.progress = 0.0,
    this.lastSyncTime,
    this.outcome = SyncOutcome.idle,
    this.errors = const [],
  });

  bool get hasFailed =>
      outcome == SyncOutcome.failed || outcome == SyncOutcome.partial;

  SyncStatus copyWith({
    bool? isSyncing,
    String? message,
    double? progress,
    DateTime? lastSyncTime,
    SyncOutcome? outcome,
    List<String>? errors,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      outcome: outcome ?? this.outcome,
      errors: errors ?? this.errors,
    );
  }
}

class SyncProgressNotifier extends StateNotifier<SyncStatus> {
  SyncProgressNotifier() : super(SyncStatus());

  void setSyncing(bool syncing, {String message = '', double progress = 0.0}) {
    state = state.copyWith(
      isSyncing: syncing,
      message: message,
      progress: progress,
      lastSyncTime: syncing ? state.lastSyncTime : DateTime.now(),
    );
  }

  void updateMessage(String message, double progress) {
    state = state.copyWith(message: message, progress: progress);
  }

  /// Resets error tracking at the start of a run.
  void beginRun() {
    state = state.copyWith(outcome: SyncOutcome.idle, errors: const []);
  }

  /// Records a non-fatal step failure (sync continues).
  void recordError(String step, Object error) {
    state = state.copyWith(errors: [...state.errors, '$step: $error']);
  }

  /// Terminal state for a run. [message] is derived from the outcome so a
  /// failure can never be labelled as success.
  void finishRun({required bool aborted}) {
    final failed = state.errors.length;
    final SyncOutcome outcome;
    final String message;

    if (aborted) {
      outcome = SyncOutcome.failed;
      message = 'Sync failed';
    } else if (failed > 0) {
      outcome = SyncOutcome.partial;
      message = 'Sync completed with $failed error(s)';
    } else {
      outcome = SyncOutcome.success;
      message = 'Sync Complete';
    }

    state = state.copyWith(
      isSyncing: false,
      message: message,
      outcome: outcome,
      lastSyncTime: DateTime.now(),
    );
  }
}

class SyncService {
  SyncService(
    this._ref,
    this._productRepository,
    this._productLocalRepository,
    this._partnerRepository,
    this._partnerLocalRepository,
    this._orderRepository,
    this._orderLocalRepository,
    this._inventoryRepository,
    this._inventoryLocalRepository,
    this._accountingRepository,
    this._accountingLocalRepository,
    this._transferRepository,
    this._transferLocalRepository,
    this._recipeRepository,
    this._recipeLocalRepository,
    this._recipeSaleRepository,
    this._recipeSaleLocalRepository,
  );

  final Ref _ref;
  final ProductRepository _productRepository;
  final ProductLocalRepository _productLocalRepository;
  final BusinessPartnerRepository _partnerRepository;
  final BusinessPartnerLocalRepository _partnerLocalRepository;
  final OrderRepository _orderRepository;
  final OrderLocalRepository _orderLocalRepository;
  final InventoryRepository _inventoryRepository;
  final InventoryLocalRepository _inventoryLocalRepository;
  final AccountingRepository _accountingRepository;
  final LocalAccountingRepository _accountingLocalRepository;
  final StockTransferRepository _transferRepository;
  final StockTransferLocalRepository _transferLocalRepository;
  final ProductRecipeRepository _recipeRepository;
  final ProductRecipeLocalRepository _recipeLocalRepository;
  final RecipeSaleRepository _recipeSaleRepository;
  final RecipeSaleLocalRepository _recipeSaleLocalRepository;

  void _updateStatus(String message, double progress) {
    _ref.read(syncProgressProvider.notifier).updateMessage(message, progress);
  }

  Future<bool> hasUnsyncedData() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;

    // Check key repositories
    final orders =
        await _orderLocalRepository.getUnsyncedOrders(organizationId: orgId);
    if (orders.isNotEmpty) return true;

    final products = await _productLocalRepository.getUnsyncedProducts(
        organizationId: orgId);
    if (products.isNotEmpty) return true;

    final partners = await _partnerLocalRepository.getUnsyncedPartners(
        organizationId: orgId);
    if (partners.isNotEmpty) return true;

    // Inventory
    final brands = await _inventoryLocalRepository.getUnsyncedBrands(
        organizationId: orgId);
    if (brands.isNotEmpty) return true;
    final cats = await _inventoryLocalRepository.getUnsyncedCategories(
        organizationId: orgId);
    if (cats.isNotEmpty) return true;

    // Accounting
    final invoices = await _accountingLocalRepository.getUnsyncedInvoices(
        organizationId: orgId);
    if (invoices.isNotEmpty) return true;
    final tx = await _accountingLocalRepository.getUnsyncedTransactions(
        organizationId: orgId);
    if (tx.isNotEmpty) return true;

    final transfers = await _transferLocalRepository.getUnsyncedTransfers(
        organizationId: orgId);
    if (transfers.isNotEmpty) return true;

    final recipes = await _recipeLocalRepository.getUnsyncedRecipes(
        organizationId: orgId);
    if (recipes.isNotEmpty) return true;

    final recipeSales = await _recipeSaleLocalRepository.getUnsyncedRecipeSales(
        organizationId: orgId);
    if (recipeSales.isNotEmpty) return true;

    return false;
  }

  Future<void> syncAll() async {
    if (_ref.read(syncProgressProvider).isSyncing) {
      return;
    }

    final wasOffline = SupabaseConfig.isOfflineLoggedIn;
    SupabaseConfig.isOfflineLoggedIn = false;

    final notifier = _ref.read(syncProgressProvider.notifier);
    var aborted = false;
    var started = false;

    // FIX (C-4): each step is individually guarded so one failing entity does
    // not abort the rest, and every failure is recorded. The terminal message
    // is derived from the recorded outcome — it can no longer report success
    // for a run that threw.
    Future<void> step(String label, double progress, Future<void> Function() body) async {
      _updateStatus(label, progress);
      try {
        await body();
      } catch (e, stack) {
        debugPrint('SyncService: step "$label" failed: $e');
        debugPrint(stack.toString());
        notifier.recordError(label, e);
      }
    }

    try {
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      if (orgId == null) {
        debugPrint('SyncService: Sync Aborted. No Organization Selected.');
        return;
      }

      debugPrint('SyncService: Full Sync Started for Org: $orgId');
      started = true;
      notifier.beginRun();
      notifier.setSyncing(true, message: 'Starting Sync...', progress: 0.0);

      await step('Pushing local changes', 0.1, pushLocalChanges);

      // FIX (C-4): the individual push helpers catch per-record errors and
      // continue, which is correct for batching but hides failure. Anything
      // still flagged unsynced after the push means records did not reach the
      // server — surface that instead of reporting success.
      try {
        if (await hasUnsyncedData()) {
          notifier.recordError(
              'Pushing local changes', 'records remain unsynced after push');
        }
      } catch (e) {
        notifier.recordError('Unsynced check', e);
      }
      await step('Syncing Inventory', 0.3, syncInventory);
      await step('Syncing Accounting', 0.5, syncAccounting);
      await step('Syncing Products', 0.7, syncProducts);
      await step('Syncing Partners', 0.8, syncPartners);
      await step('Syncing Orders', 0.9, syncOrders);
      await step('Syncing Stock Transfers', 0.95, syncStockTransfers);
      await step('Syncing Recipes', 0.97, syncProductRecipes);
      await step('Syncing Recipe Sales', 0.98, syncRecipeSales);
      await step('Updating Metadata', 1.0, syncMetadata);
    } catch (e, stack) {
      // Anything escaping the per-step guards is a hard abort.
      aborted = true;
      debugPrint('SyncService: Critical Sync Error: $e');
      debugPrint(stack.toString());
      notifier.recordError('Sync', e);
    } finally {
      SupabaseConfig.isOfflineLoggedIn = wasOffline;
      if (started) {
        notifier.finishRun(aborted: aborted);
      } else {
        notifier.setSyncing(false);
      }
    }
  }

  Future<void> syncAccounting() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint(
          'SyncService: Starting Accounting Pull (COA, Terms, Bank, Prefix, Types, Cats, Invoices, Transactions)...');

      try {
        final items = await _accountingRepository.getChartOfAccounts(
            organizationId: orgId);
        debugPrint('   - COA Pulled: ${items.length} items');
        _updateStatus('Pulled Chart of Accounts...', 0.51);
      } catch (e) {
        debugPrint('   - ❌ COA pull failed: $e');
      }

      try {
        final items =
            await _accountingRepository.getPaymentTerms(organizationId: orgId);
        debugPrint('   - Payment Terms Pulled: ${items.length} items');
        _updateStatus('Pulled Payment Terms...', 0.52);
      } catch (e) {
        debugPrint('   - ❌ Payment Terms pull failed: $e');
      }

      try {
        final items = await _accountingRepository.getBankCashAccounts(
            organizationId: orgId);
        debugPrint('   - Bank/Cash Pulled: ${items.length} items');
        _updateStatus('Pulled Bank Accounts...', 0.53);
      } catch (e) {
        debugPrint('   - ❌ Bank Accounts pull failed: $e');
      }

      try {
        final items = await _accountingRepository.getVoucherPrefixes(
            organizationId: orgId);
        debugPrint('   - Voucher Prefixes Pulled: ${items.length} items');
        _updateStatus('Pulled Voucher Prefixes...', 0.54);
      } catch (e) {
        debugPrint('   - ❌ Voucher Prefixes pull failed: $e');
      }

      try {
        final items =
            await _accountingRepository.getAccountTypes(organizationId: orgId);
        debugPrint('   - Account Types Pulled: ${items.length} items');
        _updateStatus('Pulled Account Types...', 0.55);
      } catch (e) {
        debugPrint('   - ❌ Account Types pull failed: $e');
      }

      try {
        final items = await _accountingRepository.getAccountCategories(
            organizationId: orgId);
        debugPrint('   - Account Categories Pulled: ${items.length} items');
        _updateStatus('Pulled Account Categories...', 0.56);
      } catch (e) {
        debugPrint('   - ❌ Account Categories pull failed: $e');
      }

      try {
        final items =
            await _accountingRepository.getInvoiceTypes(organizationId: orgId);
        debugPrint('   - Invoice Types Pulled: ${items.length} items');
        _updateStatus('Pulled Invoice Types...', 0.57);
      } catch (e) {
        debugPrint('   - ❌ Invoice Types pull failed: $e');
      }

      try {
        final invoices = await _accountingRepository.getInvoices(
            organizationId: orgId, storeId: storeId);
        debugPrint('   - Invoices Pulled: ${invoices.length} items');
        _updateStatus('Pulled Invoices...', 0.58);
        if (orgId != null) {
          final items = await _accountingRepository.getInvoiceItemsByOrg(orgId);
          debugPrint('   - Invoice Items Pulled: ${items.length} items');
          await _accountingRepository.getGLSetup(orgId);
          debugPrint('   - GL Setup Pulled');
        }
      } catch (e) {
        debugPrint('   - ❌ Invoices/Items push failed: $e');
      }

      try {
        final txs = await _accountingRepository.getTransactions(
            organizationId: orgId, storeId: storeId);
        debugPrint('   - Transactions Pulled: ${txs.length} items');
        _updateStatus('Pulled Transactions...', 0.59);
      } catch (e) {
        debugPrint('   - ❌ Transactions pull failed: $e');
      }

      debugPrint('SyncService: Accounting Sync Step Complete.');
    } catch (e) {
      debugPrint('❌ SyncService: Accounting Sync Major Failure: $e');
    }
  }

  Future<void> pushAccounting() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;
    debugPrint('SyncService: Pushing accounting changes...');

    // 0. Sync Repair: Ensure manual items are marked unsynced if pull finished
    final db = await DatabaseHelper.instance.database;
    await db.execute(
        'UPDATE local_account_categories SET is_synced = 0 WHERE id > 10 AND is_system = 0');
    await db.execute('UPDATE local_brands SET is_synced = 0 WHERE id > 100');

    final totalLocalCats = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM local_account_categories')) ??
        0;
    debugPrint(
        'SyncService: DEBUG - Total Categories in local DB: $totalLocalCats');

    // 1. Account Types (Base for COA)
    final unsyncedTypes = await _accountingLocalRepository
        .getUnsyncedAccountTypes(organizationId: orgId);
    if (unsyncedTypes.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedTypes.length} unsynced Account Types to push');
    }
    for (final type in unsyncedTypes) {
      try {
        await _accountingRepository.createAccountType(type);
        debugPrint('SyncService: Pushed AccountType ${type.typeName}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push AccountType ${type.typeName}: $e');
      }
    }

    // 2. Account Categories (Base for COA)
    final unsyncedCategories = await _accountingLocalRepository
        .getUnsyncedAccountCategories(organizationId: orgId);
    if (unsyncedCategories.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedCategories.length} unsynced Account Categories');
    }
    for (final cat in unsyncedCategories) {
      try {
        await _accountingRepository.createAccountCategory(cat);
        debugPrint('SyncService: Pushed AccountCategory ${cat.categoryName}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push AccountCategory ${cat.categoryName}: $e');
      }
    }

    // 3. Financial Sessions (Base for Transactions)
    final unsyncedSessions = await _accountingLocalRepository
        .getUnsyncedFinancialSessions(organizationId: orgId);
    for (final session in unsyncedSessions) {
      try {
        await _accountingRepository.createFinancialSession(session);
        debugPrint('SyncService: Pushed FinancialSession ${session.sYear}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push FinancialSession ${session.sYear}: $e');
      }
    }

    // 4. COA (Base for Transactions, BankCash, DailyBalance)
    final unsyncedCOA = await _accountingLocalRepository
        .getUnsyncedChartOfAccounts(organizationId: orgId);
    if (unsyncedCOA.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedCOA.length} unsynced Chart of Accounts to push');
    }
    // Sort by level ASC to ensure parents are pushed before children
    unsyncedCOA.sort((a, b) => a.level.compareTo(b.level));
    for (final account in unsyncedCOA) {
      try {
        await _accountingRepository.createChartOfAccount(account);
        debugPrint(
            'SyncService: Pushed ChartOfAccount ${account.accountTitle}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push COA ${account.accountTitle}: $e');
      }
    }

    // 5. GL Setup (Depends on COA)
    final unsyncedGL = await _accountingLocalRepository.getUnsyncedGLSetups();
    for (final setup in unsyncedGL) {
      try {
        await _accountingRepository.saveGLSetup(setup);
        await _accountingLocalRepository
            .markGLSetupAsSynced(setup.organizationId);
        debugPrint(
            'SyncService: Pushed GLSetup for Org ${setup.organizationId}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push GLSetup for Org ${setup.organizationId}: $e');
      }
    }

    // 6. Payment Terms
    final unsyncedTerms = await _accountingLocalRepository
        .getUnsyncedPaymentTerms(organizationId: orgId);
    if (unsyncedTerms.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedTerms.length} unsynced Payment Terms to push');
    }
    for (final term in unsyncedTerms) {
      try {
        await _accountingRepository.createPaymentTerm(term);
        debugPrint('SyncService: Pushed PaymentTerm ${term.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push PaymentTerm ${term.name}: $e');
      }
    }

    // 7. Voucher Prefixes (Base for Transactions)
    final unsyncedPrefixes = await _accountingLocalRepository
        .getUnsyncedVoucherPrefixes(organizationId: orgId);
    if (unsyncedPrefixes.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedPrefixes.length} unsynced Voucher Prefixes to push');
    }
    for (final prefix in unsyncedPrefixes) {
      try {
        await _accountingRepository.createVoucherPrefix(prefix);
        debugPrint('SyncService: Pushed Prefix ${prefix.prefixCode}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push Prefix ${prefix.prefixCode}: $e');
      }
    }

    // 8. Bank Cash (Depends on COA)
    final unsyncedBankCash = await _accountingLocalRepository
        .getUnsyncedBankCashAccounts(organizationId: orgId, storeId: storeId);
    if (unsyncedBankCash.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedBankCash.length} unsynced Bank/Cash accounts to push');
    }
    for (final acct in unsyncedBankCash) {
      try {
        await _accountingRepository.createBankCashAccount(acct);
        debugPrint('SyncService: Pushed BankCash ${acct.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push BankCash ${acct.name}: $e');
      }
    }

    // 9. Transactions (Depends on VoucherPrefix, COA, FinancialSession)
    final unsyncedTx = await _accountingLocalRepository.getUnsyncedTransactions(
        organizationId: orgId, storeId: storeId);
    for (final tx in unsyncedTx) {
      try {
        await _accountingRepository.createTransaction(tx);
        debugPrint('SyncService: Pushed Transaction ${tx.voucherNumber}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push Transaction ${tx.voucherNumber}: $e');
      }
    }

    // 10. Daily Balances (Depends on COA)
    final unsyncedBalances = await _accountingLocalRepository
        .getUnsyncedDailyBalances(organizationId: orgId);
    for (final balance in unsyncedBalances) {
      try {
        await _accountingRepository.saveDailyBalance(balance);
        debugPrint(
            'SyncService: Pushed DailyBalance for account ${balance.accountId}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push DailyBalance for account ${balance.accountId}: $e');
      }
    }

    // 11. Invoice Types
    final unsyncedInvTypes = await _accountingLocalRepository
        .getUnsyncedInvoiceTypes(organizationId: orgId);
    for (final type in unsyncedInvTypes) {
      try {
        await _accountingRepository.createInvoiceType(type);
        debugPrint('SyncService: Pushed InvoiceType ${type.idInvoiceType}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push InvoiceType ${type.idInvoiceType}: $e');
      }
    }

    // 12. Invoices & Items (Depends on Partners, Orders, Types)
    final unsyncedInvoices = await _accountingLocalRepository
        .getUnsyncedInvoices(organizationId: orgId, storeId: storeId);
    if (unsyncedInvoices.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedInvoices.length} unsynced Invoices to push');
    }
    for (final invoice in unsyncedInvoices) {
      try {
        await _accountingRepository.createInvoice(invoice);

        // Push items for this invoice
        final items =
            await _accountingLocalRepository.getInvoiceItems(invoice.id);
        if (items.isNotEmpty) {
          await _accountingRepository.createInvoiceItems(items);
        }

        await _accountingLocalRepository.markInvoiceAsSynced(invoice.id);
        debugPrint(
            'SyncService: Pushed Invoice ${invoice.invoiceNumber} and ${items.length} items');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push Invoice ${invoice.invoiceNumber}: $e');
      }
    }
  }

  Future<void> pushInventory() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    debugPrint(
        'SyncService: Pushing inventory changes (Brands, Categories, etc.)...');

    // 1. Brands
    final unsyncedBrands = await _inventoryLocalRepository.getUnsyncedBrands(
        organizationId: orgId);
    for (final brand in unsyncedBrands) {
      try {
        await _inventoryRepository.createBrand(brand);
        debugPrint('SyncService: Pushed Brand ${brand.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push Brand ${brand.name}: $e');
      }
    }

    // 2. Categories
    final unsyncedCats = await _inventoryLocalRepository.getUnsyncedCategories(
        organizationId: orgId);
    if (unsyncedCats.isNotEmpty) {
      debugPrint(
          'SyncService: Found ${unsyncedCats.length} unsynced Product Categories to push');
    }
    for (final cat in unsyncedCats) {
      try {
        await _inventoryRepository.createCategory(cat);
        debugPrint('SyncService: Pushed Category ${cat.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push Category ${cat.name}: $e');
      }
    }

    // 3. Product Types
    final unsyncedTypes = await _inventoryLocalRepository
        .getUnsyncedProductTypes(organizationId: orgId);
    for (final type in unsyncedTypes) {
      try {
        await _inventoryRepository.createProductType(type);
        debugPrint('SyncService: Pushed ProductType ${type.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push ProductType ${type.name}: $e');
      }
    }

    // 4. UOMs
    final unsyncedUoms = await _inventoryLocalRepository
        .getUnsyncedUnitsOfMeasure(organizationId: orgId);
    for (final uom in unsyncedUoms) {
      try {
        await _inventoryRepository.createUnitOfMeasure(uom);
        debugPrint('SyncService: Pushed UOM ${uom.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push UOM ${uom.name}: $e');
      }
    }

    // 5. Unit Conversions
    final unsyncedConvs = await _inventoryLocalRepository
        .getUnsyncedUnitConversions(organizationId: orgId);
    for (final conv in unsyncedConvs) {
      try {
        await _inventoryRepository.createUnitConversion(conv);
        debugPrint('SyncService: Pushed UnitConversion ${conv.id}');
      } catch (e) {
        debugPrint('SyncService: Failed to push UnitConversion ${conv.id}: $e');
      }
    }
  }

  Future<void> syncMetadata() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    try {
      debugPrint('SyncService: Starting Metadata Sync (Pull)...');
      await Future.wait([
        _partnerRepository.getCities(),
        _partnerRepository.getStates(),
        _partnerRepository.getCountries(),
        _partnerRepository.getBusinessTypes(),
        _partnerRepository.getRoles(organizationId: orgId),
      ]);

      if (orgId != null) {
        await _partnerRepository.getDepartments(orgId);
      }
      debugPrint('SyncService: Metadata Sync Complete.');
    } catch (e) {
      debugPrint('SyncService: Metadata Sync Failed: $e');
    }
  }

  Future<void> pushLocalChanges() async {
    debugPrint('SyncService: Checking for local changes to push...');
    await pushDeletions();
    await pushPartners();
    await pushAppUsers();
    await pushInventory();
    await pushProducts();
    await pushOrders();
    await pushAccounting();
    await pushStockTransfers();
    await pushProductRecipes();
    await pushRecipeSales();
  }

  Future<void> pushStockTransfers() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final unsynced = await _transferLocalRepository.getUnsyncedTransfers(
        organizationId: orgId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced Stock Transfers to push');
    for (final transfer in unsynced) {
      try {
        await _transferRepository.createTransfer(transfer);
        await _transferLocalRepository.markTransferAsSynced(transfer.id);
        debugPrint(
            'SyncService: Pushed Stock Transfer ${transfer.transferNumber}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push Stock Transfer ${transfer.transferNumber}: $e');
      }
    }
  }

  Future<void> pushProductRecipes() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final unsynced = await _recipeLocalRepository.getUnsyncedRecipes(
        organizationId: orgId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced Product Recipes to push');
    for (final recipe in unsynced) {
      try {
        await _recipeRepository.createRecipe(recipe);
        await _recipeLocalRepository.markRecipeAsSynced(recipe.id);
        debugPrint('SyncService: Pushed Recipe ${recipe.id}');
      } catch (e) {
        debugPrint('SyncService: Failed to push Recipe ${recipe.id}: $e');
      }
    }
  }

  Future<void> pushRecipeSales() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final unsynced = await _recipeSaleLocalRepository.getUnsyncedRecipeSales(
        organizationId: orgId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced Recipe Sales to push');
    for (final sale in unsynced) {
      try {
        final items = await _recipeSaleLocalRepository.getLocalRecipeSaleItems(sale.id);
        await _recipeSaleRepository.createRecipeSale(sale, items);
        await _recipeSaleLocalRepository.markRecipeSaleAsSynced(sale.id);
        debugPrint('SyncService: Pushed Recipe Sale ${sale.id}');
      } catch (e) {
        debugPrint('SyncService: Failed to push Recipe Sale ${sale.id}: $e');
      }
    }
  }

  Future<void> pushDeletions() async {
    debugPrint('SyncService: Checking for offline deletions...');
    final db = await DatabaseHelper.instance.database;
    final deletedRecords = await db.query('local_deleted_records');

    if (deletedRecords.isEmpty) return;

    debugPrint(
        'SyncService: Found ${deletedRecords.length} deletions to sync.');

    for (final record in deletedRecords) {
      final id = record['id'] as int;
      final table = record['entity_table'] as String;
      final entityId = record['entity_id'] as String;

      try {
        if (table == 'local_orders') {
          await _orderRepository.deleteOrder(entityId);
          debugPrint('SyncService: Synced deletion for order $entityId');
        } else if (table == 'local_products') {
          await _productRepository.deleteProduct(entityId);
          debugPrint('SyncService: Synced deletion for product $entityId');
        } else if (table == 'local_businesspartners') {
          await _partnerRepository.deletePartner(entityId);
          debugPrint('SyncService: Synced deletion for partner $entityId');
        }
      } catch (e) {
        debugPrint(
            'SyncService: Failed to sync deletion for $table:$entityId - $e (Marking as done to prevent loop)');
      } finally {
        // Always remove from tracking table to prevent infinite loops
        await db
            .delete('local_deleted_records', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> pushProducts() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final unsynced = await _productLocalRepository.getUnsyncedProducts(
        organizationId: orgId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced Products to push');

    debugPrint('SyncService: Pushing ${unsynced.length} unsynced products...');
    for (final product in unsynced) {
      try {
        await _productRepository.updateProduct(product); // Upsert logic usually
        await _productLocalRepository.markProductAsSynced(product.id);
        debugPrint('SyncService: Pushed product ${product.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push product ${product.name}: $e');
      }
    }
  }

  Future<void> pushPartners() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;
    final unsynced = await _partnerLocalRepository.getUnsyncedPartners(
        organizationId: orgId, storeId: storeId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced Partners to push');

    debugPrint('SyncService: Pushing ${unsynced.length} unsynced partners...');
    for (final partner in unsynced) {
      try {
        // CreatePartner now uses upsert, so it handles both new and updated records
        await _partnerRepository.createPartner(partner);
        await _partnerLocalRepository.markPartnerAsSynced(partner.id);
        debugPrint('SyncService: Pushed partner ${partner.name}');
      } catch (e) {
        debugPrint('SyncService: Failed to push partner ${partner.name}: $e');
      }
    }
  }

  Future<void> pushAppUsers() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final unsynced = await _partnerLocalRepository.getUnsyncedAppUsers(
        organizationId: orgId);
    if (unsynced.isEmpty) return;

    debugPrint(
        'SyncService: Found ${unsynced.length} unsynced AppUsers to push');

    for (final map in unsynced) {
      try {
        final user = AppUser.fromJson(map);
        // We can use updateAppUser which handles upsert online
        await _partnerRepository.updateAppUser(user, password: user.password);
        await _partnerLocalRepository.markAppUserAsSynced(user.id);
        debugPrint('SyncService: Pushed AppUser ${user.email}');
      } catch (e) {
        debugPrint('SyncService: Failed to push AppUser ${map['email']}: $e');
      }
    }
  }

  Future<void> pushOrders() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;
    final unsynced = await _orderLocalRepository.getUnsyncedOrders(
        organizationId: orgId, storeId: storeId);
    if (unsynced.isEmpty) return;

    debugPrint('SyncService: Found ${unsynced.length} unsynced Orders to push');

    debugPrint('SyncService: Pushing ${unsynced.length} unsynced orders...');
    for (final order in unsynced) {
      try {
        await _orderRepository.createOrder(order); // uses upsert logic

        // Handle items
        final items = await _orderLocalRepository.getLocalOrderItems(order.id);
        if (items.isNotEmpty) {
          // Delete existing items on server to prevent duplicates (since we don't track item modifications specifically)
          await _orderRepository.deleteOrderItems(order.id);

          final itemsWithOrderId = items.map((i) {
            final m = Map<String, dynamic>.from(i);
            m['order_id'] = order.id;
            // Ensure we don't pass local IDs if server should generate, or keep them if they are UUIDs.
            // Usually for items, we can just insert new ones.
            m.remove('id');
            m.remove('created_at');
            m.remove('product_name');
            m.remove('product'); // If stored entire object
            m.remove('uom_symbol');
            m.remove('base_quantity');
            return m;
          }).toList();

          await _orderRepository.createOrderItems(itemsWithOrderId);
        }

        await _orderLocalRepository.markOrderAsSynced(order.id);
        debugPrint('SyncService: Pushed order ${order.orderNumber}');
      } catch (e) {
        debugPrint(
            'SyncService: Failed to push order ${order.orderNumber}: $e');
      }
    }
  }

  Future<void> syncProducts() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint('SyncService: Starting Product Sync...');

      // 1. Fetch from Supabase
      final products = await _productRepository.getProducts(
          organizationId: orgId, storeId: storeId);

      if (products.isEmpty) {
        debugPrint('SyncService: No products found on server.');
        return;
      }

      // 2. Cache Locally
      await _productLocalRepository.cacheProducts(products);

      // 3. Update Sync Metadata
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'products',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
          'SyncService: Product Sync Complete. Cached ${products.length} items.');
    } catch (e) {
      debugPrint('SyncService: Product Sync Failed: $e');
    }
  }

  Future<void> syncPartners() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint('SyncService: Starting Partner Sync (Pull)...');

      final customers = await _partnerRepository.getPartners(
          isCustomer: true, organizationId: orgId, storeId: storeId);
      final vendors = await _partnerRepository.getPartners(
          isVendor: true, organizationId: orgId, storeId: storeId);
      final employees = await _partnerRepository.getPartners(
          isEmployee: true, organizationId: orgId, storeId: storeId);
      final suppliers = await _partnerRepository.getPartners(
          isSupplier: true, organizationId: orgId, storeId: storeId);

      // 5. App Users
      if (orgId != null) {
        await _partnerRepository.getAppUsers(orgId);
      }

      // Combine
      final allPartners = [
        ...customers,
        ...vendors,
        ...employees,
        ...suppliers
      ];

      if (allPartners.isEmpty) {
        debugPrint('SyncService: No partners found.');
        return;
      }

      // Note: cachePartners overwrites local data.
      // Since we pushed changes FIRST, this is reasonably safe for "Last Write Wins" from server
      // if someone else modified it. Our push would have updated server first.
      await _partnerLocalRepository.cachePartners(allPartners);

      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'business_partners',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
          'SyncService: Partner Sync Complete. Cached ${allPartners.length} items.');
    } catch (e) {
      debugPrint('SyncService: Partner Sync Failed: $e');
    }
  }

  Future<void> syncOrders() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint('SyncService: Starting Order Sync (Pull)...');
      // Ideally fetch only recent orders or incremental.
      final orders = await _orderRepository.getOrders(
          organizationId: orgId, storeId: storeId);

      if (orders.isEmpty) {
        debugPrint('SyncService: No orders found.');
        return;
      }

      await _orderLocalRepository.cacheOrders(orders);

      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'orders',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
          'SyncService: Order Sync Complete. Cached ${orders.length} items.');
    } catch (e) {
      debugPrint('SyncService: Order Sync Failed: $e');
    }
  }

  Future<void> syncStockTransfers() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint('SyncService: Starting Stock Transfer Sync (Pull)...');
      final transfers = await _transferRepository.getTransfers(
          organizationId: orgId, storeId: storeId);

      if (transfers.isEmpty) {
        debugPrint('SyncService: No stock transfers found.');
        return;
      }

      // Convert to models for caching
      final models =
          transfers.map((e) => StockTransferModel.fromEntity(e)).toList();
      await _transferLocalRepository.cacheTransfers(models);

      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'stock_transfers',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
          'SyncService: Stock Transfer Sync Complete. Cached ${transfers.length} items.');
    } catch (e) {
      debugPrint('SyncService: Stock Transfer Sync Failed: $e');
    }
  }

  Future<void> syncProductRecipes() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;

    try {
      debugPrint('SyncService: Starting Product Recipe Sync (Pull)...');
      final recipes = await _recipeRepository.getRecipes(organizationId: orgId);

      if (recipes.isEmpty) {
        debugPrint('SyncService: No product recipes found.');
        return;
      }

      await _recipeLocalRepository.cacheRecipes(recipes);

      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'product_recipes',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
          'SyncService: Product Recipe Sync Complete. Cached ${recipes.length} items.');
    } catch (e) {
      debugPrint('SyncService: Product Recipe Sync Failed: $e');
    }
  }

  Future<void> syncRecipeSales() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    final storeId = _ref.read(organizationProvider).selectedStore?.id;

    try {
      debugPrint('SyncService: Starting Recipe Sale Sync (Pull)...');
      final sales = await _recipeSaleRepository.getRecipeSales(
          organizationId: orgId, storeId: storeId);

      if (sales.isEmpty) {
        debugPrint('SyncService: No recipe sales found.');
        return;
      }

      for (var sale in sales) {
        final items = await _recipeSaleRepository.getRecipeSaleItems(sale.id);
        await _recipeSaleLocalRepository.saveRecipeSale(sale, items, isSynced: true);
      }

      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'sync_metadata',
        {
          'entity': 'recipe_sales',
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
          'SyncService: Recipe Sale Sync Complete. Cached ${sales.length} items.');
    } catch (e) {
      debugPrint('SyncService: Recipe Sale Sync Failed: $e');
    }
  }

  Future<void> syncInventory() async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;

    try {
      debugPrint('SyncService: Starting Inventory Sync (Pull)...');

      // Sync brands, categories, product types, UOMs, and conversions in parallel
      final results = await Future.wait([
        _inventoryRepository.getBrands(organizationId: orgId),
        _inventoryRepository.getCategories(organizationId: orgId),
        _inventoryRepository.getProductTypes(organizationId: orgId),
        _inventoryRepository.getUnitsOfMeasure(organizationId: orgId),
        _inventoryRepository.getUnitConversions(organizationId: orgId),
      ]);

      final brands = results[0] as List<Brand>;
      final categories = results[1] as List<ProductCategory>;
      final productTypes = results[2] as List<ProductType>;
      final uoms = results[3] as List<UnitOfMeasure>;
      final conversions = results[4] as List<UnitConversion>;

      // Cache locally
      await Future.wait([
        _inventoryLocalRepository.cacheBrands(brands),
        _inventoryLocalRepository.cacheCategories(categories),
        _inventoryLocalRepository.cacheProductTypes(productTypes),
        _inventoryLocalRepository.cacheUnitsOfMeasure(uoms),
        _inventoryLocalRepository.cacheUnitConversions(conversions),
      ]);

      // Update sync metadata
      final db = await DatabaseHelper.instance.database;
      await Future.wait([
        db.insert(
            'sync_metadata',
            {
              'entity': 'brands',
              'last_sync': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace),
        db.insert(
            'sync_metadata',
            {
              'entity': 'categories',
              'last_sync': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace),
        db.insert(
            'sync_metadata',
            {
              'entity': 'product_types',
              'last_sync': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace),
        db.insert(
            'sync_metadata',
            {
              'entity': 'uoms',
              'last_sync': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace),
        db.insert(
            'sync_metadata',
            {
              'entity': 'unit_conversions',
              'last_sync': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace),
      ]);

      debugPrint(
          'SyncService: Inventory Sync Complete. Cached ${brands.length} brands, ${categories.length} categories, ${productTypes.length} types, ${uoms.length} UOMs.');
    } catch (e) {
      debugPrint('SyncService: Inventory Sync Failed: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'sync_metadata',
      orderBy: 'last_sync DESC',
      limit: 1,
    );

    if (result.isNotEmpty && result.first['last_sync'] != null) {
      final milliseconds = result.first['last_sync'] as int;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return null;
  }
}
