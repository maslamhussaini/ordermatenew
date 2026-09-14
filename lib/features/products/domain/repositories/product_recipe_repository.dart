import '../entities/product_recipe.dart';

abstract class ProductRecipeRepository {
  Future<List<ProductRecipe>> getRecipes({int? organizationId});
  Future<ProductRecipe> getRecipeById(String id);
  Future<List<ProductRecipe>> getRecipesByProduct(
      String productId, int organizationId);
  Future<ProductRecipe> createRecipe(ProductRecipe recipe);
  Future<ProductRecipe> updateRecipe(ProductRecipe recipe);
  Future<void> deleteRecipe(String id);
}
