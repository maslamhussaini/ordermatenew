import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';

class RecipeCostingService {
  final List<Product> products;
  final List<UnitConversion> unitConversions;

  RecipeCostingService({
    required this.products,
    required this.unitConversions,
  });

  /// Calculates the total cost to produce [quantitySold] units of the product
  /// identified by [productId], using its recipe ingredients.
  ///
  /// Throws [StateError] if:
  /// - No recipe is defined for the product.
  /// - A required UOM conversion is missing.
  double calculateTotalCost({
    required String productId,
    required double quantitySold,
    required List<ProductRecipe> recipes,
  }) {
    final ingredientRecipes =
        recipes.where((r) => r.productId == productId).toList();
    if (ingredientRecipes.isEmpty) {
      throw StateError('No recipe defined for product $productId');
    }

    double totalCost = 0.0;
    for (final recipe in ingredientRecipes) {
      final component = _findProduct(recipe.componentProductId);
      if (component == null) {
        throw StateError(
            'Component product ${recipe.componentProductId} not found');
      }

      final conversionFactor = _getConversionFactor(
        fromUnitId: recipe.uomId,
        toUnitId: component.uomId,
      );
      if (conversionFactor == null) {
        throw StateError(
            'Missing UOM conversion from ${recipe.uomId} to ${component.uomId} for component ${component.id}');
      }

      final consumedQty = quantitySold * recipe.quantity * conversionFactor;
      totalCost += consumedQty * component.cost;
    }
    return totalCost;
  }

  /// Returns per-ingredient consumption details for a sale of [quantitySold]
  /// units. Used for inventory posting.
  List<IngredientConsumption> calculateConsumptions({
    required String productId,
    required double quantitySold,
    required List<ProductRecipe> recipes,
  }) {
    final ingredientRecipes =
        recipes.where((r) => r.productId == productId).toList();
    if (ingredientRecipes.isEmpty) {
      throw StateError('No recipe defined for product $productId');
    }

    final consumptions = <IngredientConsumption>[];
    for (final recipe in ingredientRecipes) {
      final component = _findProduct(recipe.componentProductId);
      if (component == null) {
        throw StateError(
            'Component product ${recipe.componentProductId} not found');
      }

      final conversionFactor = _getConversionFactor(
        fromUnitId: recipe.uomId,
        toUnitId: component.uomId,
      );
      if (conversionFactor == null) {
        throw StateError(
            'Missing UOM conversion from ${recipe.uomId} to ${component.uomId} for component ${component.id}');
      }

      final consumedQty = quantitySold * recipe.quantity * conversionFactor;
      final wastageQty = consumedQty * (recipe.wastagePercent / 100.0);

      consumptions.add(IngredientConsumption(
        componentProductId: recipe.componentProductId,
        consumedQty: consumedQty,
        wastageQty: wastageQty,
        uomId: component.uomId,
        cost: consumedQty * component.cost,
      ));
    }
    return consumptions;
  }

  Product? _findProduct(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } on StateError {
      return null;
    }
  }

  double? _getConversionFactor({
    required int fromUnitId,
    required int? toUnitId,
  }) {
    if (toUnitId == null) return null;
    if (fromUnitId == toUnitId) return 1.0;

    try {
      final conv = unitConversions.firstWhere(
        (c) => c.fromUnitId == fromUnitId && c.toUnitId == toUnitId,
      );
      return conv.conversionFactor;
    } on StateError {
      return null;
    }
  }
}

class IngredientConsumption {
  final String componentProductId;
  final double consumedQty;
  final double wastageQty;
  final int? uomId;
  final double cost;

  const IngredientConsumption({
    required this.componentProductId,
    required this.consumedQty,
    required this.wastageQty,
    this.uomId,
    required this.cost,
  });
}
