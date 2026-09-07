class AppForm {
  final int id;
  final String name;
  final String code;
  final String? module;
  final bool isActive;

  AppForm({
    required this.id,
    required this.name,
    required this.code,
    this.module,
    this.isActive = true,
  });

  factory AppForm.fromMap(Map<String, dynamic> map) {
    return AppForm(
      id: map['id'] as int,
      name: map['form_name'] as String,
      code: map['form_code'] as String,
      module: map['module_name'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}

class FormPrivilege {
  final int? id;
  final int formId;
  final int? roleId;
  final String? employeeId;
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final bool canRead;
  final bool canPrint;

  FormPrivilege({
    this.id,
    required this.formId,
    this.roleId,
    this.employeeId,
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canRead = false,
    this.canPrint = false,
  });

  factory FormPrivilege.fromMap(Map<String, dynamic> map) {
    return FormPrivilege(
      id: map['id'] as int?,
      formId: map['form_id'] as int,
      roleId: map['role_id'] as int?,
      employeeId: map['employee_id'] as String?,
      canView: (map['can_view'] as int? ?? 0) == 1,
      canAdd: (map['can_add'] as int? ?? 0) == 1,
      canEdit: (map['can_edit'] as int? ?? 0) == 1,
      canDelete: (map['can_delete'] as int? ?? 0) == 1,
      canRead: (map['can_read'] as int? ?? 0) == 1,
      canPrint: (map['can_print'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'form_id': formId,
      'role_id': roleId,
      'employee_id': employeeId,
      'can_view': canView ? 1 : 0,
      'can_add': canAdd ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_delete': canDelete ? 1 : 0,
      'can_read': canRead ? 1 : 0,
      'can_print': canPrint ? 1 : 0,
    };
  }

  FormPrivilege copyWith({
    bool? canView,
    bool? canAdd,
    bool? canEdit,
    bool? canDelete,
    bool? canRead,
    bool? canPrint,
  }) {
    return FormPrivilege(
      id: id,
      formId: formId,
      roleId: roleId,
      employeeId: employeeId,
      canView: canView ?? this.canView,
      canAdd: canAdd ?? this.canAdd,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canRead: canRead ?? this.canRead,
      canPrint: canPrint ?? this.canPrint,
    );
  }
}
