import 'package:equatable/equatable.dart';

class ProductCategory extends Equatable {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    this.status = 1,
    required this.organizationId,
    this.productCount,
  });

  final int id;
  final String name;
  final int status;
  final int organizationId;
  final int? productCount;
  final DateTime createdAt;

  ProductCategory copyWith({
    int? id,
    String? name,
    int? status,
    int? organizationId,
    int? productCount,
    DateTime? createdAt,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      organizationId: organizationId ?? this.organizationId,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, status, organizationId, productCount, createdAt];
}
