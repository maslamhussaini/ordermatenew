// ignore_for_file: avoid_print
//
// CONTROLLED VERIFICATION TEST (audit / test infrastructure only).
//
// Scope: LOCAL DATA LAYER ONLY. This drives the real
// `OrderLocalRepository` against the real `DatabaseHelper.instance`
// singleton via sqflite_common_ffi. It performs NO Supabase / network
// calls, so it verifies local persistence, unsynced-queue selection,
// the mark-as-synced state transition and org isolation.
// It does NOT verify server-side round-trip, server-side duplicate
// prevention, or real network retry behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

const int kOrgA = 96001;
const int kOrgB = 96002;
const String kCustomerA = 'cust-96001-aaaa';
const String kProductA = 'prod-96001-aaaa';
const String kSalesman = 'user-96001-salesman';

/// Mirrors exactly what `create_order_screen.dart::_submit` builds
/// (OrderModel -> Order entity) before handing it to
/// `orderProvider.createOrderWithItems`, which on the offline path calls
/// `OrderLocalRepository.addOrder(order, items: items)`.
Order buildBooking({
  required String id,
  required int orgId,
  required String customerId,
  required double total,
  String orderNumber = 'SO-96001-001',
}) {
  final now = DateTime(2026, 9, 3, 10, 30);
  return Order(
    id: id,
    orderNumber: orderNumber,
    businessPartnerId: customerId,
    businessPartnerName: 'Audit Customer $orgId',
    orderType: 'SO',
    createdBy: kSalesman,
    status: OrderStatus.booked,
    totalAmount: total,
    orderDate: now,
    createdAt: now,
    updatedAt: now,
    organizationId: orgId,
    storeId: 1,
    paymentTermId: 7,
    sYear: 2026,
  );
}

/// Mirrors the line-item map shape built in
/// `create_order_screen.dart` (_orderItems entries) and passed through
/// `createOrderWithItems`.
List<Map<String, dynamic>> buildItems({
  required String orderId,
  required String productId,
  required double qty,
  required double rate,
}) {
  return [
    {
      'order_id': orderId,
      'product_id': productId,
      'quantity': qty,
      'rate': rate,
      'total': qty * rate,
      'discount_percent': 0.0,
      'uom_id': 1,
      'base_quantity': 1.0,
    }
  ];
}

