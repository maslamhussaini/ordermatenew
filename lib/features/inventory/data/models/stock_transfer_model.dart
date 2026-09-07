import 'dart:convert';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';

class StockTransferModel extends StockTransfer {
  const StockTransferModel({
    required super.id,
    required super.transferNumber,
    required super.sourceStoreId,
    super.destinationStoreId,
    required super.status,
    required super.transferDate,
    required super.createdBy,
    super.driverName,
    super.vehicleNumber,
    super.remarks,
    required super.organizationId,
    super.sYear,
    required super.createdAt,
    required super.updatedAt,
    super.items,
    super.isSynced,
  });

  factory StockTransferModel.fromJson(Map<String, dynamic> json) {
    List<StockTransferItem> items = [];
    if (json['items_payload'] != null &&
        json['items_payload'].toString().isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json['items_payload']);
        items = list.map((e) => StockTransferItem.fromJson(e)).toList();
      } catch (e) {
        // print('Error parsing items payload: $e');
      }
    } else if (json['items'] != null) {
      // If fetching from online relation or nested list
      final List<dynamic> list = json['items'];
      items = list.map((e) => StockTransferItem.fromJson(e)).toList();
    }

    return StockTransferModel(
      id: json['id'],
      transferNumber: json['transfer_number'] ?? '',
      sourceStoreId: json['source_store_id'] is int
          ? json['source_store_id']
          : int.tryParse(json['source_store_id']?.toString() ?? '0') ?? 0,
      destinationStoreId: json['destination_store_id'] != null
          ? (json['destination_store_id'] is int
              ? json['destination_store_id']
              : int.tryParse(json['destination_store_id'].toString()))
          : null,
      status: json['status'] ?? 'Draft',
      transferDate: json['transfer_date'] != null
          ? DateTime.parse(json['transfer_date'])
          : DateTime.now(),
      createdBy: json['created_by'] ?? '',
      driverName: json['driver_name'],
      vehicleNumber: json['vehicle_number'],
      remarks: json['remarks'],
      organizationId: json['organization_id'] is int
          ? json['organization_id']
          : int.tryParse(json['organization_id']?.toString() ?? '0') ?? 0,
      sYear: json['syear'] is int
          ? json['syear']
          : int.tryParse(json['syear']?.toString() ?? '0'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      items: items,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transfer_number': transferNumber,
      'source_store_id': sourceStoreId,
      'destination_store_id': destinationStoreId,
      'status': status,
      'transfer_date': transferDate.toIso8601String(),
      'created_by': createdBy,
      'driver_name': driverName,
      'vehicle_number': vehicleNumber,
      'remarks': remarks,
      'organization_id': organizationId,
      'syear': sYear,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'items_payload': jsonEncode(items
          .map((e) => e.toJson())
          .toList()), // Always save payload for local
    };
  }

  // Helper to init from entity
  factory StockTransferModel.fromEntity(StockTransfer entity) {
    return StockTransferModel(
      id: entity.id,
      transferNumber: entity.transferNumber,
      sourceStoreId: entity.sourceStoreId,
      destinationStoreId: entity.destinationStoreId,
      status: entity.status,
      transferDate: entity.transferDate,
      createdBy: entity.createdBy,
      driverName: entity.driverName,
      vehicleNumber: entity.vehicleNumber,
      remarks: entity.remarks,
      organizationId: entity.organizationId,
      sYear: entity.sYear,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      items: entity.items,
      isSynced: entity.isSynced,
    );
  }
}
