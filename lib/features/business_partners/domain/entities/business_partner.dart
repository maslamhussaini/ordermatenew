import 'package:equatable/equatable.dart';

class BusinessPartner extends Equatable {
  const BusinessPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.contactPerson,
    this.latitude,
    this.longitude,
    this.businessTypeId,
    this.cityId,
    this.stateId,
    this.countryId,
    this.postalCode,
    this.createdBy,
    this.managerId,
    this.roleId,
    this.organizationId,
    this.storeId,
    this.isCustomer = false,
    this.isVendor = false,
    this.isEmployee = false,
    this.isSupplier = false,
    this.distanceMeters,
    this.businessTypeName,
    this.roleName,
    this.departmentId,
    this.departmentName,
    this.chartOfAccountId,
    this.paymentTermId,
    this.password,
    this.openingBalance = 0.0,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String address;
  final String? contactPerson;

  // Location
  final double? latitude;
  final double? longitude;
  final int? distanceMeters; // Runtime field

  final String? businessTypeName; // New: For offline display
  final String?
      roleName; // New: For offline display (e.g. Employee Designation)
  final String? departmentName; // New: For offline display

  final String? createdBy;
  final String? managerId;
  final int? roleId;
  final int? organizationId;
  final int? storeId;
  final int? businessTypeId;
  final int? cityId;
  final int? stateId;
  final int? countryId;
  final String? postalCode;

  final int? departmentId;
  final String? chartOfAccountId;
  final int? paymentTermId;
  final String? password;

  // Roles
  final bool isCustomer;
  final bool isVendor;
  final bool isEmployee;
  final bool isSupplier;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Helpers
  String get distanceKm {
    if (distanceMeters == null) return '';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  BusinessPartner copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? contactPerson,
    double? latitude,
    double? longitude,
    int? businessTypeId,
    String? businessTypeName,
    int? cityId,
    int? stateId,
    int? countryId,
    String? postalCode,
    String? createdBy,
    String? managerId,
    int? roleId,
    String? roleName,
    int? organizationId,
    int? storeId,
    bool? isCustomer,
    bool? isVendor,
    bool? isEmployee,
    bool? isSupplier,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? distanceMeters,
    int? departmentId,
    String? departmentName,
    String? chartOfAccountId,
    int? paymentTermId,
    String? password,
    double? openingBalance,
  }) {
    return BusinessPartner(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      businessTypeId: businessTypeId ?? this.businessTypeId,
      businessTypeName: businessTypeName ?? this.businessTypeName,
      cityId: cityId ?? this.cityId,
      stateId: stateId ?? this.stateId,
      countryId: countryId ?? this.countryId,
      postalCode: postalCode ?? this.postalCode,
      createdBy: createdBy ?? this.createdBy,
      managerId: managerId ?? this.managerId,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      isCustomer: isCustomer ?? this.isCustomer,
      isVendor: isVendor ?? this.isVendor,
      isEmployee: isEmployee ?? this.isEmployee,
      isSupplier: isSupplier ?? this.isSupplier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      chartOfAccountId: chartOfAccountId ?? this.chartOfAccountId,
      paymentTermId: paymentTermId ?? this.paymentTermId,
      password: password ?? this.password,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }

  final double openingBalance;

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        address,
        contactPerson,
        latitude,
        longitude,
        businessTypeId,
        businessTypeName,
        cityId,
        stateId,
        countryId,
        postalCode,
        createdBy,
        managerId,
        roleId,
        roleName,
        organizationId,
        storeId,
        isCustomer,
        isVendor,
        isEmployee,
        isSupplier,
        isActive,
        createdAt,
        updatedAt,
        distanceMeters,
        departmentId,
        departmentName,
        chartOfAccountId,
        paymentTermId,
        password,
      ];
}
