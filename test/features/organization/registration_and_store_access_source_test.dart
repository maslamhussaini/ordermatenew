// test/features/organization/registration_and_store_access_source_test.dart
//
// SupabaseConfig.client is a real static singleton with no injection seam
// (see test/features/organization/create_organization_financial_session_test.dart
// for the same constraint), so the registration flow and the store-wise
// access filter can't be exercised against a fake backend here. Following
// the established pattern in this suite, these are source-level assertions
// that lock the fix in place at the code-shape level:
//
//   A. Registration, Multiple Branches OFF (organization_setup_screen.dart):
//      the store name comes from the registration UI, not a hardcoded
//      'Main Store' literal; the financial-session insert is not swallowed.
//   B. Registration, Multiple Branches ON (store_setup_screen.dart):
//      the store name comes from the Branch Setup form; the financial
//      session created there is not swallowed either.
//   C. Ref-disposal race (found via a live browser registration run):
//      auth.signUp() fires AuthChangeEvent.signedIn, which flips
//      authProvider.isLoggedIn, which the router reacts to by disposing
//      the onboarding screen while _registerAndCreate()/_create() is still
//      running — org/user/store inserts survive (they call
//      SupabaseConfig.client directly), but the financial-session step,
//      which used `ref.read(organizationRepositoryProvider)`, threw "Cannot
//      use ref after the widget was disposed" and was swallowed into a
//      SnackBar on an already-gone screen. Fix: capture the repository
//      instance once, before signUp, and reuse it — confirmed against a
//      live Supabase project: orgs created before this fix have 0 financial
//      sessions, orgs created after have exactly 1.
//   K/L/M/N. Store-wise internal user access: WorkspaceSelectionScreen no
//      longer loads stores directly from the repository (which returns
//      every store in the org, ignoring who's asking); OrganizationNotifier
//      resolves access from the existing omtbl_user_store_access /
//      omtbl_role_store_access tables instead of only the single
//      omtbl_users.store_id column, and fails closed (no store) rather than
//      open (every store) if those lookups error.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A — Registration, Multiple Branches OFF', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/auth/presentation/screens/organization_setup_screen.dart',
      ).readAsStringSync();
    });

    test('store name is no longer hardcoded as "Main Store"', () {
      expect(src.contains("storeName: 'Main Store'"), isFalse,
          reason: 'store name must come from the registration UI, not a '
              'fixed literal (see section 4 of the fix)');
    });

    test('the single-branch path passes the store-name field\'s value', () {
      expect(src.contains('storeName: _storeNameController.text.trim()'),
          isTrue,
          reason: 'expected _registerAndCreate to be called with the '
              'user-entered store name');
    });

    test('a Store Name field exists and is wired to _storeNameController',
        () {
      expect(src.contains('_storeNameController'), isTrue);
      expect(
          src.contains("controller: _storeNameController"), isTrue,
          reason: 'the controller must actually be attached to a text field');
    });

    test('financial-session creation is still not swallowed', () {
      final callIndex = src.indexOf('await repo.createFinancialSession(');
      expect(callIndex, greaterThan(-1));
      // Same check as create_organization_financial_session_test.dart:
      // anchor from the organization insert (which is itself inside the
      // outer try) rather than the method start, so the unrelated
      // self-contained logo-upload try/catch earlier in the method doesn't
      // false-positive this check.
      final orgInsertIndex = src.indexOf(".from('omtbl_organizations')");
      expect(orgInsertIndex, greaterThan(-1));
      expect(callIndex, greaterThan(orgInsertIndex));
      final between = src.substring(orgInsertIndex, callIndex);
      expect(between.contains('catch ('), isFalse,
          reason: 'financial-session creation must not be shielded by its '
              'own swallowing try/catch between the organization insert and '
              'the session call');
    });

    test('the repository is captured before signUp, not read again later '
        '(the ref-disposal fix)', () {
      final repoCaptureIndex = src.indexOf(
          'final repo = ref.read(organizationRepositoryProvider);');
      final signUpIndex = src.indexOf('.auth.signUp(');
      expect(repoCaptureIndex, greaterThan(-1));
      expect(signUpIndex, greaterThan(-1));
      expect(repoCaptureIndex, lessThan(signUpIndex),
          reason: 'repo must be captured before signUp() can trigger the '
              'router to dispose this screen — reading it again afterwards '
              'is exactly what threw "Cannot use ref after the widget was '
              'disposed" in production');
      // No ref.read(organizationRepositoryProvider) should remain anywhere
      // after signUp — every use must go through the captured `repo`.
      final afterSignUp = src.substring(signUpIndex);
      expect(afterSignUp.contains('ref.read(organizationRepositoryProvider)'),
          isFalse);
    });
  });

  group('B — Registration, Multiple Branches ON', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/auth/presentation/screens/store_setup_screen.dart',
      ).readAsStringSync();
    });

    test('store name comes from the Branch Setup form field', () {
      expect(src.contains("'name': _nameController.text.trim()"), isTrue);
      expect(src.contains("'name': 'Main Store'"), isFalse);
    });

    test('financial-session creation is not swallowed', () {
      final callIndex = src.indexOf('await repo.createFinancialSession(');
      expect(callIndex, greaterThan(-1));
      final orgInsertIndex = src.indexOf(".from('omtbl_organizations')");
      expect(orgInsertIndex, greaterThan(-1));
      expect(callIndex, greaterThan(orgInsertIndex));
      final between = src.substring(orgInsertIndex, callIndex);
      expect(between.contains('catch ('), isFalse,
          reason: 'financial-session creation must not be shielded by its '
              'own swallowing try/catch between the organization insert and '
              'the session call');
    });

    test('the repository is captured before signUp, not read again later '
        '(the ref-disposal fix)', () {
      final repoCaptureIndex = src.indexOf(
          'final repo = ref.read(organizationRepositoryProvider);');
      final signUpIndex = src.indexOf('.auth.signUp(');
      expect(repoCaptureIndex, greaterThan(-1));
      expect(signUpIndex, greaterThan(-1));
      expect(repoCaptureIndex, lessThan(signUpIndex));
      final afterSignUp = src.substring(signUpIndex);
      expect(afterSignUp.contains('ref.read(organizationRepositoryProvider)'),
          isFalse);
    });
  });

  group('K/L/M/N — Store-wise internal user access', () {
    test('Workspace no longer bypasses the access-aware store loader', () {
      final src = File(
        'lib/features/organization/presentation/screens/workspace_selection_screen.dart',
      ).readAsStringSync();

      expect(
        src.contains('ref.read(organizationProvider.notifier)') &&
            src.contains('.loadStores('),
        isTrue,
        reason: 'the Store dropdown must be populated through '
            'OrganizationNotifier.loadStores, which enforces store-wise '
            'access, not a direct repository call that returns every store',
      );
    });

    test(
        'OrganizationNotifier resolves access from the existing store-access '
        'tables, not only the single store_id column', () {
      final src = File(
        'lib/features/organization/presentation/providers/organization_provider.dart',
      ).readAsStringSync();

      expect(src.contains("from('omtbl_user_store_access')"), isTrue);
      expect(src.contains("from('omtbl_role_store_access')"), isTrue);
    });

    test('an access-table read failure is caught per-source, not left to '
        'fall through to "show every store"', () {
      final src = File(
        'lib/features/organization/presentation/providers/organization_provider.dart',
      ).readAsStringSync();

      final helperStart = src.indexOf('Future<Set<int>> _resolveAllowedStoreIds(');
      expect(helperStart, greaterThan(-1));
      final helperBody = src.substring(helperStart);
      final catchCount = RegExp(r'catch \(e\)').allMatches(helperBody).length;
      expect(catchCount, greaterThanOrEqualTo(2),
          reason: 'each access-table lookup (user + role) must fail closed '
              'independently');
    });
  });
}
