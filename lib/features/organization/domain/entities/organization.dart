import 'package:equatable/equatable.dart';

class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.logoUrl,
    this.storeCount = 0,
    this.businessTypeId,
    this.isGL = false,
    this.isSales = false,
    this.isInventory = false,
    this.isHR = false,
    this.isSettings = true,
    this.planType = 'free',
    this.entitlementMode = 'legacy',
  });

  final int id;
  final String name;
  final String? code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? logoUrl;
  final int storeCount;
  final int? businessTypeId;
  final bool isGL;
  final bool isSales;
  final bool isInventory;
  final bool isHR;
  final bool isSettings;
  final String planType;

  /// Phase 3A `omtbl_organizations.entitlement_mode`: 'legacy' or 'explicit'.
  /// Defaults to 'legacy' so every existing construction site (which never
  /// sets this) keeps behaving exactly as before -- see
  /// PHASE3B_FINAL_COMMERCIAL_ENTITLEMENT_DECISIONS.md for the full model.
  final String entitlementMode;

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        isActive,
        createdAt,
        updatedAt,
        logoUrl,
        storeCount,
        businessTypeId,
        isGL,
        isSales,
        isInventory,
        isHR,
        isSettings,
        planType,
        entitlementMode,
      ];
}

/// Single source of truth for mapping a module identifier to this
/// organization's purchased/enabled module entitlement (the is_gl/is_sales/
/// is_inventory/is_hr booleans). Used by app_menu.dart (menu visibility),
/// app_router.dart (route access), and privilege_management_screen.dart
/// (form/privilege listing) so the three stay consistent instead of each
/// carrying its own separate if-chain.
///
/// Accepts both the AppRoute.module vocabulary (e.g. 'orders', 'vendors')
/// and the omtbl_app_forms.module_name vocabulary (e.g. 'Sales',
/// 'Purchasing', 'CRM') since both are used, in different screens, to mean
/// the same underlying entitlement.
///
/// This is deliberately module-level only. Per-form and per-report
/// entitlement (e.g. "module purchased but this one report wasn't") has no
/// backing table today and would require a schema change -- not attempted
/// here. Baseline/administrative capabilities (dashboard, stores, settings,
/// organization profile, reports, admin/users) and any unrecognized module
/// key fail OPEN (visible) so this helper never silently hides a route it
/// wasn't explicitly told to gate.
extension OrganizationModuleAccess on Organization {
  bool isModuleEnabled(String? moduleKey) {
    switch (moduleKey?.toLowerCase()) {
      case 'accounting':
      case 'gl':
        return isGL;
      case 'orders':
      case 'invoices':
      case 'sales':
      case 'customers':
      case 'crm':
        return isSales;
      case 'products':
      case 'inventory':
      case 'vendors':
      case 'suppliers':
      case 'purchasing':
        return isInventory;
      case 'employees':
      case 'hr':
        return isHR;
      default:
        return true;
    }
  }
}
