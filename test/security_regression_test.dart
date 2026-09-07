// test/security_regression_test.dart
//
// Regression tests for the P0/P1 security and data-integrity fixes.
// Each group names the audit finding it guards.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/utils/password_hasher.dart';
import 'package:ordermate/features/business_partners/data/models/business_partner_model.dart';
import 'package:ordermate/features/products/data/models/product_model.dart';
import 'package:ordermate/features/vendors/data/models/vendor_model.dart';

void main() {
  group('C-0 / C-0b — no authentication backdoor, no fabricated identity', () {
    test('login screen contains no test-credential bypass', () {
      final src = File('lib/features/auth/presentation/screens/login_screen.dart')
          .readAsStringSync();
      expect(src.contains('test@test.com'), isFalse,
          reason: 'hardcoded test credentials must not exist');
      expect(src.contains('TEST BYPASS'), isFalse);
      expect(src.contains("'id': 999"), isFalse,
          reason: 'fake organization/store injection must not exist');
    });

    test('no fabricated test-user-id anywhere in lib/', () {
      final offenders = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.readAsStringSync().contains('test-user-id')) {
          offenders.add(e.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'currentUserId must never return a fabricated identity');
    });
  });

  group('C-1 — no embedded production credentials', () {
    test('supabase_client.dart holds no hardcoded URL or JWT', () {
      final src =
          File('lib/core/network/supabase_client.dart').readAsStringSync();
      expect(RegExp(r"'eyJ[A-Za-z0-9_\-\.]{20,}'").hasMatch(src), isFalse,
          reason: 'anon key must not be embedded');
      expect(src.contains('.supabase.co'), isFalse,
          reason: 'project URL must not be embedded');
      expect(src.contains('SupabaseConfigException'), isTrue,
          reason: 'missing config must fail loudly');
    });

    test('no JWT literal anywhere in lib/', () {
      final offenders = <String>[];
      final jwt = RegExp(r"'eyJ[A-Za-z0-9_\-\.]{20,}'");
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (jwt.hasMatch(e.readAsStringSync())) offenders.add(e.path);
      }
      expect(offenders, isEmpty);
    });
  });

  group('C-3 — no plaintext password storage or transmission', () {
    test('hash round-trips and rejects the wrong password', () {
      final h = PasswordHasher.hash('correct-horse');
      expect(PasswordHasher.verify('correct-horse', h), isTrue);
      expect(PasswordHasher.verify('wrong', h), isFalse);
    });

    test('hash is salted — same input yields different digests', () {
      expect(PasswordHasher.hash('same'), isNot(PasswordHasher.hash('same')));
    });

    test('stored value never contains the plaintext', () {
      final h = PasswordHasher.hash('SuperSecret123');
      expect(h.contains('SuperSecret123'), isFalse);
      expect(PasswordHasher.isHashed(h), isTrue);
    });

    test('verify fails closed on null, empty and malformed input', () {
      expect(PasswordHasher.verify('x', null), isFalse);
      expect(PasswordHasher.verify('x', ''), isFalse);
      expect(PasswordHasher.verify('x', 'not-a-hash'), isFalse);
      expect(PasswordHasher.verify('x', r'pbkdf2_sha256$abc$def$ghi'), isFalse);
      expect(PasswordHasher.isHashed('plaintext'), isFalse);
    });

    test('BusinessPartnerModel.toJson does not transmit a password', () {
      final m = BusinessPartnerModel(
        id: 'bp-1',
        name: 'Test Partner',
        phone: '123',
        address: 'addr',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        organizationId: 1,
        storeId: 1,
        isCustomer: true,
        password: 'should-never-be-sent',
      );
      expect(m.toJson().containsKey('password'), isFalse);
      expect(m.toJson().values.contains('should-never-be-sent'), isFalse);
    });

    test('login screen no longer compares passwords in SQL', () {
      final src = File('lib/features/auth/presentation/screens/login_screen.dart')
          .readAsStringSync();
      expect(src.contains("email = ? AND password = ?"), isFalse);
      expect(src.contains('PasswordHasher.verify'), isTrue);
    });
  });

  group('C-4 — sync failure is reported as failure', () {
    test('a run with recorded errors is never labelled Sync Complete', () {
      final n = SyncProgressNotifier();
      n.beginRun();
      n.setSyncing(true, message: 'Starting Sync...');
      n.recordError('Syncing Orders', 'network down');
      n.finishRun(aborted: false);

      expect(n.state.message, isNot('Sync Complete'));
      expect(n.state.outcome, SyncOutcome.partial);
      expect(n.state.hasFailed, isTrue);
      expect(n.state.isSyncing, isFalse);
    });

    test('an aborted run reports failed', () {
      final n = SyncProgressNotifier();
      n.beginRun();
      n.recordError('Sync', 'boom');
      n.finishRun(aborted: true);

      expect(n.state.outcome, SyncOutcome.failed);
      expect(n.state.message, 'Sync failed');
      expect(n.state.hasFailed, isTrue);
    });

    test('a clean run still reports success', () {
      final n = SyncProgressNotifier();
      n.beginRun();
      n.finishRun(aborted: false);

      expect(n.state.outcome, SyncOutcome.success);
      expect(n.state.message, 'Sync Complete');
      expect(n.state.hasFailed, isFalse);
    });

    test('errors from a previous run do not leak into the next', () {
      final n = SyncProgressNotifier();
      n.beginRun();
      n.recordError('step', 'err');
      n.finishRun(aborted: false);
      expect(n.state.hasFailed, isTrue);

      n.beginRun();
      n.finishRun(aborted: false);
      expect(n.state.outcome, SyncOutcome.success);
      expect(n.state.errors, isEmpty);
    });
  });

  group('C-6 — retry must not duplicate child records', () {
    // These read source rather than execute network calls, so they are written
    // to be whitespace-insensitive: `dart format` must not be able to break
    // them. We collapse all whitespace before matching.
    String flat(String path) =>
        File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    test('order items are cleared before re-insert', () {
      final src =
          flat('lib/features/orders/data/repositories/order_repository_impl.dart');
      final deleteIdx = src.indexOf("from('omtbl_order_items') .delete()");
      final insertIdx = src.indexOf("from('omtbl_order_items') .insert(");
      expect(deleteIdx, greaterThan(-1),
          reason: 'line items must be cleared before re-insert');
      expect(insertIdx, greaterThan(deleteIdx),
          reason: 'delete must happen before insert');
    });

    test('stock transfer items never use a plain insert', () {
      final src = flat(
          'lib/features/inventory/data/repositories/stock_transfer_repository_impl.dart');
      expect(src.contains("from('omtbl_stock_transfer_items') .insert("), isFalse,
          reason: 'plain insert allows duplicates on retry');
    });

    test('product create supplies a client id and upserts', () {
      final src = flat(
          'lib/features/products/data/repositories/product_repository_impl.dart');

      // Scope to createProduct. updateProduct legitimately strips the id
      // because it targets the row with .eq('id', ...) instead.
      final createStart = src.indexOf('Future<Product> createProduct');
      final createEnd = src.indexOf('Future<Product> updateProduct');
      expect(createStart, greaterThan(-1));
      expect(createEnd, greaterThan(createStart));
      final createBody = src.substring(createStart, createEnd);

      expect(createBody.contains("json.remove('id')"), isFalse,
          reason: 'stripping the PK makes the create non-idempotent');
      expect(createBody.contains('const Uuid().v4()'), isTrue,
          reason: 'create must supply a client-generated primary key');
      expect(src.contains("from('omtbl_products') .upsert(json)"), isTrue);
    });
  });

  group('H-6 — is_active serialises consistently', () {
    test('vendor and partner models agree on the runtime type', () {
      final vendor = VendorModel(
        id: 'v-1',
        name: 'Vendor',
        isActive: true,
        organizationId: 1,
        storeId: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ).toJson();

      final partner = BusinessPartnerModel(
        id: 'bp-1',
        name: 'Partner',
        phone: '1',
        address: 'a',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        organizationId: 1,
        storeId: 1,
        isVendor: true,
      ).toJson();

      expect(vendor['is_active'], isA<bool>());
      expect(vendor['is_active'].runtimeType, partner['is_active'].runtimeType,
          reason: 'both write omtbl_businesspartners.is_active');
    });
  });

  group('H-7 — product JSON uses canonical column names only', () {
    ProductModel model() => ProductModel(
          id: 'p-1',
          name: 'Widget',
          sku: 'SKU-1',
          rate: 10,
          storeId: 1,
          organizationId: 1,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          limitPrice: 5,
          cogsGlId: 'cogs-uuid',
          revenueGlId: 'rev-uuid',
        );

    test('typo columns are no longer emitted', () {
      final j = model().toJson();
      expect(j.containsKey('limtprice'), isFalse);
      expect(j.containsKey('cogs_id'), isFalse);
      expect(j.containsKey('revnue_id'), isFalse);
    });

    test('canonical columns survive', () {
      final j = model().toJson();
      expect(j['limit_price'], 5);
      expect(j['cogs_gl_id'], 'cogs-uuid');
      expect(j['revenue_gl_id'], 'rev-uuid');
    });

    test('round-trips from canonical columns alone', () {
      final j = model().toJson();
      j['created_at'] = DateTime(2026, 1, 1).toIso8601String();
      final back = ProductModel.fromJson(j);
      expect(back.limitPrice, 5);
      expect(back.cogsGlId, 'cogs-uuid');
      expect(back.revenueGlId, 'rev-uuid');
    });
  });

  group('H-4 / H-5 — CSV BOM and encoding', () {
    final svc = CsvService();

    test('UTF-8 BOM is stripped so the header is detected', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('Name,SKU\nWidget,W1')];
      final rows = svc.parseCsv(svc.decodeCsvBytes(bytes));
      expect(rows.first.first.toString().toLowerCase(), 'name',
          reason: 'BOM must not defeat the header sniff');
    });

    test('parseCsv also strips an already-decoded BOM', () {
      final rows = svc.parseCsv('﻿Name,SKU\nWidget,W1');
      expect(rows.first.first.toString().toLowerCase(), 'name');
    });

    test('Windows-1252 bytes do not abort the import', () {
      // 0xE9 is 'é' in Windows-1252 and invalid standalone UTF-8.
      final bytes = <int>[...utf8.encode('Name\nJos'), 0xE9];
      expect(() => svc.decodeCsvBytes(bytes), returnsNormally);
      final rows = svc.parseCsv(svc.decodeCsvBytes(bytes));
      expect(rows.length, 2);
    });

    test('well-formed UTF-8 is unaffected', () {
      final rows =
          svc.parseCsv(svc.decodeCsvBytes(utf8.encode('Name,SKU\nZürich,Z1')));
      expect(rows[1][0], 'Zürich');
    });
  });

  group('H-3 — subscription checks fail closed', () {
    test('typed limit exception exists and plan check is unchanged', () {
      final src =
          File('lib/core/services/subscription_service.dart').readAsStringSync();
      expect(src.contains('class SubscriptionLimitException'), isTrue);
      expect(src.contains("plan == 'paid'"), isTrue,
          reason: 'the app uses free/paid — do not change this comparison');
      expect(src.contains('Could not verify your plan limits'), isTrue,
          reason: 'unexpected errors must not silently allow the action');
    });
  });

  group('H-10 — edit screens handle a missing record', () {
    const screens = [
      'lib/features/accounting/presentation/screens/account_type_form_screen.dart',
      'lib/features/accounting/presentation/screens/account_category_form_screen.dart',
      'lib/features/accounting/presentation/screens/financial_session_form_screen.dart',
    ];

    test('no unguarded firstWhere remains in the affected screens', () {
      for (final path in [
        ...screens,
        'lib/features/accounting/presentation/screens/chart_of_account_form_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('.firstWhere('), isFalse,
            reason: '$path still uses firstWhere without orElse');
      }
    });

    test('each edit screen renders a not-found state', () {
      for (final path in screens) {
        final src = File(path).readAsStringSync();
        expect(src.contains('_recordMissing'), isTrue, reason: path);
        expect(src.contains('if (_recordMissing) {'), isTrue, reason: path);
      }
    });
  });

  group('N-6 — v77 preserves local financial sessions', () {
    test('migration no longer drops the table', () {
      final src =
          File('lib/core/database/database_helper.dart').readAsStringSync();
      expect(src.contains("DROP TABLE IF EXISTS local_financial_sessions"),
          isFalse,
          reason: 'v77 must not destroy unsynced financial sessions');
      expect(
          src.contains(
              'ALTER TABLE local_financial_sessions RENAME TO local_financial_sessions_old'),
          isTrue,
          reason: 'rows must be copied across the PK change');
    });

    test('schema version was bumped for the password migration', () {
      final src =
          File('lib/core/database/database_helper.dart').readAsStringSync();
      expect(src.contains('_databaseVersion = 78'), isTrue);
      expect(src.contains('password_hash'), isTrue);
    });
  });
}
