import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/services/auth_service.dart';

bool canRead(String module) =>
    AuthService.permissionsFor(module).contains(Permission.read);
bool canWrite(String module) =>
    AuthService.permissionsFor(module).contains(Permission.write);
bool canDelete(String module) =>
    AuthService.permissionsFor(module).contains(Permission.delete);
