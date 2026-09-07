enum Permission { read, write, delete }

class RolePermissions {
  static const Map<String, Set<Permission>> admin = {
    'dashboard': {Permission.read},
    'customers': {Permission.read, Permission.write, Permission.delete},
    'orders': {Permission.read, Permission.write, Permission.delete},
    'invoices': {Permission.read, Permission.write, Permission.delete},
    'products': {Permission.read, Permission.write, Permission.delete},
    'inventory': {Permission.read, Permission.write, Permission.delete},
    'vendors': {Permission.read, Permission.write, Permission.delete},
    'employees': {Permission.read, Permission.write, Permission.delete},
    'stores': {Permission.read, Permission.write, Permission.delete},
    'reports': {Permission.read},
    'organization': {Permission.read, Permission.write},
    'settings': {Permission.read, Permission.write},
    'accounting': {Permission.read, Permission.write, Permission.delete},
    'location_tracking': {Permission.read, Permission.write, Permission.delete},
  };

  static const Map<String, Set<Permission>> staff = {
    'dashboard': {Permission.read},
    'customers': {
      Permission.read,
      Permission.write
    }, // Staff can create/edit but not delete
    'orders': {Permission.read, Permission.write},
    'invoices': {
      Permission.read
    }, // Read only? Or write? Assuming write for now
    'products': {Permission.read},
    'inventory': {Permission.read},
    'vendors': {Permission.read},
    'employees': {}, // No access
    'stores': {Permission.read},
    'reports': {},
    'organization': {},
    'settings': {Permission.read}, // Maybe basic settings?
    'accounting': {},
  };
}
