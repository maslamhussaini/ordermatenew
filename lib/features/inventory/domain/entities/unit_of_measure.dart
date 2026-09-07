import 'package:equatable/equatable.dart';

class UnitOfMeasure extends Equatable {
  const UnitOfMeasure({
    required this.id,
    required this.name,
    required this.symbol,
    this.type,
    this.isDecimalAllowed = true,
    required this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String symbol;
  final String? type;
  final bool isDecimalAllowed;
  final int organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UnitOfMeasure copyWith({
    int? id,
    String? name,
    String? symbol,
    String? type,
    bool? isDecimalAllowed,
    int? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitOfMeasure(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      isDecimalAllowed: isDecimalAllowed ?? this.isDecimalAllowed,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        symbol,
        type,
        isDecimalAllowed,
        organizationId,
        createdAt,
        updatedAt,
      ];
}
