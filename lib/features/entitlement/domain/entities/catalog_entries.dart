/// Read-only projections of the Phase 3A catalog tables, scoped to exactly
/// the fields the entitlement evaluation layer needs. Deliberately separate
/// from the older `Module`/`AppForm` models in `module_access/` -- those
/// back a still-unfinished admin write screen and carry a different (write)
/// responsibility; this evaluation layer only ever reads.

/// A row from `omtbl_modules`.
class ModuleCatalogEntry {
  const ModuleCatalogEntry({
    required this.id,
    required this.isPurchasable,
  });

  final String id;
  final bool isPurchasable;

  factory ModuleCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ModuleCatalogEntry(
      id: json['id'] as String,
      isPurchasable: json['is_purchasable'] as bool? ?? false,
    );
  }
}

/// A row from `omtbl_app_forms` (both `kind='form'` and `kind='report'`).
class AppFormCatalogEntry {
  const AppFormCatalogEntry({
    required this.id,
    required this.moduleId,
    required this.isActive,
    required this.kind,
  });

  final int id;
  final String? moduleId;
  final bool isActive;

  /// 'form' or 'report'.
  final String kind;

  bool get isReport => kind == 'report';

  factory AppFormCatalogEntry.fromJson(Map<String, dynamic> json) {
    return AppFormCatalogEntry(
      id: json['id'] as int,
      moduleId: json['module_id'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      kind: json['kind'] as String? ?? 'form',
    );
  }
}
