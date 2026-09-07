
import '../../domain/entities/chart_of_account.dart';

class OpeningBalanceModel extends OpeningBalance {
  const OpeningBalanceModel({
    required super.id,
    required super.sYear,
    required super.amount,
    required super.entityId,
    super.entityType,
    required super.organizationId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OpeningBalanceModel.fromJson(Map<String, dynamic> json) {
    return OpeningBalanceModel(
      id: json['id'] as String,
      sYear: json['syear'] as int,
      amount: (json['amount'] as num).toDouble(),
      entityId: json['entity_id'] as String,
      entityType: json['entity_type'] as String? ?? '',
      organizationId: (json['organization_id'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syear': sYear,
      'amount': amount,
      'entity_id': entityId,
      'entity_type': entityType,
      'organization_id': organizationId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'syear': sYear,
      'amount': amount,
      'entity_id': entityId,
      'entity_type': entityType,
      'organization_id': organizationId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
  factory OpeningBalanceModel.fromLocalMap(Map<String, dynamic> map) {
    return OpeningBalanceModel(
      id: map['id'] as String,
      sYear: map['syear'] as int,
      amount: (map['amount'] as num).toDouble(),
      entityId: map['entity_id'] as String,
      entityType: map['entity_type'] as String? ?? '',
      organizationId: (map['organization_id'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
    );
  }
}
