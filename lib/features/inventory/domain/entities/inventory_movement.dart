import 'package:equatable/equatable.dart';

class InventoryMovement extends Equatable {
  final int id;
  final int organizationId;
  final String productId;
  final int storeId;
  final String movementType;
  final double quantity;
  final String? referenceTable;
  final String? referenceId;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.organizationId,
    required this.productId,
    required this.storeId,
    required this.movementType,
    required this.quantity,
    this.referenceTable,
    this.referenceId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        organizationId,
        productId,
        storeId,
        movementType,
        quantity,
        referenceTable,
        referenceId,
        createdAt,
      ];
}
