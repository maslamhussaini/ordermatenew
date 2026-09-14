import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/products/data/services/recipe_costing_service.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';

void main() {
  group('RecipeCostingService', () {
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
      Product(
        id: 'c2',
        name: 'Paan Leaf',
        sku: 'LEAF',
        rate: 0.0,
        cost: 0.10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        uomId: 3,
        organizationId: 1,
      ),
    ];

    final conversions = [
      const UnitConversion(
        id: 1,
        fromUnitId: 2,
        toUnitId: 3,
        conversionFactor: 10.0,
        organizationId: 1,
      ),
    ];

    test('calculates total cost for simple recipe', () {
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
        ProductRecipe(
          id: 'r2',
          productId: 'p1',
          componentProductId: 'c2',
          quantity: 1.0,
          uomId: 3,
          wastagePercent: 0.0,
          organizationId: 1,
        ),
      ];

      final cost = service.calculateTotalCost(
        productId: 'p1',
        quantitySold: 1.0,
        recipes: recipes,
      );

      expect(cost, 0.6);
    });

    test('calculates cost with UOM conversion', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 5.0,
          uomId: 2, // using UOM 2 (Gulkand) for ingredient c1
          wastagePercent: 0.0,
          organizationId: 1,
        ),
      ];

      final cost = service.calculateTotalCost(
        productId: 'p1',
        quantitySold: 2.0,
        recipes: recipes,
      );

      expect(cost, 0.5);
    });

    test('throws when no recipe is defined', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      expect(
        () => service.calculateTotalCost(
          productId: 'p1',
          quantitySold: 1.0,
          recipes: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when component product is missing', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: conversions,
      );

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'missing',
          quantity: 1.0,
          uomId: 1,
          wastagePercent: 0.0,
          organizationId: 1,
        ),
      ];

      expect(
        () => service.calculateTotalCost(
          productId: 'p1',
          quantitySold: 1.0,
          recipes: recipes,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when UOM conversion is missing', () {
      final service = RecipeCostingService(
        products: products,
        unitConversions: const [],
      );

      final recipes = [
        ProductRecipe(
          id: 'r1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 1.0,
          uomId: 3, // different from component's UOM 2
          wastagePercent: 0.0,
          organizationId: 1,
        ),
      ];

      expect(
        () => service.calculateTotalCost(
          productId: 'p1',
          quantitySold: 1.0,
          recipes: recipes,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('calculateConsumptions returns correct quantities', () {
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
          uomId: 2, // same as component UOM
          wastagePercent: 5.0,
          organizationId: 1,
        ),
      ];

      final consumptions = service.calculateConsumptions(
        productId: 'p1',
        quantitySold: 2.0,
        recipes: recipes,
      );

      expect(consumptions.length, 1);
      expect(consumptions[0].consumedQty, 20.0);
      expect(consumptions[0].wastageQty, 1.0);
      expect(consumptions[0].cost, 1.0);
    });
  });
}
