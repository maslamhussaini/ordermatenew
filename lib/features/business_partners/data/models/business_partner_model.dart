import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';

class BusinessPartnerModel extends BusinessPartner {
  const BusinessPartnerModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.address,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.email,
    super.contactPerson,
    super.latitude,
    super.longitude,
    super.businessTypeId,
    super.businessTypeName,
    super.cityId,
    super.stateId,
    super.countryId,
    super.postalCode,
    super.createdBy,
    super.isCustomer,
    super.isVendor,
    super.isEmployee,
    super.isSupplier,
    super.roleId,
    super.roleName,
    super.managerId,
    super.organizationId,
    super.storeId,
    super.distanceMeters,
    super.departmentId,
    super.departmentName,
    super.chartOfAccountId,
    super.paymentTermId,
    super.password,
    super.openingBalance,
  });

  factory BusinessPartnerModel.fromJson(Map<String, dynamic> json) {
    return BusinessPartnerModel(
      id: json['id'] as String? ?? '', // Handle potential null id
      name: json['name'] as String? ??
          'Unknown Partner', // Handle potential null name
      phone: (json['phone'] as String?) ?? '',
      email: json['email'] as String?,
      address: (json['address'] as String?) ?? '',
      contactPerson: json['contact_person'] as String?,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      businessTypeId: json['business_type_id'] as int?,
      businessTypeName: json['omtbl_business_types'] != null
          ? (json['omtbl_business_types']
              as Map<String, dynamic>)['business_type'] as String?
          : json['business_type_name'] as String?, // Fallback for local
      cityId: json['city_id'] as int?,
      stateId: json['state_id'] as int?,
      countryId: json['country_id'] as int?,
      postalCode: json['postal_code'] as String?,
      createdBy: json['created_by'] as String?,
      managerId: json['manager_id'] as String?,
      roleId: json['role_id'] as int?,
      roleName: json['omtbl_roles'] != null
          ? (json['omtbl_roles'] as Map<String, dynamic>)['role_name']
              as String?
          : json['role_name'] as String?, // Fallback for local
      organizationId: json['organization_id'] as int?,
      storeId: json['store_id'] as int?,
      isCustomer: json['is_customer'] == 1 || json['is_customer'] == true,
      isVendor: json['is_vendor'] == 1 || json['is_vendor'] == true,
      isEmployee: json['is_employee'] == 1 || json['is_employee'] == true,
      isSupplier: json['is_supplier'] == 1 || json['is_supplier'] == true,
      isActive: json['is_active'] == 1 ||
          json['is_active'] == true ||
          json['is_active'] == null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now())
          : DateTime.now(),
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toInt()
          : null,
      departmentId: json['department_id'] as int?,
      departmentName: json['omtbl_depts'] != null
          ? (json['omtbl_depts'] as Map<String, dynamic>)['name'] as String?
          : json['department_name'] as String?, // Fallback for local
      chartOfAccountId: json['chart_of_account_id']?.toString(),
      paymentTermId: json['payment_term_id'] as int?,
      password: json['password'] as String?,
      // opening_balance field removed - not in database schema
      openingBalance: 0.0, // Always use default value
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'contact_person': contactPerson,
      'latitude': latitude,
      'longitude': longitude,
      'business_type_id': businessTypeId,
      'city_id': cityId,
      'state_id': stateId,
      'country_id': countryId,
      'postal_code': postalCode,
      'created_by': createdBy,
      'manager_id': managerId,
      'role_id': roleId,
      'organization_id': organizationId,
      'store_id': storeId,
      'department_id': departmentId,
      'is_customer': isCustomer ? 1 : 0,
      'is_vendor': isVendor ? 1 : 0,
      'is_employee': isEmployee ? 1 : 0,
      'is_supplier': isSupplier ? 1 : 0,
      'is_active': isActive,
      'chart_of_account_id': chartOfAccountId,
      'payment_term_id': paymentTermId,
      // SECURITY (C-3): password intentionally NOT transmitted to Supabase.
      // 'opening_balance': openingBalance, // Removed - column doesn't exist in database
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
