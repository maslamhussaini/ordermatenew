import 'package:equatable/equatable.dart';

class StockTransfer extends Equatable {
  final String id;
  final String transferNumber;
  final int sourceStoreId;
  final int? destinationStoreId;
  final String status; // Draft, Approved, Completed, Cancelled
  final DateTime transferDate;
  final String createdBy;
  final String? driverName;
  final String? vehicleNumber;
  final String? remarks;
  final int organizationId;
  final int? sYear;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StockTransferItem> items;
  final bool isSynced;

  const StockTransfer({
    required this.id,
    required this.transferNumber,
    required this.sourceStoreId,
    this.destinationStoreId,
    required this.status,
    required this.transferDate,
    required this.createdBy,
    this.driverName,
    this.vehicleNumber,
    this.remarks,
    required this.organizationId,
    this.sYear,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.isSynced = true,
  });

  @override
  List<Object?> get props => [
        id,
        transferNumber,
        sourceStoreId,
        destinationStoreId,
        status,
        transferDate,
        createdBy,
        driverName,
        vehicleNumber,
        remarks,
        organizationId,
        sYear,
        createdAt,
        updatedAt,
        items,
        isSynced
      ];

  StockTransfer copyWith({
    String? id,
    String? transferNumber,
    int? sourceStoreId,
    int? destinationStoreId,
    String? status,
    DateTime? transferDate,
    String? createdBy,
    String? driverName,
    String? vehicleNumber,
    String? remarks,
    int? organizationId,
    int? sYear,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<StockTransferItem>? items,
    bool? isSynced,
  }) {
    return StockTransfer(
      id: id ?? this.id,
      transferNumber: transferNumber ?? this.transferNumber,
      sourceStoreId: sourceStoreId ?? this.sourceStoreId,
      destinationStoreId: destinationStoreId ?? this.destinationStoreId,
      status: status ?? this.status,
      transferDate: transferDate ?? this.transferDate,
      createdBy: createdBy ?? this.createdBy,
      driverName: driverName ?? this.driverName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      remarks: remarks ?? this.remarks,
      organizationId: organizationId ?? this.organizationId,
      sYear: sYear ?? this.sYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class StockTransferItem extends Equatable {
  final String id;
  final String transferId;
  final String productId;
  final String productName;
  final double quantity;
  final int uomId;
  final String uomSymbol;

  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.uomId,
    required this.uomSymbol,
  });

  StockTransferItem copyWith({
    String? id,
    String? transferId,
    String? productId,
    String? productName,
    double? quantity,
    int? uomId,
    String? uomSymbol,
  }) {
    return StockTransferItem(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      uomId: uomId ?? this.uomId,
      uomSymbol: uomSymbol ?? this.uomSymbol,
    );
  }

  @override
  List<Object?> get props =>
      [id, transferId, productId, productName, quantity, uomId, uomSymbol];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transfer_id': transferId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'uom_id': uomId,
      'uom_symbol': uomSymbol,
    };
  }

  factory StockTransferItem.fromJson(Map<String, dynamic> json) {
    return StockTransferItem(
      id: json['id']?.toString() ?? '',
      transferId: json['transfer_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      uomId: (json['uom_id'] as num?)?.toInt() ?? 0,
      uomSymbol: json['uom_symbol']?.toString() ?? '',
    );
  }
}
