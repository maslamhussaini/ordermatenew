// lib/features/auth/domain/entities/user.dart

import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.role = 'employee',
    this.lastLatitude,
    this.lastLongitude,
    this.lastLocationUpdatedAt,
    this.isActive = true,
    this.organizationName,
    this.tablePrefix,
    this.organizationId,
    this.storeId,
    this.roleId,
    this.businessPartnerId,
  });
  final String id;
  final String? businessPartnerId;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? organizationName;
  final String? tablePrefix;
  final int? organizationId;
  final int? storeId;
  final int? roleId;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastLocationUpdatedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? role,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastLocationUpdatedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationName,
    String? tablePrefix,
    int? organizationId,
    int? storeId,
    int? roleId,
    String? businessPartnerId,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      organizationName: organizationName ?? this.organizationName,
      tablePrefix: tablePrefix ?? this.tablePrefix,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      roleId: roleId ?? this.roleId,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastLocationUpdatedAt:
          lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasLocation => lastLatitude != null && lastLongitude != null;

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        phone,
        role,
        lastLatitude,
        lastLongitude,
        lastLocationUpdatedAt,
        isActive,
        createdAt,
        updatedAt,
        organizationName,
        tablePrefix,
        organizationId,
        storeId,
        roleId,
        businessPartnerId,
      ];
}
