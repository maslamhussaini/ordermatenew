// lib/features/products/domain/entities/product.dart

import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.rate,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.cost = 0.0,
    this.businessPartnerId,
    this.businessPartnerName,
    this.productTypeId,
    this.productTypeName,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.uomId,
    this.uomSymbol,
    this.baseQuantity = 1.0,
    this.storeId,
    required this.organizationId,
    this.isActive = true,
    this.limitPrice = 0.0,
    this.stockQty = 0.0,
    this.inventoryGlId,
    this.cogsGlId,
    this.revenueGlId,
    this.defaultDiscountPercent = 0.0,
    this.defaultDiscountPercentLimit = 0.0,
    this.salesDiscountGlId,
  });

  final String id;
  final String name;
  final String sku;
  final String? description;
  final double rate; // Price
  final double cost;

  final String? businessPartnerId;
  final String? businessPartnerName;

  final int? productTypeId;
  final String? productTypeName;

  final int? categoryId;
  final String? categoryName;

  final int? brandId;
  final String? brandName;

  final int? uomId;
  final String? uomSymbol;
  final double baseQuantity;

  final int? storeId;
  final int organizationId;

  final bool isActive;
  final double limitPrice;
  final double stockQty;
  final String? inventoryGlId;
  final String? cogsGlId;
  final String? revenueGlId;
  final double defaultDiscountPercent;
  final double defaultDiscountPercentLimit;
  final String? salesDiscountGlId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? description,
    double? rate,
    double? cost,
    String? businessPartnerId,
    String? businessPartnerName,
    int? productTypeId,
    String? productTypeName,
    int? categoryId,
    String? categoryName,
    int? brandId,
    String? brandName,
    int? uomId,
    String? uomSymbol,
    double? baseQuantity,
    int? storeId,
    int? organizationId,
    bool? isActive,
    double? limitPrice,
    double? stockQty,
    String? inventoryGlId,
    String? cogsGlId,
    String? revenueGlId,
    double? defaultDiscountPercent,
    double? defaultDiscountPercentLimit,
    String? salesDiscountGlId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      description: description ?? this.description,
      rate: rate ?? this.rate,
      cost: cost ?? this.cost,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      businessPartnerName: businessPartnerName ?? this.businessPartnerName,
      productTypeId: productTypeId ?? this.productTypeId,
      productTypeName: productTypeName ?? this.productTypeName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      uomId: uomId ?? this.uomId,
      uomSymbol: uomSymbol ?? this.uomSymbol,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      storeId: storeId ?? this.storeId,
      organizationId: organizationId ?? this.organizationId,
      isActive: isActive ?? this.isActive,
      limitPrice: limitPrice ?? this.limitPrice,
      stockQty: stockQty ?? this.stockQty,
      inventoryGlId: inventoryGlId ?? this.inventoryGlId,
      cogsGlId: cogsGlId ?? this.cogsGlId,
      revenueGlId: revenueGlId ?? this.revenueGlId,
      defaultDiscountPercent:
          defaultDiscountPercent ?? this.defaultDiscountPercent,
      defaultDiscountPercentLimit:
          defaultDiscountPercentLimit ?? this.defaultDiscountPercentLimit,
      salesDiscountGlId: salesDiscountGlId ?? this.salesDiscountGlId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Note: Use formatCurrency() utility function in UI instead of these getters
  // to support dynamic currency from store
  String get formattedRate => rate.toStringAsFixed(2);
  String get formattedCost => cost.toStringAsFixed(2);

  @override
  List<Object?> get props => [
        id,
        name,
        sku,
        description,
        rate,
        cost,
        businessPartnerId,
        businessPartnerName,
        productTypeId,
        productTypeName,
        categoryId,
        categoryName,
        brandId,
        brandName,
        uomId,
        uomSymbol,
        baseQuantity,
        isActive,
        limitPrice,
        stockQty,
        inventoryGlId,
        cogsGlId,
        revenueGlId,
        defaultDiscountPercent,
        defaultDiscountPercentLimit,
        salesDiscountGlId,
        createdAt,
        updatedAt,
        storeId,
        organizationId,
      ];
}
