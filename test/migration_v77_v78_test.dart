// test/migration_v77_v78_test.dart
//
// N-6: v77 previously executed `DROP TABLE IF EXISTS local_financial_sessions`,
// destroying every locally-created financial session — including unsynced ones —
// on upgrade. C-3: v78 converts cached plaintext passwords to salted hashes.
//
// These tests build a pre-upgrade database by hand, run the real migration, and
// assert the data survived.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/utils/password_hasher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tmp;
  var dbSeq = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('ordermate_migration_test_');
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Creates a DB shaped like a pre-v77 install, closes it, then reopens it at
  /// the current version so `_onUpgrade` runs against the seeded data for real.
  ///
  /// This MUST use a real file. `inMemoryDatabasePath` (`:memory:`) is destroyed
  /// on close, so the reopen would get an empty database and every one of these
  /// tests would silently assert against a migration that never saw the seed.
  Future<Database> upgradeFrom(
    int oldVersion,
    Future<void> Function(Database db) seed,
  ) async {
    final path = '${tmp.path}${Platform.pathSeparator}m${dbSeq++}.db';
    final f = File(path);
    if (f.existsSync()) f.deleteSync();

    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: oldVersion),
    );
    await seed(legacy);
    await legacy.close();

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 78,
        onUpgrade: (db, from, to) =>
            DatabaseHelper.instance.runMigrationsForTest(db, from, to),
      ),
    );
  }

  group('N-6 — v77 preserves local_financial_sessions', () {
    test('existing rows survive the primary-key change', () async {
      final db = await upgradeFrom(76, (legacy) async {
        // Pre-v77 shape: syear was the sole primary key.
        await legacy.execute('''
          CREATE TABLE local_financial_sessions (
            syear INTEGER PRIMARY KEY,
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            narration TEXT,
            in_use INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1,
            is_closed INTEGER DEFAULT 0
          )
        ''');
        await legacy.insert('local_financial_sessions', {
          'syear': 2025,
          'start_date': 1735689600000,
          'end_date': 1767225600000,
          'narration': 'FY2025 — created offline, never synced',
          'in_use': 1,
          'is_active': 1,
          'organization_id': 1,
          'is_synced': 0, // the row we must not lose
          'is_closed': 0,
        });
      });

      final rows = await db.query('local_financial_sessions');
      expect(rows.length, 1,
          reason: 'the unsynced financial session must survive the upgrade');
      expect(rows.first['syear'], 2025);
      expect(rows.first['narration'], 'FY2025 — created offline, never synced');
      expect(rows.first['is_synced'], 0,
          reason: 'unsynced flag must be preserved so the row still pushes');

      // The new surrogate key and uniqueness must both be in place.
      expect(rows.first.containsKey('id'), isTrue);
      final idx = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_fin_session_org_year'");
      expect(idx.isNotEmpty, isTrue);

      await db.close();
    });

    test('two sessions for different orgs in the same year both survive',
        () async {
      final db = await upgradeFrom(76, (legacy) async {
        await legacy.execute('''
          CREATE TABLE local_financial_sessions (
            syear INTEGER PRIMARY KEY,
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            narration TEXT,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await legacy.insert('local_financial_sessions', {
          'syear': 2026,
          'start_date': 1,
          'end_date': 2,
          'organization_id': 1,
          'is_synced': 0,
        });
      });

      final rows = await db.query('local_financial_sessions');
      expect(rows.length, 1);
      // The old schema could only hold one row per year across all orgs;
      // after the migration a second org can be added.
      await db.insert('local_financial_sessions', {
        'syear': 2026,
        'start_date': 1,
        'end_date': 2,
        'organization_id': 2,
        'is_synced': 0,
      });
      expect((await db.query('local_financial_sessions')).length, 2);
      await db.close();
    });

    test('upgrade succeeds when the table did not exist yet', () async {
      final db = await upgradeFrom(76, (_) async {});
      final t = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='local_financial_sessions'");
      expect(t.isNotEmpty, isTrue);
      await db.close();
    });
  });

  group('C-3 — v78 converts cached plaintext passwords to hashes', () {
    test('legacy plaintext is hashed and then blanked', () async {
      const plaintext = 'legacy-password';

      final db = await upgradeFrom(77, (legacy) async {
        await legacy.execute('''
          CREATE TABLE local_users (
            email TEXT PRIMARY KEY,
            id TEXT NOT NULL,
            password TEXT,
            full_name TEXT
          )
        ''');
        await legacy.insert('local_users', {
          'email': 'rep@example.com',
          'id': 'auth-uuid-1',
          'password': plaintext,
          'full_name': 'Field Rep',
        });
      });

      final rows = await db.query('local_users');
      expect(rows.length, 1);
      final row = rows.first;

      expect(row['password'], isNull,
          reason: 'plaintext must be cleared by the migration');
      expect(row.values.contains(plaintext), isFalse);

      final hash = row['password_hash'] as String?;
      expect(PasswordHasher.isHashed(hash), isTrue);
      expect(PasswordHasher.verify(plaintext, hash), isTrue,
          reason: 'offline login must keep working after the upgrade');
      expect(PasswordHasher.verify('wrong', hash), isFalse);

      await db.close();
    });
  });
}
