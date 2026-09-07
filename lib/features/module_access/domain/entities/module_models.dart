class Module {
  final String id;
  final String name;
  
  Module({required this.id, required this.name});

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'],
      name: json['display_name'], // DB column is display_name, not name
    );
  }
}

class AppForm {
  final int id;
  final String name;
  final String? moduleId;

  AppForm({required this.id, required this.name, this.moduleId});

  factory AppForm.fromJson(Map<String, dynamic> json) {
    return AppForm(
      id: json['id'],
      name: json['form_name'], // DB column form_name
      moduleId: json['module_id'],
    );
  }
}

class ModuleAccess {
  final String moduleId;
  final int organizationId;
  final bool isActive;

  ModuleAccess({
    required this.moduleId,
    required this.organizationId,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'module_id': moduleId,
      'organization_id': organizationId,
      'is_active': isActive,
    };
  }
}

class ModuleAccessItem {
  final int formId;
  final String moduleId;
  final int organizationId;
  final bool isEnabled;

  ModuleAccessItem({
    required this.formId,
    required this.moduleId,
    required this.organizationId,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'form_id': formId,
      'module_id': moduleId,
      'organization_id': organizationId,
      'is_enabled': isEnabled,
    };
  }
}
