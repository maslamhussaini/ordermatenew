import 'package:ordermate/features/accounting/domain/entities/invoice_item.dart';

class InvoiceItemModel extends InvoiceItem {
  const InvoiceItemModel({
    required super.id,
    required super.invoiceId,
    required super.productId,
    super.productName,
    required super.quantity,
    required super.rate,
    required super.total,
    super.uomId,
    super.uomSymbol,
    super.discountPercent,
    super.createdAt,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id'] as String,
      invoiceId: json['invoice_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      uomId: json['uom_id'] as int?,
      uomSymbol: json['uom_symbol'] as String?,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] == null
          ? null
          : (json['created_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
              : DateTime.parse(json['created_at'] as String)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'rate': rate,
      'total': total,
      'discount_percent': discountPercent,
      'uom_id': uomId,
      'uom_symbol': uomSymbol,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory InvoiceItemModel.fromEntity(InvoiceItem entity) {
    return InvoiceItemModel(
      id: entity.id,
      invoiceId: entity.invoiceId,
      productId: entity.productId,
      productName: entity.productName,
      quantity: entity.quantity,
      rate: entity.rate,
      total: entity.total,
      uomId: entity.uomId,
      uomSymbol: entity.uomSymbol,
      discountPercent: entity.discountPercent,
      createdAt: entity.createdAt,
    );
  }
}
