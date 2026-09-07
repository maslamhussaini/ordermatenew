import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';

class UnitConversionModel extends UnitConversion {
  const UnitConversionModel({
    required super.id,
    required super.fromUnitId,
    required super.toUnitId,
    required super.conversionFactor,
    super.fromUnitName,
    super.toUnitName,
    required super.organizationId,
    super.createdAt,
    super.updatedAt,
  });

  factory UnitConversionModel.fromJson(Map<String, dynamic> json) {
    return UnitConversionModel(
      id: json['id'] as int? ?? 0,
      fromUnitId: json['from_unit_id'] as int? ?? 0,
      toUnitId: json['to_unit_id'] as int? ?? 0,
      conversionFactor: (json['conversion_factor'] as num?)?.toDouble() ?? 1.0,
      fromUnitName:
          json['from_unit'] != null ? json['from_unit']['unit_name'] : null,
      toUnitName: json['to_unit'] != null ? json['to_unit']['unit_name'] : null,
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
      'from_unit_id': fromUnitId,
      'to_unit_id': toUnitId,
      'conversion_factor': conversionFactor,
      'organization_id': organizationId,
    };
    if (id != 0) {
      data['id'] = id as dynamic;
    }
    return data;
  }
}
