import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/entitlement/data/repositories/supabase_entitlement_repository.dart';
import 'package:ordermate/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:ordermate/features/entitlement/domain/services/effective_access_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

/// Phase 3B-3 DI wiring: this is the ONE place `SupabaseEntitlementRepository`
/// and `EffectiveAccessService` are instantiated. Router, menu, and
/// ReportsHub all read through these providers -- none of them should ever
/// construct their own repository/service instance.
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return SupabaseEntitlementRepository();
});

final effectiveAccessServiceProvider = Provider<EffectiveAccessService>((ref) {
  return EffectiveAccessService(ref.watch(entitlementRepositoryProvider));
});

/// Per-form commercial availability for the currently selected organization.
///
/// A Riverpod `.family` future is cached per `formId` and only re-evaluated
/// when its watched dependency (the selected organization) changes --
/// widget rebuilds that don't change the org reuse the cached result rather
/// than re-querying Supabase, satisfying the "avoid repeated DB requests on
/// every rebuild" requirement without hand-rolled caching.
///
/// Returns `false` (fail-closed, never fail-open) if no organization is
/// selected yet or if the entitlement lookup itself throws -- see
/// EffectiveAccessService's own module/form catalog lookups, which already
/// fail closed on a missing/unknown catalog row.
final formAccessProvider =
    FutureProvider.family<bool, int>((ref, formId) async {
  final org = ref.watch(
      organizationProvider.select((s) => s.selectedOrganization));
  if (org == null) return false;

  final service = ref.watch(effectiveAccessServiceProvider);
  try {
    return await service.effectiveFormAccess(org, formId);
  } catch (_) {
    return false;
  }
});

/// Same as [formAccessProvider] but for reports -- goes through
/// `effectiveReportAccess` so the individual-report and bundle acquisition
/// paths are evaluated, not just the module/form path.
final reportAccessProvider =
    FutureProvider.family<bool, int>((ref, formId) async {
  final org = ref.watch(
      organizationProvider.select((s) => s.selectedOrganization));
  if (org == null) return false;

  final service = ref.watch(effectiveAccessServiceProvider);
  try {
    return await service.effectiveReportAccess(org, formId);
  } catch (_) {
    return false;
  }
});

/// Module-level commercial availability for the currently selected
/// organization -- used where a whole module's availability is needed
/// rather than one specific form/report (e.g. a future module-level menu
/// section header). Same caching/fail-closed behavior as [formAccessProvider].
final moduleAccessProvider =
    FutureProvider.family<bool, String>((ref, moduleId) async {
  final org = ref.watch(
      organizationProvider.select((s) => s.selectedOrganization));
  if (org == null) return false;

  final service = ref.watch(effectiveAccessServiceProvider);
  try {
    return await service.effectiveModuleAccess(org, moduleId);
  } catch (_) {
    return false;
  }
});
