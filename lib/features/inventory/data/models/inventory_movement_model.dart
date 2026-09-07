import 'package:ordermate/features/inventory/domain/entities/inventory_movement.dart';

class InventoryMovementModel extends InventoryMovement {
  const InventoryMovementModel({
    required super.id,
    required super.organizationId,
    required super.productId,
    required super.storeId,
    required super.movementType,
    required super.quantity,
    super.referenceTable,
    super.referenceId,
    required super.createdAt,
  });

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) {
    return InventoryMovementModel(
      id: json['id'] as int,
      organizationId: json['organization_id'] as int,
      productId: json['product_id'] as String,
      storeId: json['store_id'] as int,
      movementType: json['movement_type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      referenceTable: json['reference_table'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organization_id': organizationId,
      'product_id': productId,
      'store_id': storeId,
      'movement_type': movementType,
      'quantity': quantity,
      'reference_table': referenceTable,
      'reference_id': referenceId,
    };
  }
}
