import 'package:ordermate/core/enums/permission.dart';

class PermissionObject {
  final String module;
  final Permission action;

  const PermissionObject(this.module, this.action);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionObject &&
          runtimeType == other.runtimeType &&
          module == other.module &&
          action == other.action;

  @override
  int get hashCode => module.hashCode ^ action.hashCode;
}
