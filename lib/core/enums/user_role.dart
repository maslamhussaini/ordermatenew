enum UserRole {
  superUser,
  admin,
  staff,
  viewer;

  String get label {
    switch (this) {
      case UserRole.superUser:
        return 'Super User';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
      case UserRole.viewer:
        return 'Viewer';
    }
  }
}
