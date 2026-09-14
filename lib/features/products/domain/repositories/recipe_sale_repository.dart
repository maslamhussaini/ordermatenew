import '../entities/recipe_sale.dart';

abstract class RecipeSaleRepository {
  Future<List<RecipeSale>> getRecipeSales({int? organizationId, int? storeId});
  Future<RecipeSale> getRecipeSaleById(String id);
  Future<List<RecipeSaleItem>> getRecipeSaleItems(String recipeSaleId);
  Future<RecipeSale> createRecipeSale(RecipeSale sale, List<RecipeSaleItem> items);
  Future<RecipeSale> updateRecipeSale(RecipeSale sale, List<RecipeSaleItem> items);
  Future<void> deleteRecipeSale(String id);
}
