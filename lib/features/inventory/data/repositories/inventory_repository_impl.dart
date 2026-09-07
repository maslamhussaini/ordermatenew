import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/inventory/data/models/brand_model.dart';
import 'package:ordermate/features/inventory/data/models/product_category_model.dart';
import 'package:ordermate/features/inventory/data/models/product_type_model.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/inventory/data/models/unit_of_measure_model.dart';
import 'package:ordermate/features/inventory/data/models/unit_conversion_model.dart';
import 'package:ordermate/features/inventory/domain/repositories/inventory_repository.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/features/inventory/data/repositories/inventory_local_repository.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl();
  final InventoryLocalRepository _localRepository = InventoryLocalRepository();

  // ==========================
  // BRANDS
  // ==========================

  @override
  Future<List<Brand>> getBrands({int? organizationId}) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalBrands(organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client
          .from('omtbl_brands')
          .select('*')
          .eq('status', 1);

      if (organizationId != null && organizationId != 0) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }

      final response = await query
          .order('brandtype', ascending: true)
          .limit(1000)
          .timeout(const Duration(seconds: 15));

      final List<Brand> items = (response as List)
          .map<Brand>(
              (json) => BrandModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache
      // Cache
      await _localRepository.cacheBrands(items);

      // Merge Unsynced
      final unsynced = await _localRepository.getUnsyncedBrands(
          organizationId: organizationId);
      if (unsynced.isNotEmpty) {
        final existingIds = items.map((e) => e.id).toSet();
        for (var u in unsynced) {
          if (!existingIds.contains(u.id)) {
            items.add(u);
          } else {
            // Replace server item with local edit
            final index = items.indexWhere((e) => e.id == u.id);
            if (index != -1) items[index] = u;
          }
        }
      }
      return items;
    } catch (e) {
      if (!SupabaseConfig.isOfflineLoggedIn) {
        try {
          final localItems = await _localRepository.getLocalBrands(
              organizationId: organizationId);
          if (localItems.isNotEmpty) return localItems;
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<Brand> createBrand(Brand brand) async {
    final model = BrandModel(
      id: brand.id,
      name: brand.name,
      status: brand.status,
      organizationId: brand.organizationId,
      createdAt: brand.createdAt,
    );
    final json = model.toJson();
    if (model.id == 0) {
      json.remove('idbrand');
    }

    if (SupabaseConfig.isOfflineLoggedIn) {
      final newId = await _localRepository.saveBrand(model, isSynced: false);
      return BrandModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_brands')
          .insert(json)
          .select()
          .single();

      final newBrand = BrandModel.fromJson(response);
      await _localRepository.saveBrand(newBrand, isSynced: true);
      return newBrand;
    } catch (e) {
      final newId = await _localRepository.saveBrand(model, isSynced: false);
      return BrandModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }
  }

  @override
  Future<void> updateBrand(Brand brand) async {
    final model = BrandModel(
      id: brand.id,
      name: brand.name,
      status: brand.status,
      organizationId: brand.organizationId,
      createdAt: brand.createdAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveBrand(model, isSynced: false);
      return;
    }

    try {
      final updateJson = model.toJson();

      await SupabaseConfig.client
          .from('omtbl_brands')
          .update(updateJson)
          .eq('idbrand', brand.id);
      await _localRepository.saveBrand(model, isSynced: true);
    } catch (e) {
      await _localRepository.saveBrand(model, isSynced: false);
    }
  }

  @override
  Future<void> deleteBrand(int id) async {
    final db = await DatabaseHelper.instance.database;
    // Hard delete locally if we are online and success is expected,
    // BUT to be safe for offline sync we might need to keep it?
    // For now, let's just hard delete per user request.

    if (SupabaseConfig.isOfflineLoggedIn) {
      // Offline: Soft delete locally to mark for sync later (if we had a sync service)
      // But since user wants hard delete verification, we might just assume online for now
      await db.update('local_brands', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
      return;
    }

    try {
      // Server Hard Delete
      await SupabaseConfig.client
          .from('omtbl_brands')
          .delete()
          .eq('idbrand', id);

      // Local Hard Delete on success
      await db.delete('local_brands', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      // If server failed, stick to soft delete locally?
      // Or rethrow. Let's rethrow to show error.
      rethrow;
    }
  }

  // ==========================
  // CATEGORIES
  // ==========================

  @override
  Future<List<ProductCategory>> getCategories({int? organizationId}) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalCategories(
          organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client
          .from('omtbl_categories')
          .select('*')
          .eq('status', 1);

      if (organizationId != null && organizationId != 0) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }

      final response = await query
          .order('category', ascending: true)
          .limit(1000)
          .timeout(const Duration(seconds: 15));

      final List<ProductCategory> items = (response as List)
          .map<ProductCategory>((json) =>
              ProductCategoryModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache
      // Cache
      await _localRepository.cacheCategories(items);

      // Merge Unsynced
      final unsynced = await _localRepository.getUnsyncedCategories(
          organizationId: organizationId);
      if (unsynced.isNotEmpty) {
        final existingIds = items.map((e) => e.id).toSet();
        for (var u in unsynced) {
          if (!existingIds.contains(u.id)) {
            items.add(u);
          } else {
            final index = items.indexWhere((e) => e.id == u.id);
            if (index != -1) items[index] = u;
          }
        }
      }
      return items;
    } catch (e) {
      // Fallback
      try {
        final localItems = await _localRepository.getLocalCategories(
            organizationId: organizationId);
        if (localItems.isNotEmpty) return localItems;
      } catch (_) {}
      throw Exception('Failed to fetch categories: $e');
    }
  }

  @override
  Future<ProductCategory> createCategory(ProductCategory category) async {
    final model = ProductCategoryModel(
      id: category.id,
      name: category.name,
      status: category.status,
      organizationId: category.organizationId,
      createdAt: category.createdAt,
    );
    final json = model.toJson();
    if (model.id == 0) {
      json.remove('idcategory');
    }

    if (SupabaseConfig.isOfflineLoggedIn) {
      final newId = await _localRepository.saveCategory(model, isSynced: false);
      return ProductCategoryModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_categories')
          .insert(json)
          .select()
          .single();

      final newCat = ProductCategoryModel.fromJson(response);
      await _localRepository.saveCategory(newCat, isSynced: true);
      return newCat;
    } catch (e) {
      final newId = await _localRepository.saveCategory(model, isSynced: false);
      return ProductCategoryModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }
  }

  @override
  Future<void> updateCategory(ProductCategory category) async {
    final model = ProductCategoryModel(
      id: category.id,
      name: category.name,
      status: category.status,
      organizationId: category.organizationId,
      createdAt: category.createdAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveCategory(model, isSynced: false);
      return;
    }

    try {
      final updateJson = model.toJson();

      await SupabaseConfig.client
          .from('omtbl_categories')
          .update(updateJson)
          .eq('idcategory', category.id);
      await _localRepository.saveCategory(model, isSynced: true);
    } catch (e) {
      await _localRepository.saveCategory(model, isSynced: false);
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    final db = await DatabaseHelper.instance.database;

    if (SupabaseConfig.isOfflineLoggedIn) {
      await db.update('local_categories', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
      return;
    }

    try {
      // Server Hard Delete
      await SupabaseConfig.client
          .from('omtbl_categories')
          .delete()
          .eq('idcategory', id);

      // Local Hard Delete
      await db.delete('local_categories', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  // ==========================
  // PRODUCT TYPES
  // ==========================

  @override
  Future<List<ProductType>> getProductTypes({int? organizationId}) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalProductTypes(
          organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client
          .from('omtbl_producttypes')
          .select('*')
          .eq('status', 1);

      if (organizationId != null && organizationId != 0) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }

      final response = await query
          .order('producttype', ascending: true)
          .limit(1000)
          .timeout(const Duration(seconds: 15));

      final List<ProductType> items = (response as List)
          .map<ProductType>(
              (json) => ProductTypeModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache
      // Cache
      await _localRepository.cacheProductTypes(items);

      // Merge Unsynced
      final unsynced = await _localRepository.getUnsyncedProductTypes(
          organizationId: organizationId);
      if (unsynced.isNotEmpty) {
        final existingIds = items.map((e) => e.id).toSet();
        for (var u in unsynced) {
          if (!existingIds.contains(u.id)) {
            items.add(u);
          } else {
            final index = items.indexWhere((e) => e.id == u.id);
            if (index != -1) items[index] = u;
          }
        }
      }
      return items;
    } catch (e) {
      // Fallback
      try {
        final localItems = await _localRepository.getLocalProductTypes(
            organizationId: organizationId);
        if (localItems.isNotEmpty) return localItems;
      } catch (_) {}
      throw Exception('Failed to fetch product types: $e');
    }
  }

  @override
  Future<ProductType> createProductType(ProductType type) async {
    final model = ProductTypeModel(
      id: type.id,
      name: type.name,
      status: type.status,
      organizationId: type.organizationId,
      createdAt: type.createdAt,
    );
    final json = model.toJson();
    if (model.id == 0) {
      json.remove('idproducttype');
    }

    if (SupabaseConfig.isOfflineLoggedIn) {
      final newId =
          await _localRepository.saveProductType(model, isSynced: false);
      return ProductTypeModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_producttypes')
          .insert(json)
          .select()
          .single();

      final newType = ProductTypeModel.fromJson(response);
      await _localRepository.saveProductType(newType, isSynced: true);
      return newType;
    } catch (e) {
      final newId =
          await _localRepository.saveProductType(model, isSynced: false);
      return ProductTypeModel(
        id: newId,
        name: model.name,
        status: model.status,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
      );
    }
  }

  @override
  Future<void> updateProductType(ProductType type) async {
    final model = ProductTypeModel(
      id: type.id,
      name: type.name,
      status: type.status,
      organizationId: type.organizationId,
      createdAt: type.createdAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveProductType(model, isSynced: false);
      return;
    }

    try {
      final updateJson = model.toJson();

      await SupabaseConfig.client
          .from('omtbl_producttypes')
          .update(updateJson)
          .eq('idproducttype', type.id);
      await _localRepository.saveProductType(model, isSynced: true);
    } catch (e) {
      await _localRepository.saveProductType(model, isSynced: false);
    }
  }

  @override
  Future<void> deleteProductType(int id) async {
    final db = await DatabaseHelper.instance.database;

    if (SupabaseConfig.isOfflineLoggedIn) {
      await db.update('local_product_types', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_producttypes')
          .delete()
          .eq('idproducttype', id);

      await db.delete('local_product_types', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  // ==========================
  // UNITS OF MEASURE
  // ==========================

  @override
  Future<List<UnitOfMeasure>> getUnitsOfMeasure({int? organizationId}) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalUnitsOfMeasure(
          organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client.from('omtbl_units_of_measure').select();

      if (organizationId != null) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }

      final response = await query
          .order('unit_name', ascending: true)
          .timeout(const Duration(seconds: 15));

      final List<UnitOfMeasure> items = (response as List)
          .map<UnitOfMeasure>((json) =>
              UnitOfMeasureModel.fromJson(json as Map<String, dynamic>))
          .toList();

      await _localRepository.cacheUnitsOfMeasure(items);

      // Merge Unsynced
      final unsynced = await _localRepository.getUnsyncedUnitsOfMeasure(
          organizationId: organizationId);
      if (unsynced.isNotEmpty) {
        final existingIds = items.map((e) => e.id).toSet();
        for (var u in unsynced) {
          if (!existingIds.contains(u.id)) {
            items.add(u);
          } else {
            final index = items.indexWhere((e) => e.id == u.id);
            if (index != -1) items[index] = u;
          }
        }
      }
      return items;
    } catch (e) {
      try {
        final localItems = await _localRepository.getLocalUnitsOfMeasure(
            organizationId: organizationId);
        if (localItems.isNotEmpty) return localItems;
      } catch (_) {}
      throw Exception('Failed to fetch UOMs: $e');
    }
  }

  @override
  Future<UnitOfMeasure> createUnitOfMeasure(UnitOfMeasure uom) async {
    final model = UnitOfMeasureModel(
      id: uom.id,
      name: uom.name,
      symbol: uom.symbol,
      type: uom.type,
      isDecimalAllowed: uom.isDecimalAllowed,
      organizationId: uom.organizationId,
      createdAt: uom.createdAt,
      updatedAt: uom.updatedAt,
    );
    final json = model.toJson();
    if (model.id == 0) json.remove('id');

    if (SupabaseConfig.isOfflineLoggedIn) {
      final newId =
          await _localRepository.saveUnitOfMeasure(model, isSynced: false);
      return UnitOfMeasureModel(
        id: newId,
        name: model.name,
        symbol: model.symbol,
        type: model.type,
        isDecimalAllowed: model.isDecimalAllowed,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_units_of_measure')
          .insert(json)
          .select()
          .single();

      final newUom = UnitOfMeasureModel.fromJson(response);
      await _localRepository.saveUnitOfMeasure(newUom, isSynced: true);
      return newUom;
    } catch (e) {
      final newId =
          await _localRepository.saveUnitOfMeasure(model, isSynced: false);
      return UnitOfMeasureModel(
        id: newId,
        name: model.name,
        symbol: model.symbol,
        type: model.type,
        isDecimalAllowed: model.isDecimalAllowed,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );
    }
  }

  @override
  Future<void> updateUnitOfMeasure(UnitOfMeasure uom) async {
    final model = UnitOfMeasureModel(
      id: uom.id,
      name: uom.name,
      symbol: uom.symbol,
      type: uom.type,
      isDecimalAllowed: uom.isDecimalAllowed,
      organizationId: uom.organizationId,
      createdAt: uom.createdAt,
      updatedAt: uom.updatedAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveUnitOfMeasure(model, isSynced: false);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_units_of_measure')
          .update(model.toJson())
          .eq('id', uom.id);
      await _localRepository.saveUnitOfMeasure(model, isSynced: true);
    } catch (e) {
      await _localRepository.saveUnitOfMeasure(model, isSynced: false);
    }
  }

  @override
  Future<void> deleteUnitOfMeasure(int id) async {
    final db = await DatabaseHelper.instance.database;

    if (SupabaseConfig.isOfflineLoggedIn) {
      await db.update('local_units_of_measure', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
      return;
    }

    try {
      // Server Hard Delete
      await SupabaseConfig.client
          .from('omtbl_units_of_measure')
          .delete()
          .eq('id', id);

      await db
          .delete('local_units_of_measure', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  // ==========================
  // UNIT CONVERSIONS
  // ==========================

  @override
  Future<List<UnitConversion>> getUnitConversions({int? organizationId}) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalUnitConversions(
          organizationId: organizationId);
    }

    try {
      var query = SupabaseConfig.client.from('omtbl_unit_conversions').select(
          '*, from_unit:omtbl_units_of_measure!from_unit_id(unit_name), to_unit:omtbl_units_of_measure!to_unit_id(unit_name)');

      if (organizationId != null) {
        query = query
            .or('organization_id.eq.$organizationId,organization_id.is.null');
      }

      final response = await query.timeout(const Duration(seconds: 15));

      final List<UnitConversion> items = (response as List)
          .map<UnitConversion>((json) =>
              UnitConversionModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache
      await _localRepository.cacheUnitConversions(items);

      // Merge Unsynced
      final unsynced = await _localRepository.getUnsyncedUnitConversions(
          organizationId: organizationId);
      if (unsynced.isNotEmpty) {
        final existingIds = items.map((e) => e.id).toSet();
        for (var u in unsynced) {
          if (!existingIds.contains(u.id)) {
            items.add(u);
          } else {
            // Replace server item with local edit if needed
            final index = items.indexWhere((e) => e.id == u.id);
            if (index != -1) items[index] = u;
          }
        }
      }
      return items;
    } catch (e) {
      try {
        final localItems = await _localRepository.getLocalUnitConversions(
            organizationId: organizationId);
        if (localItems.isNotEmpty) return localItems;
      } catch (_) {}
      throw Exception('Failed to fetch unit conversions: $e');
    }
  }

  @override
  Future<UnitConversion> createUnitConversion(UnitConversion conversion) async {
    final model = UnitConversionModel(
      id: conversion.id,
      fromUnitId: conversion.fromUnitId,
      toUnitId: conversion.toUnitId,
      conversionFactor: conversion.conversionFactor,
      organizationId: conversion.organizationId,
      createdAt: conversion.createdAt,
      updatedAt: conversion.updatedAt,
    );
    final json = model.toJson();
    if (model.id == 0) json.remove('id');

    if (SupabaseConfig.isOfflineLoggedIn) {
      final newId =
          await _localRepository.saveUnitConversion(model, isSynced: false);
      return UnitConversionModel(
        id: newId,
        fromUnitId: model.fromUnitId,
        toUnitId: model.toUnitId,
        conversionFactor: model.conversionFactor,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_unit_conversions')
          .insert(json)
          .select()
          .single();

      final newConv = UnitConversionModel.fromJson(response);
      await _localRepository.saveUnitConversion(newConv, isSynced: true);
      return newConv;
    } catch (e) {
      final newId =
          await _localRepository.saveUnitConversion(model, isSynced: false);
      return UnitConversionModel(
        id: newId,
        fromUnitId: model.fromUnitId,
        toUnitId: model.toUnitId,
        conversionFactor: model.conversionFactor,
        organizationId: model.organizationId,
        createdAt: model.createdAt,
        updatedAt: model.updatedAt,
      );
    }
  }

  @override
  Future<void> updateUnitConversion(UnitConversion conversion) async {
    final model = UnitConversionModel(
      id: conversion.id,
      fromUnitId: conversion.fromUnitId,
      toUnitId: conversion.toUnitId,
      conversionFactor: conversion.conversionFactor,
      organizationId: conversion.organizationId,
      createdAt: conversion.createdAt,
      updatedAt: conversion.updatedAt,
    );

    if (SupabaseConfig.isOfflineLoggedIn) {
      await _localRepository.saveUnitConversion(model, isSynced: false);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_unit_conversions')
          .update(model.toJson())
          .eq('id', conversion.id);
      await _localRepository.saveUnitConversion(model, isSynced: true);
    } catch (e) {
      await _localRepository.saveUnitConversion(model, isSynced: false);
    }
  }

  @override
  Future<void> deleteUnitConversion(int id) async {
    final db = await DatabaseHelper.instance.database;

    if (SupabaseConfig.isOfflineLoggedIn) {
      await db.update('local_unit_conversions', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_unit_conversions')
          .delete()
          .eq('id', id);

      await db
          .delete('local_unit_conversions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }
}
