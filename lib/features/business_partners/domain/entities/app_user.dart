class AppUser {
  final String id;
  final String businessPartnerId;
  final String email;
  final String? fullName;
  final int roleId;
  final String? roleName;
  final int organizationId;
  final int storeId;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime updatedAt;
  final String? password;

  AppUser({
    required this.id,
    required this.businessPartnerId,
    required this.email,
    this.fullName,
    required this.roleId,
    this.roleName,
    required this.organizationId,
    required this.storeId,
    this.isActive = true,
    this.lastLogin,
    required this.updatedAt,
    this.password,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      businessPartnerId: json['business_partner_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      roleId: json['role_id'] as int? ?? 0,
      roleName: json['role_name'] as String? ??
          (json['omtbl_roles'] is Map
              ? json['omtbl_roles']['role_name'] as String?
              : null),
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      updatedAt: json['updated_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now(),
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_partner_id': businessPartnerId,
      'email': email,
      'full_name': fullName,
      'role_id': roleId,
      'role_name': roleName,
      'organization_id': organizationId,
      'store_id': storeId,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // SECURITY (C-3): password intentionally NOT transmitted to Supabase.
    };
  }

  AppUser copyWith({
    String? id,
    String? businessPartnerId,
    String? email,
    String? fullName,
    int? roleId,
    String? roleName,
    int? organizationId,
    int? storeId,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? updatedAt,
    String? password,
  }) {
    return AppUser(
      id: id ?? this.id,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      updatedAt: updatedAt ?? this.updatedAt,
      password: password ?? this.password,
    );
  }
}
