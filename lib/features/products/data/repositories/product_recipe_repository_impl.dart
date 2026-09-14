import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/products/data/models/product_recipe_model.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/domain/repositories/product_recipe_repository.dart';

class ProductRecipeRepositoryImpl implements ProductRecipeRepository {
  @override
  Future<List<ProductRecipe>> getRecipes({int? organizationId}) async {
    var query = SupabaseConfig.client.from('omtbl_product_recipes').select();
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    final response = await query.timeout(const Duration(seconds: 15));
    return (response as List)
        .map((json) => ProductRecipeModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProductRecipe> getRecipeById(String id) async {
    final response = await SupabaseConfig.client
        .from('omtbl_product_recipes')
        .select()
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    return ProductRecipeModel.fromJson(response);
  }

  @override
  Future<List<ProductRecipe>> getRecipesByProduct(
      String productId, int organizationId) async {
    final response = await SupabaseConfig.client
        .from('omtbl_product_recipes')
        .select()
        .eq('product_id', productId)
        .eq('organization_id', organizationId)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((json) => ProductRecipeModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProductRecipe> createRecipe(ProductRecipe recipe) async {
    final model = ProductRecipeModel.fromEntity(recipe);
    final json = model.toJson();
    final response = await SupabaseConfig.client
        .from('omtbl_product_recipes')
        .insert(json)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return ProductRecipeModel.fromJson(response);
  }

  @override
  Future<ProductRecipe> updateRecipe(ProductRecipe recipe) async {
    final model = ProductRecipeModel.fromEntity(recipe);
    final json = model.toJson();
    final response = await SupabaseConfig.client
        .from('omtbl_product_recipes')
        .update(json)
        .eq('id', recipe.id)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return ProductRecipeModel.fromJson(response);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await SupabaseConfig.client
        .from('omtbl_product_recipes')
        .delete()
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
  }
}
