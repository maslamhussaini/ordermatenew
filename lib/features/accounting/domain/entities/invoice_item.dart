import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  final String id;
  final String invoiceId;
  final String productId;
  final String? productName;
  final double quantity;
  final double rate;
  final double total;
  final int? uomId;
  final String? uomSymbol;
  final double? discountPercent;
  final DateTime? createdAt;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.rate,
    required this.total,
    this.uomId,
    this.uomSymbol,
    this.discountPercent = 0.0,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        invoiceId,
        productId,
        productName,
        quantity,
        rate,
        total,
        uomId,
        uomSymbol,
        discountPercent,
        createdAt,
      ];

  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? productId,
    String? productName,
    double? quantity,
    double? rate,
    double? total,
    int? uomId,
    String? uomSymbol,
    double? discountPercent,
    DateTime? createdAt,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      total: total ?? this.total,
      uomId: uomId ?? this.uomId,
      uomSymbol: uomSymbol ?? this.uomSymbol,
      discountPercent: discountPercent ?? this.discountPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
