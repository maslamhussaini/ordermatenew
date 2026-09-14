import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/products/data/services/recipe_costing_service.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';

void main() {
  group('RecipeCostingService - Wastage', () {
    final products = [
      Product(
        id: 'p1',
        name: 'Meetha Paan',
        sku: 'PAAN',
        rate: 25.0,
        cost: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        uomId: 1,
        organizationId: 1,
      ),
      Product(
        id: 'c1',
        name: 'Gulkand',
        sku: 'GULKAND',
        rate: 0.0,
        cost: 0.05,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        uomId: 2,
        organizationId: 1,
      ),
    ];

    final conversions = [
      UnitConversion(
        id: 1,
        fromUnitId: 2,
        toUnitId: 2,
        conversionFactor: 1.0,
        organizationId: 1,
      ),
    ];

    test('wastage is separate from consumption - no double counting', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      // 100 Paan sold, 10g Gulkand each
      // Normal consumption = 100 * 10g = 1000g
      // Recipe wastage = 5% -> 50g wastage
      // Additional manual wastage = 20g
      // Total WASTAGE movement = 70g (50g from recipe + 20g manual)
      // Total inventory reduction = 1000g consumption + 70g wastage = 1070g

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 10.0,
          uomId: 2,
          wastagePercent: 5.0,
          organizationId: 1,
        ),
      ];

      final consumptions = service.calculateConsumptions(
        productId: 'p1',
        quantitySold: 100.0,
        recipes: recipes,
      );

      expect(consumptions.length, 1);
      expect(consumptions[0].consumedQty, 1000.0); // 100 * 10 = 1000g
      expect(consumptions[0].wastageQty, 50.0); // 5% of 1000 = 50g
      expect(consumptions[0].cost, 50.0); // 1000 * 0.05 = 50.0

      // Simulate posting: consumption = 1000g, wastage = 50g (recipe) + 20g (manual) = 70g
      final manualWastage = 20.0;
      final totalWastage = consumptions[0].wastageQty + manualWastage;
      expect(totalWastage, 70.0);

      // Total inventory reduction
      final totalReduction = consumptions[0].consumedQty + totalWastage;
      expect(totalReduction, 1070.0);
    });

    test('wastage is NOT included in CONSUMPTION movement', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 10.0,
          uomId: 2,
          wastagePercent: 5.0,
          organizationId: 1,
        ),
      ];

      final consumptions = service.calculateConsumptions(
        productId: 'p1',
        quantitySold: 100.0,
        recipes: recipes,
      );

      // consumedQty should be pure consumption: 100 * 10 = 1000g
      // NOT 1000 + 50 = 1050g
      expect(consumptions[0].consumedQty, 1000.0);
      expect(consumptions[0].wastageQty, 50.0);

      // Verify consumedQty does NOT include wastage
      expect(consumptions[0].consumedQty, isNot(equals(1050.0)));
    });

    test('zero wastage percent results in zero wastage qty', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 10.0,
          uomId: 2,
          wastagePercent: 0.0,
          organizationId: 1,
        ),
      ];

      final consumptions = service.calculateConsumptions(
        productId: 'p1',
        quantitySold: 100.0,
        recipes: recipes,
      );

      expect(consumptions[0].consumedQty, 1000.0);
      expect(consumptions[0].wastageQty, 0.0);
    });
  });
}
