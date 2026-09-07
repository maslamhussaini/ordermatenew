import 'package:ordermate/features/inventory/domain/entities/product_type.dart';

class ProductTypeModel extends ProductType {
  const ProductTypeModel({
    required super.id,
    required super.name,
    required super.createdAt,
    super.status,
    required super.organizationId,
    super.productCount,
  });

  factory ProductTypeModel.fromJson(Map<String, dynamic> json) {
    return ProductTypeModel(
      id: json['idproducttype'] as int? ?? 0,
      name: json['producttype']?.toString() ?? '',
      status: json['status'] as int? ?? 1,
      organizationId: (json['organization_id'] as int?) ?? 0,
      productCount: _parseProductCount(json['product_count']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static int _parseProductCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is List) {
      if (value.isEmpty) return 0;
      final first = value.first;
      if (first is Map && first.containsKey('count')) {
        return first['count'] as int? ?? 0;
      }
      return value.length;
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'idproducttype': id == 0 ? null : id,
      'producttype': name,
      'status': status,
      'organization_id': organizationId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
