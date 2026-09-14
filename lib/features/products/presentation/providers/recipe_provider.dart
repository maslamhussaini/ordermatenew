import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';
import 'package:ordermate/features/products/domain/repositories/product_recipe_repository.dart';
import 'package:ordermate/features/products/domain/repositories/recipe_sale_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_recipe_local_repository.dart';
import 'package:ordermate/features/products/data/repositories/recipe_sale_local_repository.dart';
import 'package:ordermate/features/products/data/services/recipe_costing_service.dart';
import 'package:ordermate/features/inventory/data/services/inventory_posting_service.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:uuid/uuid.dart';

class RecipeState {
  final List<ProductRecipe> recipes;
  final bool isLoading;
  final String? error;
  final bool isPosting;

  RecipeState({
    this.recipes = const [],
    this.isLoading = false,
    this.error,
    this.isPosting = false,
  });

  RecipeState copyWith({
    List<ProductRecipe>? recipes,
    bool? isLoading,
    String? error,
    bool? isPosting,
  }) {
    return RecipeState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPosting: isPosting ?? this.isPosting,
    );
  }
}

class RecipeNotifier extends StateNotifier<RecipeState> {
  final Ref _ref;
  final ProductRecipeRepository _recipeRepository;
  final ProductRecipeLocalRepository _recipeLocalRepository;
  final RecipeSaleRepository _recipeSaleRepository;
  final RecipeSaleLocalRepository _recipeSaleLocalRepository;
  final InventoryPostingService _postingService;

  RecipeNotifier(
    this._ref,
    this._recipeRepository,
    this._recipeLocalRepository,
    this._recipeSaleRepository,
    this._recipeSaleLocalRepository,
    this._postingService,
  ) : super(RecipeState());

