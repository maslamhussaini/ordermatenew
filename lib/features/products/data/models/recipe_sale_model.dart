import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';

class RecipeSaleModel extends RecipeSale {
  const RecipeSaleModel({
    required super.id,
    required super.organizationId,
    required super.storeId,
    required super.saleDate,
    super.totalAmount,
    super.totalCost,
    super.totalProfit,
    super.createdBy,
    super.createdAt,
  });

  factory RecipeSaleModel.fromJson(Map<String, dynamic> json) {
    return RecipeSaleModel(
      id: json['id'] as String,
      organizationId: (json['organization_id'] as num?)?.toInt() ?? 0,
      storeId: (json['store_id'] as num?)?.toInt() ?? 0,
      saleDate: json['sale_date'] != null
          ? DateTime.tryParse('${json['sale_date']}T00:00:00') ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  factory RecipeSaleModel.fromEntity(RecipeSale entity) {
    return RecipeSaleModel(
      id: entity.id,
      organizationId: entity.organizationId,
      storeId: entity.storeId,
      saleDate: entity.saleDate,
      totalAmount: entity.totalAmount,
      totalCost: entity.totalCost,
      totalProfit: entity.totalProfit,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'store_id': storeId,
      'sale_date': saleDate.toIso8601String().split('T').first,
      'total_amount': totalAmount,
      'total_cost': totalCost,
      'total_profit': totalProfit,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class RecipeSaleItemModel extends RecipeSaleItem {
  const RecipeSaleItemModel({
    required super.id,
    required super.recipeSaleId,
    required super.productId,
    required super.quantitySold,
    required super.rate,
    required super.amount,
    required super.cost,
    required super.profit,
    super.wastageQty,
  });

  factory RecipeSaleItemModel.fromJson(Map<String, dynamic> json) {
    return RecipeSaleItemModel(
      id: json['id'] as String,
      recipeSaleId: json['recipe_sale_id'] as String,
      productId: json['product_id'] as String,
      quantitySold: (json['quantity_sold'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      wastageQty: (json['wastage_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory RecipeSaleItemModel.fromEntity(RecipeSaleItem entity) {
    return RecipeSaleItemModel(
      id: entity.id,
      recipeSaleId: entity.recipeSaleId,
      productId: entity.productId,
      quantitySold: entity.quantitySold,
      rate: entity.rate,
      amount: entity.amount,
      cost: entity.cost,
      profit: entity.profit,
      wastageQty: entity.wastageQty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipe_sale_id': recipeSaleId,
      'product_id': productId,
      'quantity_sold': quantitySold,
      'rate': rate,
      'amount': amount,
      'cost': cost,
      'profit': profit,
      'wastage_qty': wastageQty,
    };
  }
}
