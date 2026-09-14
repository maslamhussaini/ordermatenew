import 'package:equatable/equatable.dart';

class RecipeSale extends Equatable {
  const RecipeSale({
    required this.id,
    required this.organizationId,
    required this.storeId,
    required this.saleDate,
    this.totalAmount = 0.0,
    this.totalCost = 0.0,
    this.totalProfit = 0.0,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final int organizationId;
  final int storeId;
  final DateTime saleDate;
  final double totalAmount;
  final double totalCost;
  final double totalProfit;
  final String? createdBy;
  final DateTime? createdAt;

  RecipeSale copyWith({
    String? id,
    int? organizationId,
    int? storeId,
    DateTime? saleDate,
    double? totalAmount,
    double? totalCost,
    double? totalProfit,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return RecipeSale(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      saleDate: saleDate ?? this.saleDate,
      totalAmount: totalAmount ?? this.totalAmount,
      totalCost: totalCost ?? this.totalCost,
      totalProfit: totalProfit ?? this.totalProfit,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        storeId,
        saleDate,
        totalAmount,
        totalCost,
        totalProfit,
        createdBy,
        createdAt,
      ];
}

class RecipeSaleItem extends Equatable {
  const RecipeSaleItem({
    required this.id,
    required this.recipeSaleId,
    required this.productId,
    required this.quantitySold,
    required this.rate,
    required this.amount,
    required this.cost,
    required this.profit,
    this.wastageQty = 0.0,
  });

  final String id;
  final String recipeSaleId;
  final String productId;
  final double quantitySold;
  final double rate;
  final double amount;
  final double cost;
  final double profit;
  final double wastageQty;

  RecipeSaleItem copyWith({
    String? id,
    String? recipeSaleId,
    String? productId,
    double? quantitySold,
    double? rate,
    double? amount,
    double? cost,
    double? profit,
    double? wastageQty,
  }) {
    return RecipeSaleItem(
      id: id ?? this.id,
      recipeSaleId: recipeSaleId ?? this.recipeSaleId,
      productId: productId ?? this.productId,
      quantitySold: quantitySold ?? this.quantitySold,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      cost: cost ?? this.cost,
      profit: profit ?? this.profit,
      wastageQty: wastageQty ?? this.wastageQty,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipeSaleId,
        productId,
        quantitySold,
        rate,
        amount,
        cost,
        profit,
        wastageQty,
      ];
}
