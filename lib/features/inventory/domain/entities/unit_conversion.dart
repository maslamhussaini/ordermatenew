import 'package:equatable/equatable.dart';

class UnitConversion extends Equatable {
  const UnitConversion({
    required this.id,
    required this.fromUnitId,
    required this.toUnitId,
    required this.conversionFactor,
    this.fromUnitName,
    this.toUnitName,
    required this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int fromUnitId;
  final int toUnitId;
  final double conversionFactor;
  final String? fromUnitName;
  final String? toUnitName;
  final int organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UnitConversion copyWith({
    int? id,
    int? fromUnitId,
    int? toUnitId,
    double? conversionFactor,
    String? fromUnitName,
    String? toUnitName,
    int? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitConversion(
      id: id ?? this.id,
      fromUnitId: fromUnitId ?? this.fromUnitId,
      toUnitId: toUnitId ?? this.toUnitId,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      fromUnitName: fromUnitName ?? this.fromUnitName,
      toUnitName: toUnitName ?? this.toUnitName,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fromUnitId,
        toUnitId,
        conversionFactor,
        fromUnitName,
        toUnitName,
        organizationId,
        createdAt,
        updatedAt,
      ];
}
