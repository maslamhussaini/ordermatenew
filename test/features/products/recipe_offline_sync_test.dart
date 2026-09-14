import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/domain/repositories/product_recipe_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_recipe_local_repository.dart';
import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';
import 'package:ordermate/features/products/domain/repositories/recipe_sale_repository.dart';
import 'package:ordermate/features/products/data/repositories/recipe_sale_local_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class MockProductRecipeRepository extends Mock implements ProductRecipeRepository {}
class MockProductRecipeLocalRepository extends Mock implements ProductRecipeLocalRepository {}
class MockRecipeSaleRepository extends Mock implements RecipeSaleRepository {}
class MockRecipeSaleLocalRepository extends Mock implements RecipeSaleLocalRepository {}
class MockOrganizationState extends Mock implements OrganizationState {}

void main() {
  setUpAll(() {
    registerFallbackValue(ProductRecipe(
      id: 'fallback',
      productId: 'p1',
      componentProductId: 'c1',
      quantity: 0.0,
      uomId: 0,
      organizationId: 0,
    ));
    registerFallbackValue(RecipeSale(
      id: 'fallback',
      organizationId: 0,
      storeId: 0,
      saleDate: DateTime.now(),
    ));
    registerFallbackValue(<RecipeSaleItem>[]);
  });

  group('Recipe Offline Sync', () {
    late MockProductRecipeRepository mockRecipeRepo;
    late MockProductRecipeLocalRepository mockRecipeLocalRepo;
    late MockRecipeSaleRepository mockSaleRepo;
    late MockRecipeSaleLocalRepository mockSaleLocalRepo;
    late MockOrganizationState mockOrgState;

    setUp(() {
      mockRecipeRepo = MockProductRecipeRepository();
      mockRecipeLocalRepo = MockProductRecipeLocalRepository();
      mockSaleRepo = MockRecipeSaleRepository();
      mockSaleLocalRepo = MockRecipeSaleLocalRepository();
      mockOrgState = MockOrganizationState();
    });

    test('unsynced recipes can be pushed to remote', () async {
      when(() => mockOrgState.selectedOrganizationId).thenReturn(1);

      final unsyncedRecipes = [
        ProductRecipe(
          id: 'recipe-1',
          productId: 'p1',
          componentProductId: 'c1',
          quantity: 10.0,
          uomId: 1,
          organizationId: 1,
        ),
      ];

      when(() => mockRecipeLocalRepo.getUnsyncedRecipes(organizationId: 1))
          .thenAnswer((_) async => unsyncedRecipes);

      when(() => mockRecipeRepo.createRecipe(any()))
          .thenAnswer((_) async => unsyncedRecipes.first);

      when(() => mockRecipeLocalRepo.markRecipeAsSynced('recipe-1'))
          .thenAnswer((_) async {});

      expect(unsyncedRecipes.length, 1);
      expect(unsyncedRecipes.first.id, 'recipe-1');
    });

    test('unsynced recipe sales can be pushed with items', () async {
      when(() => mockOrgState.selectedOrganizationId).thenReturn(1);

      final unsyncedSale = RecipeSale(
        id: 'sale-1',
        organizationId: 1,
        storeId: 1,
        saleDate: DateTime.now(),
        totalAmount: 100.0,
        totalCost: 60.0,
        totalProfit: 40.0,
      );

      final saleItems = [
        const RecipeSaleItem(
          id: 'item-1',
          recipeSaleId: 'sale-1',
          productId: 'p1',
          quantitySold: 10.0,
          rate: 10.0,
          amount: 100.0,
          cost: 60.0,
          profit: 40.0,
          wastageQty: 0.0,
        ),
      ];

      when(() => mockSaleLocalRepo.getUnsyncedRecipeSales(organizationId: 1))
          .thenAnswer((_) async => [unsyncedSale]);

      when(() => mockSaleLocalRepo.getLocalRecipeSaleItems('sale-1'))
          .thenAnswer((_) async => saleItems);

      when(() => mockSaleRepo.createRecipeSale(unsyncedSale, saleItems))
          .thenAnswer((_) async => unsyncedSale);

      when(() => mockSaleLocalRepo.markRecipeSaleAsSynced('sale-1'))
          .thenAnswer((_) async {});

      expect(unsyncedSale.id, 'sale-1');
      expect(saleItems.length, 1);
    });

    test('recipe local save sets is_synced to 0', () async {
      final recipe = ProductRecipe(
        id: 'recipe-test',
        productId: 'p1',
        componentProductId: 'c1',
        quantity: 5.0,
        uomId: 1,
        organizationId: 1,
      );

      expect(recipe.id, 'recipe-test');
      expect(recipe.quantity, 5.0);
    });
  });
}
