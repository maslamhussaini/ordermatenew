// lib/features/customers/domain/entities/customer.dart

import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  // Calculated field from location query

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.createdBy,
    this.isActive = true,
    this.distanceMeters,
    this.businessTypeId,
    this.businessTypeName,
    this.chartOfAccountId,
  });
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String address;
  final double latitude;
  final double longitude;
  final String? createdBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? distanceMeters;

  final int? businessTypeId; // FK
  final String? businessTypeName; // Fetched via join (optional usage)
  final String? chartOfAccountId;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? distanceMeters,
    int? businessTypeId,
    String? businessTypeName,
    String? chartOfAccountId,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      businessTypeId: businessTypeId ?? this.businessTypeId,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      chartOfAccountId: chartOfAccountId ?? this.chartOfAccountId,
    );
  }

  String get distanceKm {
    if (distanceMeters == null) return 'N/A';
    return '${(distanceMeters! / 1000).toStringAsFixed(2)} km';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        address,
        latitude,
        longitude,
        createdBy,
        isActive,
        createdAt,
        updatedAt,
        distanceMeters,
        businessTypeId,
        businessTypeName,
        chartOfAccountId,
      ];
}
