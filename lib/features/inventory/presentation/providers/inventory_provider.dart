import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/repositories/inventory_repository.dart';

// State
class InventoryState {
  const InventoryState({
    this.brands = const [],
    this.categories = const [],
    this.productTypes = const [],
    this.unitsOfMeasure = const [],
    this.unitConversions = const [],
    this.isLoading = false,
    this.error,
  });
  final List<Brand> brands;
  final List<ProductCategory> categories;
  final List<ProductType> productTypes;
  final List<UnitOfMeasure> unitsOfMeasure;
  final List<UnitConversion> unitConversions;
  final bool isLoading;
  final String? error;

  InventoryState copyWith({
    List<Brand>? brands,
    List<ProductCategory>? categories,
    List<ProductType>? productTypes,
    List<UnitOfMeasure>? unitsOfMeasure,
    List<UnitConversion>? unitConversions,
    bool? isLoading,
    String? error,
  }) {
    return InventoryState(
      brands: brands ?? this.brands,
      categories: categories ?? this.categories,
      productTypes: productTypes ?? this.productTypes,
      unitsOfMeasure: unitsOfMeasure ?? this.unitsOfMeasure,
      unitConversions: unitConversions ?? this.unitConversions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier(this.repository, this.ref) : super(const InventoryState());
  final InventoryRepository repository;
  final Ref ref;

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    debugPrint('InventoryNotifier: Loading all data for Org ID: $orgId');

    // Helper to safely load data
    Future<List<T>> safeLoad<T>(
        String name, Future<List<T>> Function() fetcher) async {
      try {
        debugPrint('InventoryNotifier: Fetching $name...');
        final result = await fetcher();
        debugPrint('InventoryNotifier: Fetched ${result.length} $name');
        return result;
      } catch (e) {
        debugPrint('InventoryNotifier: Error loading $name: $e');
        return [];
      }
    }

    // Load sequentially to avoid SQLite locking issues during caching
    final brands = await safeLoad(
        'Brands', () => repository.getBrands(organizationId: orgId));
    final categories = await safeLoad(
        'Categories', () => repository.getCategories(organizationId: orgId));
    final productTypes = await safeLoad('ProductTypes',
        () => repository.getProductTypes(organizationId: orgId));
    final unitsOfMeasure = await safeLoad('UnitsOfMeasure',
        () => repository.getUnitsOfMeasure(organizationId: orgId));
    final unitConversions = await safeLoad('UnitConversions',
        () => repository.getUnitConversions(organizationId: orgId));

    if (brands.isEmpty && categories.isEmpty && productTypes.isEmpty) {
      debugPrint('InventoryNotifier: All primary inventory lists are empty.');
    }

    state = state.copyWith(
      isLoading: false,
      brands: brands,
      categories: categories,
      productTypes: productTypes,
      unitsOfMeasure: unitsOfMeasure,
      unitConversions: unitConversions,
    );
  }

  Future<void> loadAllIgnoreOrg() async {
    state = state.copyWith(isLoading: true, error: null);
    debugPrint('InventoryNotifier: Loading ALL data (ignoring Org ID)');

    Future<List<T>> safeLoad<T>(
        String name, Future<List<T>> Function() fetcher) async {
      try {
        debugPrint('InventoryNotifier: Fetching $name (no org filter)...');
        final result = await fetcher();
        debugPrint('InventoryNotifier: Fetched ${result.length} $name');
        return result;
      } catch (e) {
        debugPrint('InventoryNotifier: Error loading $name: $e');
        return [];
      }
    }

    final brands =
        await safeLoad('Brands', () => repository.getBrands(organizationId: 0));
    final categories = await safeLoad(
        'Categories', () => repository.getCategories(organizationId: 0));
    final productTypes = await safeLoad(
        'ProductTypes', () => repository.getProductTypes(organizationId: 0));
    final unitsOfMeasure = await safeLoad('UnitsOfMeasure',
        () => repository.getUnitsOfMeasure(organizationId: 0));
    final unitConversions = await safeLoad('UnitConversions',
        () => repository.getUnitConversions(organizationId: 0));

    state = state.copyWith(
      isLoading: false,
      brands: brands,
      categories: categories,
      productTypes: productTypes,
      unitsOfMeasure: unitsOfMeasure,
      unitConversions: unitConversions,
    );
  }

  // Brands
  Future<void> loadBrands() async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final brands = await repository.getBrands(organizationId: orgId);
      state = state.copyWith(brands: brands);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addBrand(String name) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.createBrand(
        Brand(
          id: 0,
          name: name,
          organizationId: orgId ?? 0,
          createdAt: DateTime.now(),
        ),
      );
      await loadBrands();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateBrand(Brand brand) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.updateBrand(brand.copyWith(organizationId: orgId));
      await loadBrands();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteBrand(int id) async {
    try {
      await repository.deleteBrand(id);
      await loadBrands();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Categories
  Future<void> loadCategories() async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final categories = await repository.getCategories(organizationId: orgId);
      state = state.copyWith(categories: categories);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addCategory(String name) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.createCategory(
        ProductCategory(
          id: 0,
          name: name,
          organizationId: orgId ?? 0,
          createdAt: DateTime.now(),
        ),
      );
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateCategory(ProductCategory category) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.updateCategory(category.copyWith(organizationId: orgId));
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await repository.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Product Types
  Future<void> loadProductTypes() async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final types = await repository.getProductTypes(organizationId: orgId);
      state = state.copyWith(productTypes: types);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addProductType(String name) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.createProductType(
        ProductType(
          id: 0,
          name: name,
          organizationId: orgId ?? 0,
          createdAt: DateTime.now(),
        ),
      );
      await loadProductTypes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProductType(ProductType type) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.updateProductType(type.copyWith(organizationId: orgId));
      await loadProductTypes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProductType(int id) async {
    try {
      await repository.deleteProductType(id);
      await loadProductTypes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Units of Measure
  Future<void> loadUnitsOfMeasure() async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final items = await repository.getUnitsOfMeasure(organizationId: orgId);
      state = state.copyWith(unitsOfMeasure: items);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addUnitOfMeasure(UnitOfMeasure uom) async {
    try {
      final user = ref.read(organizationProvider).selectedOrganization;
      final orgId = user?.id;
      final uomWithOrg = UnitOfMeasure(
        id: uom.id,
        name: uom.name,
        symbol: uom.symbol,
        type: uom.type,
        isDecimalAllowed: uom.isDecimalAllowed,
        organizationId: orgId ?? 0,
      );
      await repository.createUnitOfMeasure(uomWithOrg);
      await loadUnitsOfMeasure();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Minimal-input variant for [LookupField]'s inline "+ Create New" dialog
  /// (Phase QA P0.2), which only collects a single name string -- the same
  /// pattern already used by [addBrand]/[addCategory]/[addProductType].
  /// Symbol defaults to the typed name itself (the user can refine it later
  /// via the full Units of Measure screen) -- deliberately not inventing any
  /// business data, just accepting what the user typed as both fields.
  Future<void> addUnitOfMeasureByName(String name) async {
    await addUnitOfMeasure(UnitOfMeasure(
      id: 0,
      name: name,
      symbol: name,
      organizationId: 0, // overwritten with the real org id inside addUnitOfMeasure
    ));
  }

  Future<void> updateUnitOfMeasure(UnitOfMeasure uom) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository.updateUnitOfMeasure(uom.copyWith(organizationId: orgId));
      await loadUnitsOfMeasure();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteUnitOfMeasure(int id) async {
    try {
      await repository.deleteUnitOfMeasure(id);
      await loadUnitsOfMeasure();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Unit Conversions
  Future<void> loadUnitConversions() async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final items = await repository.getUnitConversions(organizationId: orgId);
      state = state.copyWith(unitConversions: items);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addUnitConversion(UnitConversion conversion) async {
    try {
      final user = ref.read(organizationProvider).selectedOrganization;
      final orgId = user?.id;
      final conversionWithOrg = UnitConversion(
        id: conversion.id,
        fromUnitId: conversion.fromUnitId,
        toUnitId: conversion.toUnitId,
        conversionFactor: conversion.conversionFactor,
        organizationId: orgId ?? 0,
      );
      await repository.createUnitConversion(conversionWithOrg);
      await loadUnitConversions();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateUnitConversion(UnitConversion conversion) async {
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await repository
          .updateUnitConversion(conversion.copyWith(organizationId: orgId));
      await loadUnitConversions();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteUnitConversion(int id) async {
    try {
      await repository.deleteUnitConversion(id);
      await loadUnitConversions();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Provider
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl();
});

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return InventoryNotifier(repository, ref);
});
