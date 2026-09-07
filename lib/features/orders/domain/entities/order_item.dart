// lib/features/orders/domain/entities/order_item.dart

import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.rate,
    required this.total,
    required this.createdAt,
    this.productName,
    this.productSku,
    this.uomId,
    this.uomSymbol,
  });
  final String id;
  final String orderId;
  final String productId;
  final String? productName;
  final String? productSku;
  final double quantity; // Changed to double for units like KG
  final double rate;
  final double total;
  final DateTime createdAt;
  final int? uomId;
  final String? uomSymbol;

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    String? productSku,
    double? quantity,
    double? rate,
    double? total,
    DateTime? createdAt,
    int? uomId,
    String? uomSymbol,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      uomId: uomId ?? this.uomId,
      uomSymbol: uomSymbol ?? this.uomSymbol,
    );
  }

  // Calculate total from quantity and rate
  static double calculateTotal(double quantity, double rate) {
    return quantity * rate;
  }

  // Note: Use formatCurrency() utility function in UI instead
  String get formattedRate => rate.toStringAsFixed(2);
  String get formattedTotal => total.toStringAsFixed(2);

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String?,
      productSku: json['product_sku'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      uomId: (json['uom_id'] as num?)?.toInt(),
      uomSymbol: json['uom_symbol'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'quantity': quantity,
      'rate': rate,
      'total': total,
      'created_at': createdAt.toIso8601String(),
      'uom_id': uomId,
      'uom_symbol': uomSymbol,
    };
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        productId,
        productName,
        productSku,
        quantity,
        rate,
        total,
        createdAt,
        uomId,
        uomSymbol,
      ];
}