  Future<void> loadRecipes(String productId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      final recipes = await _recipeRepository.getRecipesByProduct(
          productId, orgId ?? 0);
      state = state.copyWith(recipes: recipes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> saveRecipe(
      String productId, List<ProductRecipe> recipes) async {
    final orgId = _ref.read(organizationProvider).selectedOrganizationId;
    if (orgId == null) {
      throw Exception('No organization selected');
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final existing = await _recipeRepository.getRecipesByProduct(
          productId, orgId);

      for (final recipe in existing) {
        if (!recipes.any((r) => r.id == recipe.id)) {
          await _recipeRepository.deleteRecipe(recipe.id);
          await _recipeLocalRepository.deleteRecipe(recipe.id);
        }
      }

      for (final recipe in recipes) {
        final entity = recipe.copyWith(
          productId: productId,
          organizationId: orgId,
          updatedAt: DateTime.now(),
        );
        if (entity.id.isEmpty || entity.id == '0') {
          final created = await _recipeRepository.createRecipe(entity);
          await _recipeLocalRepository.addRecipe(created);
        } else {
          final updated = await _recipeRepository.updateRecipe(entity);
          await _recipeLocalRepository.updateRecipe(updated);
        }
      }

      await loadRecipes(productId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<double> calculateRecipeCost(String productId) async {
    final productState = _ref.read(productProvider);
    final recipes = await _recipeLocalRepository.getLocalRecipes(
        organizationId: _ref.read(organizationProvider).selectedOrganizationId);
    final productRecipes = recipes.where((r) => r.productId == productId).toList();
    if (productRecipes.isEmpty) return 0.0;

    final conversions = await _ref
        .read(inventoryRepositoryProvider)
        .getUnitConversions(organizationId: _ref.read(organizationProvider).selectedOrganizationId);

    final costing = RecipeCostingService(
      products: productState.products,
      unitConversions: conversions,
    );

    return costing.calculateTotalCost(
      productId: productId,
      quantitySold: 1.0,
      recipes: productRecipes,
    );
  }

  Future<void> postCounterSale(
      List<Map<String, dynamic>> saleItems, Map<String, double> wastageMap) async {
    if (state.isPosting) {
      throw Exception('Sale is already being posted. Please wait.');
    }

    state = state.copyWith(isPosting: true, error: null);

    try {
      final orgId = _ref.read(organizationProvider).selectedOrganizationId;
      final storeId = _ref.read(organizationProvider).selectedStore?.id;
      if (orgId == null || storeId == null) {
        throw Exception('Organization or store not selected');
      }

      if (saleItems.isEmpty) {
        throw Exception('No sale items to post');
      }

      for (var item in saleItems) {
        final qtySold = (item['quantity_sold'] as num).toDouble();
        if (qtySold <= 0) {
          throw Exception('Quantity sold must be greater than zero for all items');
        }
      }

      final accounting = _ref.read(accountingProvider.notifier);
      final productState = _ref.read(productProvider);
      final recipes = await _recipeLocalRepository.getLocalRecipes(
          organizationId: orgId);
      final conversions = await _ref
          .read(inventoryRepositoryProvider)
          .getUnitConversions(organizationId: orgId);

      final sYear = accounting.validateAndGetSYear(DateTime.now());
      final glSetup = accounting.state.glSetup;
      if (glSetup == null) {
        throw Exception('GL Setup not configured. Please configure accounting first.');
      }

      final cashAccountId = glSetup.cashAccountId ?? glSetup.bankAccountId;
      if (cashAccountId == null) {
        throw Exception('Cash/Bank account not configured in GL Setup');
      }
      if (glSetup.salesAccountId == null) {
        throw Exception('Sales Revenue account not configured in GL Setup');
      }
      if (glSetup.cogsAccountId == null) {
        throw Exception('COGS account not configured in GL Setup');
      }
      if (glSetup.inventoryAccountId == null) {
        throw Exception('Inventory account not configured in GL Setup');
      }

      final prefixes = accounting.state.voucherPrefixes;
      final jvPrefix = prefixes.where((p) => p.prefixCode == 'JV').firstOrNull;
      if (jvPrefix == null) {
        throw Exception('Voucher Prefix JV not found');
      }

      final costing = RecipeCostingService(
        products: productState.products,
        unitConversions: conversions,
      );

      final saleId = const Uuid().v4();
      final saleDate = DateTime.now();
      var totalAmount = 0.0;
      var totalCost = 0.0;
      var totalProfit = 0.0;

      final saleItemsEntities = <RecipeSaleItem>[];
      final movements = <Map<String, dynamic>>[];

      for (var item in saleItems) {
        final productId = item['product_id'] as String;
        final qtySold = (item['quantity_sold'] as num).toDouble();
        final rate = (item['rate'] as num).toDouble();
        final amount = qtySold * rate;
        final wastageQty = wastageMap[productId] ?? 0.0;

        final productRecipes = recipes.where((r) => r.productId == productId).toList();
        if (productRecipes.isEmpty) {
          throw Exception('No recipe defined for product $productId');
        }

        final itemCost = costing.calculateTotalCost(
          productId: productId,
          quantitySold: qtySold,
          recipes: recipes,
        );

        final itemProfit = amount - itemCost;

        totalAmount += amount;
        totalCost += itemCost;
        totalProfit += itemProfit;

        saleItemsEntities.add(RecipeSaleItem(
          id: const Uuid().v4(),
          recipeSaleId: saleId,
          productId: productId,
          quantitySold: qtySold,
          rate: rate,
          amount: amount,
          cost: itemCost,
          profit: itemProfit,
          wastageQty: wastageQty,
        ));

        final consumptions = costing.calculateConsumptions(
          productId: productId,
          quantitySold: qtySold,
          recipes: recipes,
        );

        for (var c in consumptions) {
          final totalWastage = c.wastageQty + wastageQty;
          movements.add({
            'productId': c.componentProductId,
            'consumption': c.consumedQty,
            'wastage': totalWastage,
          });
        }
      }

      final sale = RecipeSale(
        id: saleId,
        organizationId: orgId,
        storeId: storeId,
        saleDate: saleDate,
        totalAmount: totalAmount,
        totalCost: totalCost,
        totalProfit: totalProfit,
        createdBy: null,
        createdAt: saleDate,
      );

      await _recipeSaleLocalRepository.saveRecipeSale(sale, saleItemsEntities,
          isSynced: false);

      try {
        final connectivityResult = await ConnectivityHelper.check();
        if (!connectivityResult.contains(ConnectivityResult.none)) {
          await _recipeSaleRepository.createRecipeSale(sale, saleItemsEntities);
          await _recipeSaleLocalRepository.markRecipeSaleAsSynced(saleId);
        }
      } catch (e) {
        debugPrint('RecipeProvider: Failed to push recipe sale: $e');
      }

      for (var m in movements) {
        final productId = m['productId'] as String;
        final consumptionQty = m['consumption'] as double;
        final wastageQty = m['wastage'] as double;

        try {
          await _postingService.postConsumption(
            organizationId: orgId,
            productId: productId,
            storeId: storeId,
            quantity: consumptionQty,
            referenceTable: 'omtbl_recipe_sales',
            referenceId: saleId,
          );
        } catch (e) {
          debugPrint('RecipeProvider: Failed to post consumption: $e');
          throw Exception('Failed to post inventory consumption: $e');
        }

        if (wastageQty > 0) {
          try {
            await _postingService.postWastage(
              organizationId: orgId,
              productId: productId,
              storeId: storeId,
              quantity: wastageQty,
              referenceTable: 'omtbl_recipe_sales',
              referenceId: saleId,
            );
          } catch (e) {
            debugPrint('RecipeProvider: Failed to post wastage: $e');
            throw Exception('Failed to post wastage: $e');
          }
        }
      }

      await _postRecipeGLTransactions(
        accounting: accounting,
        orgId: orgId,
        storeId: storeId,
        saleDate: saleDate,
        saleId: saleId,
        totalAmount: totalAmount,
        totalCost: totalCost,
      );

      _ref.read(syncProgressProvider.notifier).setSyncing(true, message: 'Syncing recipe sale...');
      _ref.read(syncServiceProvider).syncAll().catchError((e) {
        debugPrint('RecipeProvider: Background sync failed: $e');
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isPosting: false);
    }
  }

  Future<void> _postRecipeGLTransactions({
    required AccountingNotifier accounting,
    required int orgId,
    required int storeId,
    required DateTime saleDate,
    required String saleId,
    required double totalAmount,
    required double totalCost,
  }) async {
    final sYear = accounting.validateAndGetSYear(saleDate);
    final glSetup = accounting.state.glSetup;
    if (glSetup == null) {
      throw Exception('GL Setup not configured');
    }

    final cashAccountId = glSetup.cashAccountId ?? glSetup.bankAccountId;
    if (cashAccountId == null) {
      throw Exception('Cash/Bank account not configured in GL Setup');
    }

    final prefixes = accounting.state.voucherPrefixes;
    final jvPrefix = prefixes.where((p) => p.prefixCode == 'JV').firstOrNull;
    if (jvPrefix == null) {
      throw Exception('Voucher Prefix JV not found');
    }

    final baseVoucherNumber = 'CS-${saleId.substring(0, 8)}';

    // 1. Cash/Counter Cash Dr, Sales Revenue Cr
    final salesTx = Transaction(
      id: const Uuid().v4(),
      voucherPrefixId: jvPrefix.id,
      voucherNumber: baseVoucherNumber,
      voucherDate: saleDate,
      accountId: cashAccountId,
      offsetAccountId: glSetup.salesAccountId,
      amount: totalAmount,
      description: 'Counter Sale - ${baseVoucherNumber}',
      status: 'posted',
      organizationId: orgId,
      storeId: storeId,
      sYear: sYear,
      invoiceId: saleId,
    );

    // 2. COGS Dr, Inventory Cr
    final cogsTx = Transaction(
      id: const Uuid().v4(),
      voucherPrefixId: jvPrefix.id,
      voucherNumber: baseVoucherNumber,
      voucherDate: saleDate,
      accountId: glSetup.cogsAccountId,
      offsetAccountId: glSetup.inventoryAccountId,
      amount: totalCost,
      description: 'COGS - Counter Sale ${baseVoucherNumber}',
      status: 'posted',
      organizationId: orgId,
      storeId: storeId,
      sYear: sYear,
      invoiceId: saleId,
    );

    await accounting.createTransaction(salesTx);
    await accounting.createTransaction(cogsTx);
  }
}

final recipeProvider =
    StateNotifierProvider<RecipeNotifier, RecipeState>((ref) {
  final repo = ref.watch(productRecipeRepositoryProvider);
  final localRepo = ref.watch(productRecipeLocalRepositoryProvider);
  final saleRepo = ref.watch(recipeSaleRepositoryProvider);
  final saleLocalRepo = ref.watch(recipeSaleLocalRepositoryProvider);
  final postingService = InventoryPostingService();
  return RecipeNotifier(ref, repo, localRepo, saleRepo, saleLocalRepo, postingService);
});
