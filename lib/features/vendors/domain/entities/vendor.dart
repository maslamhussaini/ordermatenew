// lib/features/vendors/domain/entities/vendor.dart

import 'package:equatable/equatable.dart';

class Vendor extends Equatable {
  const Vendor({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.isSupplier = false,
    this.isVendor = false,
    this.isActive = true,
    this.productCount,
    this.organizationId,
    this.storeId,
    this.chartOfAccountId,
    this.createdBy,
  });
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final bool isSupplier;
  final bool isVendor;
  final bool isActive;
  final int? productCount;
  final int? organizationId;
  final int? storeId;
  final String? chartOfAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;
  // omtbl_users.id of the original creator. Must never be the Supabase
  // Auth UID -- omtbl_businesspartners.created_by's foreign key targets
  // omtbl_users.id. Preserved (not re-stamped) on update.
  final String? createdBy;

  Vendor copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    bool? isSupplier,
    bool? isVendor,
    bool? isActive,
    int? productCount,
    int? organizationId,
    int? storeId,
    String? chartOfAccountId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isSupplier: isSupplier ?? this.isSupplier,
      isVendor: isVendor ?? this.isVendor,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      chartOfAccountId: chartOfAccountId ?? this.chartOfAccountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        contactPerson,
        phone,
        email,
        address,
        isSupplier,
        isVendor,
        isActive,
        productCount,
        organizationId,
        storeId,
        chartOfAccountId,
        createdAt,
        updatedAt,
        createdBy,
      ];
}
