import 'package:ordermate/features/vendors/domain/entities/vendor.dart';

class VendorModel extends Vendor {
  const VendorModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    super.contactPerson,
    super.phone,
    super.email,
    super.address,
    super.isSupplier,
    super.isVendor,
    super.isActive,
    required super.organizationId,
    required super.storeId,
    super.productCount,
    super.chartOfAccountId,
    super.createdBy,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isSupplier: json['is_supplier'] == 1 || json['is_supplier'] == true,
      isVendor: json['is_vendor'] == 1 || json['is_vendor'] == true,
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active'] == null,
      productCount: _parseProductCount(json['product_count']),
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      chartOfAccountId: json['chart_of_account_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  static int _parseProductCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is List) {
      if (value.isEmpty) return 0;
      final first = value.first;
      if (first is Map && first.containsKey('count')) {
        return first['count'] as int? ?? 0;
      }
      return value.length;
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'is_supplier': isSupplier ? 1 : 0,
      'is_vendor': isVendor ? 1 : 0,
      // FIX (H-6): emit a bool, matching BusinessPartnerModel and the
      // `.eq('is_active', true)` read path. Both models write
      // omtbl_businesspartners; the int form was rejected by a bool column.
      'is_active': isActive,
      'organization_id': organizationId,
      'store_id': storeId,
      'chart_of_account_id': chartOfAccountId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
