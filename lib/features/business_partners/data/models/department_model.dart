import 'package:ordermate/features/business_partners/domain/entities/department.dart';

class DepartmentModel extends Department {
  const DepartmentModel({
    required super.id,
    required super.name,
    super.organizationId,
    super.status,
    super.isSynced,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as int,
      name: (json['name'] ?? json['dept_name'])
          as String, // Handle potential naming variations
      organizationId: (json['organization_id'] as int?) ?? 0,
      status: json['status'] == 1 || json['status'] == true,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'organization_id': organizationId,
      'status': status ? 1 : 0,
    };
  }
}
