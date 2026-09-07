import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';

class UnitOfMeasureModel extends UnitOfMeasure {
  const UnitOfMeasureModel({
    required super.id,
    required super.name,
    required super.symbol,
    super.type,
    super.isDecimalAllowed,
    required super.organizationId,
    super.createdAt,
    super.updatedAt,
  });

  factory UnitOfMeasureModel.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasureModel(
      id: json['id'] as int? ?? 0,
      name: json['unit_name']?.toString() ?? '',
      symbol: json['unit_symbol']?.toString() ?? '',
      type: json['unit_type']?.toString(),
      isDecimalAllowed: json['is_decimal_allowed'] == true,
      organizationId: (json['organization_id'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'unit_name': name,
      'unit_symbol': symbol,
      'unit_type': type,
      'is_decimal_allowed': isDecimalAllowed,
      'organization_id': organizationId,
    };
    if (id != 0) {
      data['id'] = id as dynamic;
    }
    return data;
  }
}
