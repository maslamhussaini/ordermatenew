// Focused tests for this pass's created_by identity fixes:
//   - AuthState.applicationIdentityResolved (closes the sign-in race window
//     where userId briefly holds the Supabase Auth UID instead of
//     omtbl_users.id)
//   - Vendor entity's new createdBy field and VendorModel's JSON handling
//     (createdBy must round-trip on read, and must NEVER be emitted by
//     toJson(), since toJson() is shared by both create and update and
//     update must never overwrite the original creator)
//
// These are pure-data tests -- no widget harness, no Supabase mocking --
// matching the scope-conservation instruction for this pass.
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/data/models/vendor_model.dart';

void main() {
  group('AuthState.applicationIdentityResolved', () {
    test('defaults to false (identity not yet resolved)', () {
      const state = AuthState();
      expect(state.applicationIdentityResolved, isFalse);
    });

    test(
        'setting userId to the Auth UID at sign-in does NOT imply resolved',
        () {
      // This is exactly the race window: userId is non-empty (the Auth
      // UID) but applicationIdentityResolved must still be false, so
      // create/save flows checking isEmpty alone would be fooled.
      const initial = AuthState();
      final afterSignIn = initial.copyWith(
        isLoggedIn: true,
        userId: 'auth-uid-1234',
      );
      expect(afterSignIn.userId, 'auth-uid-1234');
      expect(afterSignIn.applicationIdentityResolved, isFalse);
    });

    test(
        'explicitly resolving with a real omtbl_users.id sets the flag true',
        () {
      const initial = AuthState();
      final resolved = initial.copyWith(
        userId: 'omtbl-users-id-5678',
        applicationIdentityResolved: true,
      );
      expect(resolved.userId, 'omtbl-users-id-5678');
      expect(resolved.applicationIdentityResolved, isTrue);
    });

    test('once resolved, an unrelated copyWith call does not reset it', () {
      const initial = AuthState();
      final resolved = initial.copyWith(
        userId: 'omtbl-users-id-5678',
        applicationIdentityResolved: true,
      );
      final afterUnrelatedUpdate =
          resolved.copyWith(userFullName: 'Jane Doe');
      expect(afterUnrelatedUpdate.applicationIdentityResolved, isTrue);
      expect(afterUnrelatedUpdate.userId, 'omtbl-users-id-5678');
    });

    test('sign-out (fresh AuthState) resets resolution to false', () {
      const initial = AuthState();
      final resolved = initial.copyWith(
        userId: 'omtbl-users-id-5678',
        applicationIdentityResolved: true,
      );
      expect(resolved.applicationIdentityResolved, isTrue);
      const afterSignOut = AuthState(); // mirrors _clearAuthState()
      expect(afterSignOut.applicationIdentityResolved, isFalse);
      expect(afterSignOut.userId, isEmpty);
    });

    test('superuser path resolving with empty employeeId stays unresolved',
        () {
      // Mirrors the guard added in auth_provider.dart:
      // applicationIdentityResolved: employeeId != null && employeeId.isNotEmpty
      const initial = AuthState();
      final employeeId = _nullEmployeeId(); // simulates a missing omtbl_users row
      final result = initial.copyWith(
        userId: employeeId ?? '',
        role: UserRole.admin,
        applicationIdentityResolved:
            employeeId != null && employeeId.isNotEmpty,
      );
      expect(result.applicationIdentityResolved, isFalse);
      expect(result.userId, isEmpty);
    });
  });

  group('Vendor.createdBy', () {
    test('defaults to null', () {
      final vendor = Vendor(
        id: 'v1',
        name: 'Test Vendor',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(vendor.createdBy, isNull);
    });

    test('copyWith preserves createdBy when not specified', () {
      final vendor = Vendor(
        id: 'v1',
        name: 'Test Vendor',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        createdBy: 'omtbl-users-id-creator',
      );
      final updated = vendor.copyWith(name: 'Renamed Vendor');
      expect(updated.createdBy, 'omtbl-users-id-creator');
      expect(updated.name, 'Renamed Vendor');
    });
  });

  group('VendorModel JSON handling for created_by', () {
    test('fromJson reads created_by', () {
      final model = VendorModel.fromJson({
        'id': 'v1',
        'name': 'Test Vendor',
        'organization_id': 1,
        'store_id': 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'created_by': 'omtbl-users-id-creator',
      });
      expect(model.createdBy, 'omtbl-users-id-creator');
    });

    test(
        'toJson never emits created_by (shared by create and update paths -- '
        'update must never overwrite the original creator)', () {
      final model = VendorModel(
        id: 'v1',
        name: 'Test Vendor',
        organizationId: 1,
        storeId: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        createdBy: 'omtbl-users-id-creator',
      );
      final json = model.toJson();
      expect(json.containsKey('created_by'), isFalse,
          reason:
              'created_by must be added explicitly by the create path only '
              '(vendor_repository_impl.dart), never via the shared toJson() '
              'that updateVendor also uses');
    });
  });
}

// Kept as a real (non-const-collapsed) function call so the analyzer
// doesn't flag the `employeeId != null` check above as always-false.
String? _nullEmployeeId() => null;
