import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/products/data/models/recipe_sale_model.dart';
import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';
import 'package:ordermate/features/products/domain/repositories/recipe_sale_repository.dart';

class RecipeSaleRepositoryImpl implements RecipeSaleRepository {
  @override
  Future<List<RecipeSale>> getRecipeSales({int? organizationId, int? storeId}) async {
    var query = SupabaseConfig.client.from('omtbl_recipe_sales').select();
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    if (storeId != null) {
      query = query.eq('store_id', storeId);
    }
    final response = await query
        .order('sale_date', ascending: false)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((json) => RecipeSaleModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RecipeSale> getRecipeSaleById(String id) async {
    final response = await SupabaseConfig.client
        .from('omtbl_recipe_sales')
        .select()
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    return RecipeSaleModel.fromJson(response);
  }

  @override
  Future<List<RecipeSaleItem>> getRecipeSaleItems(String recipeSaleId) async {
    final response = await SupabaseConfig.client
        .from('omtbl_recipe_sale_items')
        .select()
        .eq('recipe_sale_id', recipeSaleId)
        .timeout(const Duration(seconds: 15));
    return (response as List)
        .map((json) => RecipeSaleItemModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RecipeSale> createRecipeSale(
      RecipeSale sale, List<RecipeSaleItem> items) async {
    final saleModel = RecipeSaleModel.fromEntity(sale);
    final saleJson = saleModel.toJson();
    saleJson.remove('id');

    final response = await SupabaseConfig.client
        .from('omtbl_recipe_sales')
        .insert(saleJson)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));

    final createdSale = RecipeSaleModel.fromJson(response);

    final itemModels = items
        .map((item) => RecipeSaleItemModel(
              id: item.id.isEmpty ? '' : item.id,
              recipeSaleId: createdSale.id,
              productId: item.productId,
              quantitySold: item.quantitySold,
              rate: item.rate,
              amount: item.amount,
              cost: item.cost,
              profit: item.profit,
              wastageQty: item.wastageQty,
            ))
        .toList();

    for (var m in itemModels) {
      final j = m.toJson();
      if (j['id'] == '') j.remove('id');
      await SupabaseConfig.client
          .from('omtbl_recipe_sale_items')
          .insert(j)
          .timeout(const Duration(seconds: 15));
    }

    return createdSale;
  }

  @override
  Future<RecipeSale> updateRecipeSale(
      RecipeSale sale, List<RecipeSaleItem> items) async {
    final saleModel = RecipeSaleModel.fromEntity(sale);
    final saleJson = saleModel.toJson();
    saleJson.remove('id');

    final response = await SupabaseConfig.client
        .from('omtbl_recipe_sales')
        .update(saleJson)
        .eq('id', sale.id)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));

    final updatedSale = RecipeSaleModel.fromJson(response);

    await SupabaseConfig.client
        .from('omtbl_recipe_sale_items')
        .delete()
        .eq('recipe_sale_id', sale.id)
        .timeout(const Duration(seconds: 15));

    final itemModels = items
        .map((item) => RecipeSaleItemModel(
              id: item.id.isEmpty ? '' : item.id,
              recipeSaleId: updatedSale.id,
              productId: item.productId,
              quantitySold: item.quantitySold,
              rate: item.rate,
              amount: item.amount,
              cost: item.cost,
              profit: item.profit,
              wastageQty: item.wastageQty,
            ))
        .toList();

    for (var m in itemModels) {
      final j = m.toJson();
      if (j['id'] == '') j.remove('id');
      await SupabaseConfig.client
          .from('omtbl_recipe_sale_items')
          .insert(j)
          .timeout(const Duration(seconds: 15));
    }

    return updatedSale;
  }

  @override
  Future<void> deleteRecipeSale(String id) async {
    await SupabaseConfig.client
        .from('omtbl_recipe_sale_items')
        .delete()
        .eq('recipe_sale_id', id)
        .timeout(const Duration(seconds: 15));
    await SupabaseConfig.client
        .from('omtbl_recipe_sales')
        .delete()
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
  }
}
