// lib/features/products/data/models/product_model.dart

import 'package:ordermate/features/products/domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.sku,
    required super.rate,
    required super.createdAt,
    required super.updatedAt,
    super.description,
    super.cost,
    super.businessPartnerId,
    super.businessPartnerName,
    super.productTypeId,
    super.productTypeName,
    super.categoryId,
    super.categoryName,
    super.brandId,
    super.brandName,
    super.uomId,
    super.uomSymbol,
    super.baseQuantity,
    super.storeId,
    required super.organizationId,
    super.isActive,
    super.limitPrice,
    super.stockQty,
    super.inventoryGlId,
    super.cogsGlId,
    super.revenueGlId,
    super.defaultDiscountPercent,
    super.defaultDiscountPercentLimit,
    super.salesDiscountGlId,
    super.isRecipe,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Unknown Product',
      sku: json['sku'] as String,
      description: json['description'] as String?,
      rate: (json['rate'] as num).toDouble(),
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      businessPartnerId: json['business_partner_id'] as String?,
      businessPartnerName: json['omtbl_businesspartners'] != null
          ? (json['omtbl_businesspartners'] as Map<String, dynamic>)['name']
              as String?
          : null,
      productTypeId: json['product_type_id'] as int?,
      productTypeName: json['omtbl_producttypes'] != null
          ? (json['omtbl_producttypes'] as Map<String, dynamic>)['producttype']
              as String?
          : null,
      categoryId: json['category_id'] as int?,
      categoryName: json['omtbl_categories'] != null
          ? (json['omtbl_categories'] as Map<String, dynamic>)['category']
              as String?
          : null,
      brandId: json['brand_id'] as int?,
      brandName: json['omtbl_brands'] != null
          ? (json['omtbl_brands'] as Map<String, dynamic>)['brandtype']
              as String?
          : null,
      uomId: json['uom_id'] as int?,
      uomSymbol: json['omtbl_units_of_measure'] != null
          ? (json['omtbl_units_of_measure']
              as Map<String, dynamic>)['unit_symbol'] as String?
          : json['uom_symbol'] as String?,
      baseQuantity: (json['base_quantity'] as num?)?.toDouble() ?? 1.0,
      storeId: json['store_id'] as int?,
      organizationId: (json['organization_id'] as int?) ?? 0,
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active'] == null,
      limitPrice: (json['limit_price'] as num? ?? json['limtprice'] as num?)
              ?.toDouble() ??
          0.0,
      stockQty: (json['stock_qty'] as num?)?.toDouble() ?? 0.0,
      inventoryGlId: json['inventory_gl_id'] as String?,
      cogsGlId: (json['cogs_gl_id'] as String?) ?? (json['cogs_id'] as String?),
      revenueGlId:
          (json['revenue_gl_id'] as String?) ?? (json['revnue_id'] as String?),
      defaultDiscountPercent:
          (json['defult_discount_percnt'] as num?)?.toDouble() ?? 0.0,
      defaultDiscountPercentLimit:
          (json['defult_discount_percnt_limit'] as num?)?.toDouble() ?? 0.0,
      salesDiscountGlId: (json['sales_discount_id'] as String?) ??
          (json['sales_discount_gl_id'] as String?),
      isRecipe: json['is_recipe'] == 1 || json['is_recipe'] == true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'description': description,
      'rate': rate,
      'cost': cost,
      'business_partner_id': businessPartnerId,
      'product_type_id': productTypeId,
      'category_id': categoryId,
      'brand_id': brandId,
      'uom_id': uomId,
      'uom_symbol': uomSymbol,
      'base_quantity': baseQuantity,
      'store_id': storeId,
      'organization_id': organizationId,
      'is_active': isActive,
      'limit_price': limitPrice,
      'stock_qty': stockQty,
      'inventory_gl_id': inventoryGlId,
      'cogs_gl_id': cogsGlId,
      'revenue_gl_id': revenueGlId,
      'defult_discount_percnt': defaultDiscountPercent,
      'defult_discount_percnt_limit': defaultDiscountPercentLimit,
      'sales_discount_id': salesDiscountGlId,
      'is_recipe': isRecipe,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product toEntity() => this;
}
