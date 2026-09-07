import 'package:ordermate/features/organization/domain/entities/organization.dart';

class OrganizationModel extends Organization {
  const OrganizationModel({
    required super.id,
    required super.name,
    required super.code,
    required super.createdAt,
    required super.updatedAt,
    super.isActive,
    super.logoUrl,
    super.storeCount,
    super.businessTypeId,
    super.isGL,
    super.isSales,
    super.isInventory,
    super.isHR,
    super.isSettings,
    super.planType,
    super.entitlementMode,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['omtbl_stores'] is List &&
        (json['omtbl_stores'] as List).isNotEmpty) {
      final first = (json['omtbl_stores'] as List).first;
      if (first is Map && first.containsKey('count')) {
        count = first['count'] as int;
      }
    }
    // Also support direct 'store_count' if we change query or cache structure
    if (json.containsKey('store_count')) {
      count = json['store_count'] as int;
    }

    return OrganizationModel(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      code: json['code']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      logoUrl: json['logo_url']?.toString(),
      storeCount: count,
      businessTypeId: json['business_type_id'] as int?,
      isGL: json['is_gl'] as bool? ?? false,
      isSales: json['is_sales'] as bool? ?? false,
      isInventory: json['is_inventory'] as bool? ?? false,
      isHR: json['is_hr'] as bool? ?? false,
      isSettings: json['is_settings'] as bool? ?? true,
      planType: json['plan_type']?.toString() ?? 'free',
      entitlementMode: json['entitlement_mode']?.toString() ?? 'legacy',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'logo_url': logoUrl,
      'store_count': storeCount,
      'business_type_id': businessTypeId,
      'is_gl': isGL,
      'is_sales': isSales,
      'is_inventory': isInventory,
      'is_hr': isHR,
      'is_settings': isSettings,
      'plan_type': planType,
      'entitlement_mode': entitlementMode,
    };
  }
}
