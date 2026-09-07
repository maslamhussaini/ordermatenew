import 'package:ordermate/features/organization/domain/entities/store.dart';

class StoreModel extends Store {
  const StoreModel({
    required super.id,
    required super.organizationId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    super.location,
    super.city,
    super.country,
    super.postalCode,
    super.phone,
    super.storeDefaultCurrency,
    super.isActive,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] as int? ?? 0,
      organizationId: json['organization_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown Store',
      storeDefaultCurrency: json['store_default_currency']?.toString() ?? 'USD',
      location: json['location']?.toString(),
      city: json['store_city']?.toString(),
      country: json['store_country']?.toString(),
      postalCode: json['store_postal_code']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'store_default_currency': storeDefaultCurrency,
      'location': location,
      'store_city': city,
      'store_country': country,
      'store_postal_code': postalCode,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
