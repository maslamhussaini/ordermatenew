import 'package:uuid/uuid.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/products/data/models/product_model.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/features/products/data/repositories/product_local_repository.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalRepository _localRepository = ProductLocalRepository();

  @override
  Future<List<Product>> getProducts({int? storeId, int? organizationId}) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalProducts(
          storeId: storeId, organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client.from('omtbl_products').select(
            '*, omtbl_businesspartners(name), omtbl_producttypes(producttype), omtbl_categories(category), omtbl_brands(brandtype), omtbl_units_of_measure(unit_symbol)',
          );

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query
          .eq('is_active', 1)
          .order('created_at', ascending: false)
          .limit(1000)
          .timeout(const Duration(seconds: 20));

      final products = (response as List)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
          'ProductRepo: Fetched ${products.length} products from Supabase');

      await _localRepository.cacheProducts(products);

      return products;
    } catch (e) {
      debugPrint('ProductRepo: Fetch failed: $e');
      try {
        final localProducts = await _localRepository.getLocalProducts(
            storeId: storeId, organizationId: organizationId);
        if (localProducts.isNotEmpty) {
          debugPrint(
              'ProductRepo: Returning ${localProducts.length} local products as fallback');
          return localProducts;
        }
      } catch (_) {}
      throw Exception('Failed to fetch products: $e');
    }
  }

  @override
  Future<Product> getProductById(String id) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_products')
          .select(
            '*, omtbl_businesspartners(name), omtbl_producttypes(producttype), omtbl_categories(category), omtbl_brands(brandtype), omtbl_units_of_measure(unit_symbol)',
          )
          .eq('id', id)
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  @override
  Future<Product> createProduct(Product product) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.addProduct(product);
      return product;
    }

    try {
      final model = ProductModel(
        id: product.id,
        name: product.name,
        sku: product.sku,
        rate: product.rate,
        cost: product.cost,
        description: product.description,
        businessPartnerId: product.businessPartnerId,
        productTypeId: product.productTypeId,
        categoryId: product.categoryId,
        brandId: product.brandId,
        uomId: product.uomId,
        uomSymbol: product.uomSymbol,
        baseQuantity: product.baseQuantity,
        organizationId: product.organizationId,
        isActive: product.isActive,
        limitPrice: product.limitPrice,
        stockQty: product.stockQty,
        inventoryGlId: product.inventoryGlId,
        cogsGlId: product.cogsGlId,
        revenueGlId: product.revenueGlId,
        defaultDiscountPercent: product.defaultDiscountPercent,
        defaultDiscountPercentLimit: product.defaultDiscountPercentLimit,
        salesDiscountGlId: product.salesDiscountGlId,
        isRecipe: product.isRecipe,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
      );

      final json = model.toJson();
      json.remove('uom_symbol');
      json.remove('created_at');

      // FIX (C-6): supply a client-generated UUID primary key so the write is
      // idempotent. Previously the id was stripped and the row inserted, so a
      // retry after a lost response created a duplicate product. `id` is an
      // existing uuid primary key — no schema change is implied here.
      final existingId = (json['id'] as String?)?.trim() ?? '';
      json['id'] = existingId.isEmpty ? const Uuid().v4() : existingId;

      // Sanitize UUID fields
      if (json['business_partner_id'] == '') {
        json['business_partner_id'] = null;
      }

      final response = await SupabaseConfig.client
          .from('omtbl_products')
          .upsert(json)
          .select(
            '*, omtbl_businesspartners(name), omtbl_producttypes(producttype), omtbl_categories(category), omtbl_brands(brandtype), omtbl_units_of_measure(unit_symbol)',
          )
          .single()
          .timeout(const Duration(seconds: 15));

      final newItem = ProductModel.fromJson(response);

      // Cache the new item
      await _localRepository.cacheProducts([newItem]);

      return newItem;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        await _localRepository.addProduct(product);
        return product;
      }
      throw Exception('Failed to create product: $e');
    }
  }

  @override
  Future<Product> updateProduct(Product product) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.updateProduct(product);
      return product;
    }

    try {
      final model = ProductModel(
        id: product.id,
        name: product.name,
        sku: product.sku,
        rate: product.rate,
        cost: product.cost,
        description: product.description,
        businessPartnerId: product.businessPartnerId,
        productTypeId: product.productTypeId,
        categoryId: product.categoryId,
        brandId: product.brandId,
        uomId: product.uomId,
        uomSymbol: product.uomSymbol,
        baseQuantity: product.baseQuantity,
        organizationId: product.organizationId,
        isActive: product.isActive,
        limitPrice: product.limitPrice,
        stockQty: product.stockQty,
        inventoryGlId: product.inventoryGlId,
        cogsGlId: product.cogsGlId,
        revenueGlId: product.revenueGlId,
        defaultDiscountPercent: product.defaultDiscountPercent,
        defaultDiscountPercentLimit: product.defaultDiscountPercentLimit,
        salesDiscountGlId: product.salesDiscountGlId,
        isRecipe: product.isRecipe,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
      );

      final json = model.toJson();
      json.remove('id');
      json.remove('uom_symbol');
      json.remove('created_at');

      // Sanitize UUID fields
      if (json['business_partner_id'] == '') {
        json['business_partner_id'] = null;
      }

      final response = await SupabaseConfig.client
          .from('omtbl_products')
          .update(json)
          .eq('id', product.id)
          .select(
            '*, omtbl_businesspartners(name), omtbl_producttypes(producttype), omtbl_categories(category), omtbl_brands(brandtype), omtbl_units_of_measure(unit_symbol)',
          )
          .single()
          .timeout(const Duration(seconds: 15));

      final updatedItem = ProductModel.fromJson(response);
      await _localRepository.cacheProducts([updatedItem]);

      return updatedItem;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        await _localRepository.updateProduct(product);
        return product;
      }
      throw Exception('Failed to update product: $e');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Offline Delete
      await _localRepository.deleteProduct(id);
      return;
    }

    try {
      // Soft delete online
      await SupabaseConfig.client
          .from('omtbl_products')
          .update({'is_active': false}).eq('id', id);

      // Also delete from local if successful, so it disappears immediately
      await _localRepository.deleteProduct(id);
    } catch (e) {
      debugPrint('Online delete product failed: $e. Falling back to local.');
      // Optimize fallback
      try {
        await _localRepository.deleteProduct(id);
      } catch (localE) {
        throw Exception('Failed to delete product: $e');
      }
    }
  }
}