void main() {
  late OrderLocalRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    repo = OrderLocalRepository();

    // Clean slate for our dedicated org id range only.
    final db = await DatabaseHelper.instance.database;
    await db.delete('local_orders',
        where: 'organization_id IN (?, ?)', whereArgs: [kOrgA, kOrgB]);
  });

  tearDownAll(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('local_orders',
        where: 'organization_id IN (?, ?)', whereArgs: [kOrgA, kOrgB]);
  });

  group('Offline booking -> local persistence -> sync-queue state machine',
      () {
    final orderId = const Uuid().v4();
    const qty = 3.0;
    const rate = 250.0;
    const total = qty * rate;

    test('STEP 1+2+3: offline booking persists with all fields, is_synced=0',
        () async {
      final order = buildBooking(
        id: orderId,
        orgId: kOrgA,
        customerId: kCustomerA,
        total: total,
      );
      final items =
          buildItems(orderId: orderId, productId: kProductA, qty: qty, rate: rate);

      // Real offline write path used by createOrderWithItems' network-error
      // fallback in order_provider.dart.
      await repo.addOrder(order, items: items);

      final local = await repo.getLocalOrders(organizationId: kOrgA);
      print('STEP 2: getLocalOrders(96001) -> ${local.length} row(s)');
      final found = local.firstWhere((o) => o.id == orderId);

      // is_synced flag (raw column check)
      final db = await DatabaseHelper.instance.database;
      final raw = await db.query('local_orders',
          columns: ['is_synced', 'created_by', 'organization_id', 'customer_id'],
          where: 'id = ?',
          whereArgs: [orderId]);
      print('STEP 2: raw row -> ${raw.first}');
      expect(raw.first['is_synced'], 0, reason: 'must be queued for sync');

      // STEP 3: field fidelity
      expect(found.organizationId, kOrgA);
      expect(found.businessPartnerId, kCustomerA);
      expect(found.createdBy, kSalesman);
      expect(found.storeId, 1);
      expect(found.sYear, 2026);
      expect(found.orderType, 'SO');
      expect(found.status, OrderStatus.booked);
      expect(found.totalAmount, total);
      expect(found.paymentTermId, 7);

      final storedItems = await repo.getLocalOrderItems(orderId);
      print('STEP 3: line items -> $storedItems');
      expect(storedItems.length, 1);
      expect(storedItems.first['product_id'], kProductA);
      expect(storedItems.first['quantity'], qty);
      expect(storedItems.first['rate'], rate);
      expect(storedItems.first['total'], total);
      expect(
        storedItems.fold<double>(0, (s, i) => s + (i['total'] as num)),
        found.totalAmount,
        reason: 'header total must equal sum of line totals',
      );
    });

    test('STEP 4: order appears in getUnsyncedOrders (the sync push queue)',
        () async {
      final unsynced = await repo.getUnsyncedOrders(organizationId: kOrgA);
      print('STEP 4: getUnsyncedOrders(96001) -> '
          '${unsynced.map((o) => o.id).toList()}');
      expect(unsynced.any((o) => o.id == orderId), isTrue);
      // Items must survive into the push payload too.
      final pushed = unsynced.firstWhere((o) => o.id == orderId);
      expect(pushed.organizationId, kOrgA);
      expect(pushed.createdBy, kSalesman);
    });

    test('STEP 5: markOrderAsSynced removes it from the queue (no server call)',
        () async {
      await repo.markOrderAsSynced(orderId);

      final unsynced = await repo.getUnsyncedOrders(organizationId: kOrgA);
      print('STEP 5: after markOrderAsSynced -> '
          '${unsynced.map((o) => o.id).toList()}');
      expect(unsynced.any((o) => o.id == orderId), isFalse);

      // Still readable as a normal local order.
      final local = await repo.getLocalOrders(organizationId: kOrgA);
      expect(local.any((o) => o.id == orderId), isTrue);
      expect(await repo.isOrderUnsynced(orderId), isFalse);
    });
  });

  group('STEP 6: double-submission (double-tap) behaviour', () {
    test('same logical order submitted twice with two client UUIDs -> 2 rows',
        () async {
      // A real double-tap re-enters _submit(), and `const Uuid().v4()` is
      // called again per invocation -> a DIFFERENT id each time.
      final id1 = const Uuid().v4();
      final id2 = const Uuid().v4();

      for (final id in [id1, id2]) {
        await repo.addOrder(
          buildBooking(
            id: id,
            orgId: kOrgA,
            customerId: kCustomerA,
            total: 500.0,
            orderNumber: 'SO-96001-DUP',
          ),
          items: buildItems(
              orderId: id, productId: kProductA, qty: 2.0, rate: 250.0),
        );
      }

      final dupes = (await repo.getUnsyncedOrders(organizationId: kOrgA))
          .where((o) => o.orderNumber == 'SO-96001-DUP')
          .toList();
      print('STEP 6a: distinct-UUID double submit -> ${dupes.length} unsynced '
          'row(s): ${dupes.map((o) => o.id).toList()}');
      expect(dupes.length, 2,
          reason: 'NO local de-duplication guard: both queue for push');
    });

    test('same client UUID replayed -> single row (ConflictAlgorithm.replace)',
        () async {
      final sameId = const Uuid().v4();
      for (var i = 0; i < 2; i++) {
        await repo.addOrder(
          buildBooking(
            id: sameId,
            orgId: kOrgA,
            customerId: kCustomerA,
            total: 900.0,
            orderNumber: 'SO-96001-REPLAY',
          ),
          items: buildItems(
              orderId: sameId, productId: kProductA, qty: 3.0, rate: 300.0),
        );
      }
      final rows = (await repo.getLocalOrders(organizationId: kOrgA))
          .where((o) => o.orderNumber == 'SO-96001-REPLAY')
          .toList();
      print('STEP 6b: same-UUID replay -> ${rows.length} row(s)');
      expect(rows.length, 1,
          reason: 'PK + ConflictAlgorithm.replace collapses same-id retries');
    });
  });

  group('STEP 7: cross-organization isolation', () {
    test('org 96002 order never leaks into org 96001 reads', () async {
      final otherId = const Uuid().v4();
      await repo.addOrder(
        buildBooking(
          id: otherId,
          orgId: kOrgB,
          customerId: 'cust-96002-bbbb',
          total: 111.0,
          orderNumber: 'SO-96002-001',
        ),
        items: buildItems(
            orderId: otherId, productId: 'prod-96002', qty: 1.0, rate: 111.0),
      );

      final orgA = await repo.getLocalOrders(organizationId: kOrgA);
      final orgB = await repo.getLocalOrders(organizationId: kOrgB);
      print('STEP 7: org96001 rows=${orgA.length}, org96002 rows=${orgB.length}');

      expect(orgA.any((o) => o.id == otherId), isFalse);
      expect(orgA.every((o) => o.organizationId == kOrgA), isTrue);
      expect(orgB.any((o) => o.id == otherId), isTrue);

      final unsyncedA = await repo.getUnsyncedOrders(organizationId: kOrgA);
      expect(unsyncedA.any((o) => o.id == otherId), isFalse);
    });

    test('null organizationId returns empty (OFF-01 fail-closed)', () async {
      final none = await repo.getLocalOrders(organizationId: null);
      print('STEP 7b: getLocalOrders(null) -> ${none.length} row(s)');
      expect(none, isEmpty);
    });

    test('getUnsyncedOrders with NO org filter is NOT tenant-scoped',
        () async {
      // Contrast control: unlike getLocalOrders, getUnsyncedOrders has an
      // optional (not required) organizationId and does not fail closed.
      final all = await repo.getUnsyncedOrders();
      final orgs = all.map((o) => o.organizationId).toSet();
      print('STEP 7c: getUnsyncedOrders() unfiltered -> ${all.length} row(s) '
          'spanning orgs $orgs');
      expect(orgs.contains(kOrgB), isTrue);
    });
  });
}
