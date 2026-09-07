import 'package:equatable/equatable.dart';

class AppRole extends Equatable {
  final int id;
  final String roleName;
  final String? description;
  final int? departmentId;
  final bool canRead;
  final bool canWrite;
  final bool canEdit;
  final bool canPrint;
  final bool isSystem;

  const AppRole({
    required this.id,
    required this.roleName,
    this.description,
    this.departmentId,
    this.canRead = false,
    this.canWrite = false,
    this.canEdit = false,
    this.canPrint = false,
    this.isSystem = false,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as int,
      roleName: json['role_name'] as String,
      description: json['description'] as String?,
      departmentId: json['department_id'] as int?,
      canRead: json['can_read'] == 1 || json['can_read'] == true,
      canWrite: json['can_write'] == 1 || json['can_write'] == true,
      canEdit: json['can_edit'] == 1 || json['can_edit'] == true,
      canPrint: json['can_print'] == 1 || json['can_print'] == true,
      isSystem: json['is_system'] == 1 || json['is_system'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': roleName,
      'description': description,
      'department_id': departmentId,
      'can_read': canRead ? 1 : 0,
      'can_write': canWrite ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_print': canPrint ? 1 : 0,
      'is_system': isSystem ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
        id,
        roleName,
        description,
        departmentId,
        canRead,
        canWrite,
        canEdit,
        canPrint,
        isSystem,
      ];
}
