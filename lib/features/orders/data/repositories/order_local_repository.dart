import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ordermate/features/orders/domain/entities/order_item.dart';
import 'dart:convert';

class OrderLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cacheOrders(List<Order> orders) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Get list of unsynced orders to protect local changes
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_orders',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<String> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as String).toSet();

    for (final order in orders) {
      // Skip overwriting if local copy is dirty
      if (unsyncedIds.contains(order.id)) {
        continue;
      }

      batch.insert(
        'local_orders',
        {
          'id': order.id,
          'customer_id': order.businessPartnerId,
          'total_amount': order.totalAmount,
          'status': order.status.name,
          'order_date': order.orderDate.millisecondsSinceEpoch,
          'is_synced': 1,
          'items_payload': '{}',
          'order_number': order.orderNumber,
          'business_partner_name': order.businessPartnerName ?? '',
          'created_by': order.createdBy,
          'store_id': order.storeId,
          'organization_id': order.organizationId,
          'order_type': order.orderType,
          'payment_term_id': order.paymentTermId,
          'dispatch_status': order.dispatchStatus,
          'dispatch_date': order.dispatchDate?.millisecondsSinceEpoch,
          'is_invoiced': order.isInvoiced ? 1 : 0,
          'syear': order.sYear,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): `organizationId` is `required` (though still
  /// nullable) so every caller must explicitly state its tenant context.
  /// If none is available, this returns an empty list rather than
  /// removing the organization predicate.
  Future<List<Order>> getLocalOrders(
      {required int? organizationId, int? storeId, int? sYear}) async {
    if (organizationId == null) {
      return [];
    }

    final db = await _dbHelper.database;
    final List<String> conditions = ['organization_id = ?'];
    final List<dynamic> args = [organizationId];

    if (storeId != null) {
      conditions.add('store_id = ?');
      args.add(storeId);
    }
    if (sYear != null) {
      conditions.add('syear = ?');
      args.add(sYear);
    }

    final whereClause = conditions.join(' AND ');

    final maps = await db.query(
      'local_orders',
      where: whereClause,
      whereArgs: args,
      orderBy: 'order_date DESC',
    );

    return maps.map((map) {
      final statusString = map['status'] as String;
      final status = OrderStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => OrderStatus.pending,
      );

      List<OrderItem> items = [];
      if (map['items_payload'] != null) {
        try {
          final payload = map['items_payload'] as String;
          if (payload.isNotEmpty && payload != '{}') {
            final List<dynamic> list = jsonDecode(payload);
            items = list.map((e) => OrderItem.fromJson(e)).toList();
          }
        } catch (_) {}
      }

      return Order(
        id: map['id'] as String,
        orderNumber: map['order_number'] as String? ?? 'OFFLINE',
        businessPartnerId: map['customer_id'] as String,
        orderType: map['order_type'] as String? ?? 'SO',
        createdBy: map['created_by'] as String? ?? '',
        status: status,
        totalAmount: (map['total_amount'] as num).toDouble(),
        orderDate:
            DateTime.fromMillisecondsSinceEpoch(map['order_date'] as int),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        businessPartnerName:
            map['business_partner_name'] as String? ?? 'Offline Partner',
        storeId: (map['store_id'] as int?) ?? 0,
        organizationId: (map['organization_id'] as int?) ?? 0,
        paymentTermId: map['payment_term_id'] as int?,
        dispatchStatus: map['dispatch_status'] as String? ?? 'pending',
        dispatchDate: map['dispatch_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dispatch_date'] as int)
            : null,
        isInvoiced: map['is_invoiced'] == 1,
        sYear: map['syear'] as int?,
        items: items,
      );
    }).toList();
  }

  Future<List<Order>> getUnsyncedOrders(
      {int? organizationId, int? storeId, int? sYear}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['is_synced = 0'];
    final List<dynamic> args = [];

    if (organizationId != null) {
      conditions.add('organization_id = ?');
      args.add(organizationId);
    }
    if (storeId != null) {
      conditions.add('store_id = ?');
      args.add(storeId);
    }
    if (sYear != null) {
      conditions.add('syear = ?');
      args.add(sYear);
    }

    final maps = await db.query(
      'local_orders',
      where: conditions.join(' AND '),
      whereArgs: args,
    );

    return maps.map((map) {
      final statusString = map['status'] as String;
      final status = OrderStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => OrderStatus.pending,
      );

      List<OrderItem> items = [];
      if (map['items_payload'] != null) {
        try {
          final payload = map['items_payload'] as String;
          if (payload.isNotEmpty && payload != '{}') {
            final List<dynamic> list = jsonDecode(payload);
            items = list.map((e) => OrderItem.fromJson(e)).toList();
          }
        } catch (_) {}
      }

      return Order(
        id: map['id'] as String,
        orderNumber: map['order_number'] as String? ?? 'OFFLINE',
        businessPartnerId: map['customer_id'] as String,
        orderType: map['order_type'] as String? ?? 'SO',
        createdBy: map['created_by'] as String? ?? '',
        status: status,
        totalAmount: (map['total_amount'] as num).toDouble(),
        orderDate:
            DateTime.fromMillisecondsSinceEpoch(map['order_date'] as int),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        businessPartnerName:
            map['business_partner_name'] as String? ?? 'Offline Partner',
        storeId: (map['store_id'] as int?) ?? 0,
        organizationId: (map['organization_id'] as int?) ?? 0,
        paymentTermId: map['payment_term_id'] as int?,
        dispatchStatus: map['dispatch_status'] as String? ?? 'pending',
        dispatchDate: map['dispatch_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dispatch_date'] as int)
            : null,
        isInvoiced: map['is_invoiced'] == 1,
        sYear: map['syear'] as int?,
        items: items,
      );
    }).toList();
  }

  Future<void> markOrderAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // CRUD Operations

  Future<List<Map<String, dynamic>>> getLocalOrderItems(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'local_orders',
      columns: ['items_payload'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty && result.first['items_payload'] != null) {
      final payload = result.first['items_payload'] as String;
      if (payload.isNotEmpty && payload != '{}') {
        try {
          return List<Map<String, dynamic>>.from(jsonDecode(payload));
        } catch (e) {
          return [];
        }
      }
    }
    return [];
  }

  // CRUD Operations
  Future<void> addOrder(Order order,
      {List<Map<String, dynamic>>? items}) async {
    final db = await _dbHelper.database;
    final itemsPayload = items != null ? jsonEncode(items) : '{}';

    await db.insert(
      'local_orders',
      {
        'id': order.id,
        'customer_id': order.businessPartnerId,
        'total_amount': order.totalAmount,
        'status': order.status.name,
        'order_date': order.orderDate.millisecondsSinceEpoch,
        'is_synced': 0, // Pending Sync
        'items_payload': itemsPayload,
        'order_number': order.orderNumber,
        'business_partner_name': order.businessPartnerName ?? '',
        'created_by': order.createdBy,
        'store_id': order.storeId,
        'organization_id': order.organizationId,
        'order_type': order.orderType,
        'payment_term_id': order.paymentTermId,
        'dispatch_status': order.dispatchStatus,
        'dispatch_date': order.dispatchDate?.millisecondsSinceEpoch,
        'is_invoiced': order.isInvoiced ? 1 : 0,
        'syear': order.sYear,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateOrder(Order order,
      {List<Map<String, dynamic>>? items}) async {
    final db = await _dbHelper.database;

    final Map<String, dynamic> data = {
      'customer_id': order.businessPartnerId,
      'total_amount': order.totalAmount,
      'status': order.status.name,
      'order_date': order.orderDate.millisecondsSinceEpoch,
      'is_synced': 0, // Reset sync status on update
      'order_number': order.orderNumber,
      'business_partner_name': order.businessPartnerName ?? '',
      'store_id': order.storeId,
      'organization_id': order.organizationId,
      'order_type': order.orderType,
      'payment_term_id': order.paymentTermId,
      'dispatch_status': order.dispatchStatus,
      'dispatch_date': order.dispatchDate?.millisecondsSinceEpoch,
      'is_invoiced': order.isInvoiced ? 1 : 0,
      'syear': order.sYear,
    };

    if (items != null) {
      data['items_payload'] = jsonEncode(items);
    }

    await db.update(
      'local_orders',
      data,
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> saveLocalOrderItems(
      String orderId, List<Map<String, dynamic>> items,
      {bool? isSynced}) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> data = {
      'items_payload': jsonEncode(items),
    };

    if (isSynced != null) {
      data['is_synced'] = isSynced ? 1 : 0;
    } else {
      data['is_synced'] = 0; // Default to marked as modified
    }

    await db.update(
      'local_orders',
      data,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<bool> isOrderUnsynced(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'local_orders',
      columns: ['is_synced'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return (result.first['is_synced'] as int) == 0;
    }
    return false; // precise fallback if not found? Assume synced or not present.
  }

  Future<void> deleteOrder(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Record the deletion for sync
      await txn.insert('local_deleted_records', {
        'entity_table': 'local_orders',
        'entity_id': id,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Perform the local delete
      await txn.delete(
        'local_orders',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> updateDispatchInfo(
      String orderId, String status, DateTime date) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_orders',
      {
        'dispatch_status': status,
        'dispatch_date': date.millisecondsSinceEpoch,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateOrderInvoiced(String orderId, bool isInvoiced) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_orders',
      {
        'is_invoiced': isInvoiced ? 1 : 0,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
