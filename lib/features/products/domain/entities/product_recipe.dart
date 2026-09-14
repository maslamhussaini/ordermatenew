import 'package:equatable/equatable.dart';

class ProductRecipe extends Equatable {
  const ProductRecipe({
    required this.id,
    required this.productId,
    required this.componentProductId,
    required this.quantity,
    required this.uomId,
    this.wastagePercent = 0.0,
    required this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String productId;
  final String componentProductId;
  final double quantity;
  final int uomId;
  final double wastagePercent;
  final int organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductRecipe copyWith({
    String? id,
    String? productId,
    String? componentProductId,
    double? quantity,
    int? uomId,
    double? wastagePercent,
    int? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductRecipe(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      componentProductId: componentProductId ?? this.componentProductId,
      quantity: quantity ?? this.quantity,
      uomId: uomId ?? this.uomId,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        componentProductId,
        quantity,
        uomId,
        wastagePercent,
        organizationId,
        createdAt,
        updatedAt,
      ];
}
