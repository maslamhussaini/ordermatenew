import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';

abstract class InventoryRepository {
  // Brands
  Future<List<Brand>> getBrands({int? organizationId});
  Future<Brand> createBrand(Brand brand);
  Future<void> updateBrand(Brand brand);
  Future<void> deleteBrand(int id);

  // Categories
  Future<List<ProductCategory>> getCategories({int? organizationId});
  Future<ProductCategory> createCategory(ProductCategory category);
  Future<void> updateCategory(ProductCategory category);
  Future<void> deleteCategory(int id);

  // Product Types
  Future<List<ProductType>> getProductTypes({int? organizationId});
  Future<ProductType> createProductType(ProductType type);
  Future<void> updateProductType(ProductType type);
  Future<void> deleteProductType(int id);

  // Units of Measure
  Future<List<UnitOfMeasure>> getUnitsOfMeasure({int? organizationId});
  Future<UnitOfMeasure> createUnitOfMeasure(UnitOfMeasure uom);
  Future<void> updateUnitOfMeasure(UnitOfMeasure uom);
  Future<void> deleteUnitOfMeasure(int id);

  // Unit Conversions
  Future<List<UnitConversion>> getUnitConversions({int? organizationId});
  Future<UnitConversion> createUnitConversion(UnitConversion conversion);
  Future<void> updateUnitConversion(UnitConversion conversion);
  Future<void> deleteUnitConversion(int id);
}
