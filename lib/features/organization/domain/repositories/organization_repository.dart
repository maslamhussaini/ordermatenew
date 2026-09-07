import 'dart:typed_data';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';

abstract class OrganizationRepository {
  // Organization
  Future<List<Organization>> getOrganizations();
  Future<Organization?> getOrganization(int id);
  Future<void> updateOrganization(Organization organization);
  Future<String> uploadOrganizationLogo(Uint8List bytes, String fileName);
  Future<Organization> createOrganization(
    String name,
    String? taxId,
    bool hasMultipleBranches,
    String? logoUrl, {
    int? businessTypeId,
  });
  Future<void> deleteOrganization(int id);

  /// Creates a single `omtbl_financial_sessions` row for [organizationId].
  ///
  /// Unlike `createOrganization`'s internal best-effort session insert, this
  /// method does NOT swallow errors: callers (e.g. registration screens) are
  /// expected to catch and surface failures so a broken registration is
  /// never silently reported as successful.
  Future<void> createFinancialSession({
    required int organizationId,
    required int syear,
    required DateTime startDate,
    required DateTime endDate,
    String? narration,
  });

  // Logo caching
  Future<void> cacheLogo(int orgId, Uint8List logoBytes);
  Future<Uint8List?> getCachedLogo(int orgId);

  // Stores
  Future<List<Store>> getStores(int organizationId);
  Future<Store> createStore(Store store);
  Future<void> updateStore(Store store);
  Future<void> deleteStore(int storeId);
}
