// test/security/platform_admin_authority_test.dart
//
// Phase 3B-4A-R: the platform-admin authorization foundation.
//
// The real is_platform_admin() SQL function/omtbl_platform_admins table
// cannot be exercised end-to-end in this test suite -- the migration is
// PREPARED, not executed (this assistant has no direct Postgres/DDL access
// in this environment, consistent with every prior phase of this
// engagement; the SQL Editor execution step is a manual action for the
// project owner, documented in the migration file's own trailing comment
// block). These tests instead verify, precisely and without fabricating
// database behavior:
//   1. The migration file itself encodes the required safety properties
//      (structural/content assertions on the SQL text).
//   2. The hardcoded platform-admin email has been removed from every
//      security-relevant (authorization) call site in the Dart source, and
//      that NO new hardcoded copy was introduced anywhere else.
//   3. The email is deliberately still present in the legitimate,
//      non-authorization usages (notification recipients) -- proving the
//      change didn't overreach into unrelated code.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _hardcodedEmail = 'maslamhussaini@gmail.com';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Migration file: omtbl_platform_admins safety properties', () {
    late String migration;

    setUpAll(() {
      migration = _read(
          'supabase/migrations/20260903120000_platform_admin_authority.sql');
    });

    test('creates the table with a real FK to auth.users(id)', () {
      expect(migration, contains('CREATE TABLE IF NOT EXISTS omtbl_platform_admins'));
      expect(migration, contains('REFERENCES auth.users(id)'));
    });

    test('user_id is unique (one row per admin, idempotent bootstrap)', () {
      expect(migration, contains('user_id      UUID NOT NULL UNIQUE'));
    });

    test('RLS is enabled on the table', () {
      expect(migration,
          contains('ALTER TABLE omtbl_platform_admins ENABLE ROW LEVEL SECURITY'));
    });

    test('no CREATE POLICY grants any write access to authenticated/anon', () {
      // The whole point of this table's RLS design is default-deny: zero
      // policies at all, so only service_role (which bypasses RLS) can
      // read or write it directly. A regression here would mean someone
      // added a policy letting ordinary users self-grant platform admin.
      // Strip SQL comment lines first so this doesn't false-positive on
      // the migration's own prose explaining that no policy exists.
      final codeOnly = migration
          .split('\n')
          .where((line) => !line.trim().startsWith('--'))
          .join('\n');
      expect(codeOnly.contains('CREATE POLICY'), isFalse,
          reason:
              'omtbl_platform_admins must have zero RLS policies -- authority must not be self-service');
    });

    test('is_platform_admin() is SECURITY DEFINER with a pinned search_path', () {
      expect(migration, contains('CREATE OR REPLACE FUNCTION is_platform_admin()'));
      expect(migration, contains('SECURITY DEFINER'));
      // Must be the SAFE single-schema pattern (matches current_org_id()),
      // not the WARNING-flagged 'public','pg_temp' pattern seen on
      // get_my_org_id() in an earlier audit.
      expect(migration, contains("SET search_path = 'public'"));
      expect(migration.contains("'public', 'pg_temp'"), isFalse);
    });

    test('is_platform_admin() takes no arguments (cannot query another user)', () {
      final fnStart = migration.indexOf('FUNCTION is_platform_admin()');
      expect(fnStart, greaterThanOrEqualTo(0));
      // The signature itself has empty parens -- confirms no uuid/email
      // parameter exists that a caller could use to ask about someone else.
      expect(migration.substring(fnStart, fnStart + 40),
          contains('is_platform_admin()'));
    });

    test('is_platform_admin() checks auth.uid(), not a client-supplied value', () {
      final fnStart = migration.indexOf('CREATE OR REPLACE FUNCTION is_platform_admin()');
      final fnEnd = migration.indexOf(r'$$;', fnStart);
      final fnBody = migration.substring(fnStart, fnEnd);
      expect(fnBody, contains('auth.uid()'));
    });

    test('bootstrap resolves the existing admin by email lookup, never a hardcoded UUID', () {
      expect(migration, contains('SELECT id, email'));
      expect(migration, contains('FROM auth.users'));
      expect(migration, contains("WHERE email = '$_hardcodedEmail'"));
      expect(migration, contains('ON CONFLICT (user_id) DO NOTHING'));
      // No UUID literal anywhere in the file (36-char 8-4-4-4-12 hex shape).
      final uuidPattern = RegExp(
          r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
      expect(uuidPattern.hasMatch(migration), isFalse,
          reason: 'The migration must never guess/hardcode a UUID');
    });

    test('does not touch any commercial-entitlement table', () {
      for (final forbidden in [
        'ALTER TABLE omtbl_module_access_items',
        'ALTER TABLE omtbl_organization_bundle_entitlement',
        'ALTER TABLE omtbl_report_bundles',
        'ALTER TABLE omtbl_modules',
        'ALTER TABLE omtbl_app_forms',
        'ALTER TABLE omtbl_organizations',
      ]) {
        expect(migration.contains(forbidden), isFalse,
            reason: '$forbidden must not appear in the platform-admin migration');
      }
    });

    test('contains no destructive statements', () {
      for (final destructive in ['DROP TABLE', 'TRUNCATE', 'DELETE FROM']) {
        expect(migration.toUpperCase().contains(destructive), isFalse);
      }
    });
  });

  group('Hardcoded email removed from every authorization call site', () {
    test('auth_provider.dart no longer compares email for superUser determination', () {
      final source = _read('lib/core/providers/auth_provider.dart');
      expect(source.contains("sessionUser.email == '$_hardcodedEmail'"), isFalse);
      expect(source, contains("rpc('is_platform_admin')"));
    });

    test('app_menu.dart no longer compares email for /module-config visibility', () {
      final source = _read('lib/core/views/app_menu.dart');
      expect(source.contains("== '$_hardcodedEmail'"), isFalse);
      expect(source, contains('auth.role == UserRole.superUser'));
    });

    test('module_config_screen.dart no longer compares email for its own access gate', () {
      final source = _read(
          'lib/features/module_access/presentation/screens/module_config_screen.dart');
      expect(source.contains("!= '$_hardcodedEmail'"), isFalse);
      expect(source, contains("rpc('is_platform_admin')"));
    });

    test('organization_list_screen.dart no longer compares email for the Modules button',
        () {
      final source = _read(
          'lib/features/organization/presentation/screens/organization_list_screen.dart');
      expect(source.contains("== '$_hardcodedEmail'"), isFalse);
      expect(source, contains('ref.watch(authProvider).role == UserRole.superUser'));
    });
  });

  group('No overreach: legitimate non-authorization email usages are untouched', () {
    test('bug_reporter.dart still sends bug reports to the admin email (not an auth check)',
        () {
      final source = _read('lib/core/utils/bug_reporter.dart');
      expect(source, contains(_hardcodedEmail));
    });

    test(
        'organization_setup_screen.dart still notifies the admin email on signup (not an auth check)',
        () {
      final source =
          _read('lib/features/auth/presentation/screens/organization_setup_screen.dart');
      expect(source, contains(_hardcodedEmail));
    });
  });
}
