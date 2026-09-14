import 'package:ordermate/features/products/domain/entities/product_recipe.dart';

class ProductRecipeModel extends ProductRecipe {
  const ProductRecipeModel({
    required super.id,
    required super.productId,
    required super.componentProductId,
    required super.quantity,
    required super.uomId,
    super.wastagePercent,
    required super.organizationId,
    super.createdAt,
    super.updatedAt,
  });

  factory ProductRecipeModel.fromJson(Map<String, dynamic> json) {
    return ProductRecipeModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      componentProductId: json['component_product_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      uomId: json['uom_id'] as int,
      wastagePercent: (json['wastage_percent'] as num?)?.toDouble() ?? 0.0,
      organizationId: (json['organization_id'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  factory ProductRecipeModel.fromEntity(ProductRecipe entity) {
    return ProductRecipeModel(
      id: entity.id,
      productId: entity.productId,
      componentProductId: entity.componentProductId,
      quantity: entity.quantity,
      uomId: entity.uomId,
      wastagePercent: entity.wastagePercent,
      organizationId: entity.organizationId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'component_product_id': componentProductId,
      'quantity': quantity,
      'uom_id': uomId,
      'wastage_percent': wastagePercent,
      'organization_id': organizationId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
