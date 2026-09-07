// lib/features/customers/data/models/customer_model.dart

import 'package:ordermate/features/customers/domain/entities/customer.dart';

class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.createdAt,
    required super.updatedAt,
    super.email,
    super.createdBy,
    super.isActive,
    super.distanceMeters,
    super.businessTypeId,
    super.businessTypeName,
    super.chartOfAccountId,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    // Handling nested JSON from joins if available: e.g. omtbl_business_types: { business_type: 'Retailer' }
    String? businessTypeName;
    if (json['omtbl_business_types'] != null &&
        json['omtbl_business_types'] is Map) {
      final businessTypeData = json['omtbl_business_types'] as Map;
      businessTypeName = businessTypeData['business_type'] as String?;
    }

    return CustomerModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      createdBy: json['created_by']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
      businessTypeId: json['business_type_id'] as int?,
      businessTypeName: businessTypeName,
      chartOfAccountId: json['chart_of_account_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_by': createdBy,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'business_type_id': businessTypeId,
      'chart_of_account_id': chartOfAccountId,
    };
  }

  Customer toEntity() => this;
}
