import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/orders/data/models/order_model.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/domain/repositories/order_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderLocalRepository _localRepository = OrderLocalRepository();
  @override
  Future<List<Order>> getOrders(
      {int? organizationId, int? storeId, int? sYear}) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();

    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalOrders(
          organizationId: organizationId, storeId: storeId, sYear: sYear);
    }

    try {
      var query = SupabaseConfig.client.from('omtbl_orders').select(
          '*, omtbl_businesspartners(name), items:omtbl_order_items(*, product:omtbl_products(name), uom:omtbl_units_of_measure(unit_symbol))'); // Fetch items too

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      if (sYear != null) {
        query = query.eq('syear', sYear);
      }

      final response = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 3));

      final orders = (response as List).map((json) {
        // Map the nested object to the flat field expected by the model
        if (json['omtbl_businesspartners'] != null) {
          json['business_partner_name'] =
              json['omtbl_businesspartners']['name'];
        }

        // Flatten items if present (Same logic as in getOrdersByDateRange)
        if (json['items'] != null && json['items'] is List) {
          json['items'] = (json['items'] as List).map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            if (itemMap['product'] != null) {
              itemMap['product_name'] = itemMap['product']['name'];
            }
            if (itemMap['uom'] != null) {
              itemMap['uom_symbol'] = itemMap['uom']['unit_symbol'];
            }
            return itemMap;
          }).toList();
        }

        return OrderModel.fromJson(json);
      }).toList();

      // Cache (This marks them as synced in local repo via cacheOrders)
      await _localRepository.cacheOrders(orders);

      // Merge with Unsynced (Offline) Orders to ensure they are visible
      final unsynced = await _localRepository.getUnsyncedOrders(
          organizationId: organizationId, storeId: storeId, sYear: sYear);
      if (unsynced.isNotEmpty) {
        final Map<String, Order> mergedMap = {};
        for (final o in orders) {
          mergedMap[o.id] = o;
        }
        for (final o in unsynced) {
          mergedMap[o.id] = o; // Local takes precedence
        }

        final mergedList = mergedMap.values.toList();
        mergedList.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        return mergedList;
      }

      return orders;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network')) {
        // Fallback to local
        final localOrders = await _localRepository.getLocalOrders(
            organizationId: organizationId, storeId: storeId, sYear: sYear);
        if (localOrders.isNotEmpty) return localOrders;
      }
      throw Exception('Failed to load orders: $e');
    }
  }

  @override
  Future<Order> createOrder(Order order) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.addOrder(order);
      return order;
    }

    try {
      final model = OrderModel.fromEntity(order);
      final json = model.toJson();
      json.remove('created_at');
      json.remove('updated_at');
      // items_payload is a local SQLite/offline-only column; omtbl_orders
      // has no such column remotely (items are persisted via the separate
      // order-items mechanism instead).
      json.remove('items_payload');
      // ID is preserved to support offline UUID generation

      final response = await SupabaseConfig.client
          .from('omtbl_orders')
          .upsert(
              json) // Use upsert to handle both new and existing (if conflict)
          .select()
          .single();

      // Update local cache as well to ensure consistency
      final newOrder = OrderModel.fromJson(response);
      await _localRepository
          .addOrder(newOrder); // Note: addOrder marks as synced=0 by default?
      // Wait, standard addOrder logic in local repo sets is_synced=0.
      // If we just got it from server, we should mark it synced.
      await _localRepository.markOrderAsSynced(newOrder.id);

      return newOrder;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        await _localRepository.addOrder(order);
        return order;
      }
      throw Exception('Failed to create order: $e');
    }
  }

  @override
  Future<void> updateOrder(Order order) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.updateOrder(order);
      return;
    }

    try {
      final model = OrderModel.fromEntity(order);
      final json = model.toJson();
      // json.remove('id'); // Keep ID for upsert!
      json.remove('created_at');
      json.remove('updated_at');
      // items_payload is a local SQLite/offline-only column; omtbl_orders
      // has no such column remotely (items are persisted via the separate
      // order-items mechanism instead).
      json.remove('items_payload');

      // print('DEBUG: sending updateOrder json: $json for id: ${order.id}');

      // Use upsert to handle cases where the order exists locally (offline created)
      // but not yet on server. This prevents Foreign Key errors when adding items.
      await SupabaseConfig.client.from('omtbl_orders').upsert(json).select();

      // Update local as well
      await _localRepository.updateOrder(order);
      await _localRepository.markOrderAsSynced(order.id);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        await _localRepository.updateOrder(order);
        return;
      }
      throw Exception('Failed to update order: $e');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Offline Delete
      await _localRepository.deleteOrder(id);
      return;
    }

    try {
      await SupabaseConfig.client.from('omtbl_orders').delete().eq('id', id);

      // Also delete from local if successful
      await _localRepository.deleteOrder(id);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        await _localRepository.deleteOrder(id);
        return;
      }
      throw Exception('Failed to delete order: $e');
    }
  }

  @override
  Future<String> generateOrderNumber(String prefix) async {
    // Generate a simple order number: PREFIX-YYYYMMDD-HHMMSS
    // This is simple client-side generation.
    // Ideally, this should be done via a Postgres function or sequence to ensure uniqueness.
    // For now, using timestamp to minimize collision.
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$prefix-$dateStr-$timeStr';
  }

  @override
  Future<void> createOrderItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      final orderId = items.first['order_id'] as String;
      await _localRepository.saveLocalOrderItems(orderId, items);
      return;
    }

    try {
      final itemsToInsert = items.map((i) {
        final m = Map<String, dynamic>.from(i);
        m['order_id'] = items.first[
            'order_id']; // Ensure ID is consistent or use i['order_id'] if available
        // Remove transient fields not in DB
        m.remove('product_name');
        m.remove('uom_symbol');
        m.remove('base_quantity');
        m.remove('created_at');
        m.remove('id');
        m.remove('discount_percent');
        return m;
      }).toList();

      // FIX (C-6): order-item maps carry no client-generated id (see
      // create_order_screen.dart, which builds them without one), so there is
      // no key to upsert on. Replacing the order's line set makes the write
      // idempotent: a retry after a lost response clears the rows the first
      // attempt inserted instead of appending a second copy.
      final targetOrderId = items.first['order_id'] as String;
      await SupabaseConfig.client
          .from('omtbl_order_items')
          .delete()
          .eq('order_id', targetOrderId);

      await SupabaseConfig.client
          .from('omtbl_order_items')
          .insert(itemsToInsert);

      // Update local cache as Synced
      final orderId = items.first['order_id'] as String;
      await _localRepository.saveLocalOrderItems(orderId, items,
          isSynced: true);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        final orderId = items.first['order_id'] as String;
        await _localRepository.saveLocalOrderItems(orderId, items);
        return;
      }
      throw Exception('Failed to create order items: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return _localRepository.getLocalOrderItems(orderId);
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_order_items')
          .select(
              '*, omtbl_products(name), omtbl_units_of_measure(unit_symbol)')
          .eq('order_id', orderId);

      final items = List<Map<String, dynamic>>.from(response).map((item) {
        if (item['omtbl_products'] != null) {
          item['product_name'] = item['omtbl_products']['name'];
        }
        if (item['omtbl_units_of_measure'] != null) {
          item['uom_symbol'] = item['omtbl_units_of_measure']['unit_symbol'];
        }
        return item;
      }).toList();

      // Update cache (Mark as synced since we fetched authoritative data)
      // Protection: If items is empty, verify we are not wiping unsynced local data
      if (items.isEmpty) {
        if (await _localRepository.isOrderUnsynced(orderId)) {
          return _localRepository.getLocalOrderItems(orderId);
        }
      }

      await _localRepository.saveLocalOrderItems(orderId, items,
          isSynced: true);

      return items;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        return _localRepository.getLocalOrderItems(orderId);
      }
      throw Exception('Failed to fetch order items: $e');
    }
  }

  @override
  Future<void> deleteOrderItems(String orderId) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.saveLocalOrderItems(orderId, []);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_order_items')
          .delete()
          .eq('order_id', orderId);

      // Also clear local (Synced)
      await _localRepository.saveLocalOrderItems(orderId, [], isSynced: true);
    } catch (e) {
      debugPrint(
          'Online delete order items failed: $e. Falling back to local.');
      // Optimize Fallback
      try {
        await _localRepository.saveLocalOrderItems(orderId, []);
      } catch (localE) {
        throw Exception('Failed to delete order items: $e');
      }
    }
  }

  @override
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end,
      {int? organizationId, int? storeId}) async {
    try {
      var query = SupabaseConfig.client
          .from('omtbl_orders')
          .select(
              '*, omtbl_businesspartners(name), items:omtbl_order_items(*, product:omtbl_products(name), uom:omtbl_units_of_measure(unit_symbol))')
          .gte('order_date', start.toIso8601String())
          .lte('order_date', end.toIso8601String());

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (storeId != null) query = query.eq('store_id', storeId);

      final response = await query
          .order('order_date', ascending: false)
          .order('created_at', ascending: false);

      final orders = (response as List).map((json) {
        if (json['omtbl_businesspartners'] != null) {
          json['business_partner_name'] =
              json['omtbl_businesspartners']['name'];
        }

        // Flatten items if present
        if (json['items'] != null && json['items'] is List) {
          json['items'] = (json['items'] as List).map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            if (itemMap['product'] != null) {
              itemMap['product_name'] = itemMap['product']['name'];
            }
            if (itemMap['uom'] != null) {
              itemMap['uom_symbol'] = itemMap['uom']['unit_symbol'];
            }
            return itemMap;
          }).toList();
        }

        return OrderModel.fromJson(json);
      }).toList();

      // Helper to fetch user names
      if (orders.isNotEmpty) {
        final userIds = orders.map((o) => o.createdBy).toSet().toList();
        if (userIds.isNotEmpty) {
          try {
            final usersResponse = await SupabaseConfig.client
                .from('omtbl_users') // Corrected table name
                .select(
                    'id, full_name') // id matches auth_user_id usually in omtbl_users schema seen in LoginScreen
                .filter('id', 'in', userIds);

            final userMap = {
              for (var u in (usersResponse as List))
                u['id'] as String: u['full_name'] as String
            };

            return orders.map((o) {
              return o.copyWith(createdByName: userMap[o.createdBy]);
            }).toList();
          } catch (e) {
            debugPrint('Error fetching user names: $e');
            // FALLBACK: Try local DB
            try {
              final db = await DatabaseHelper.instance.database;
              // We can't use 'in' easily with rawQuery in sqflite without safe generic helpers,
              // but we can query all local users or loop.
              // Or just query the ones we need.
              final placeholders = List.filled(userIds.length, '?').join(',');
              final localUsers = await db.rawQuery(
                  'SELECT id, full_name FROM local_users WHERE id IN ($placeholders)',
                  userIds);

              final localUserMap = {
                for (var u in localUsers)
                  u['id'] as String: u['full_name'] as String
              };

              return orders.map((o) {
                return o.copyWith(
                    createdByName:
                        localUserMap[o.createdBy] ?? o.createdByName);
              }).toList();
            } catch (localE) {
              debugPrint('Local user fallback failed: $localE');
            }
          }
        }
      }

      return orders;
    } catch (e) {
      debugPrint('Error in getOrdersByDateRange: $e');
      // If offline, filtered locally
      final localOrders = await _localRepository.getLocalOrders(
          organizationId: organizationId, storeId: storeId);
      return localOrders
          .where((o) =>
              (o.orderDate.isAfter(start) ||
                  o.orderDate.isAtSameMomentAs(start)) &&
              (o.orderDate.isBefore(end) || o.orderDate.isAtSameMomentAs(end)))
          .toList();
    }
  }

  @override
  Future<void> updateDispatchInfo(
      String orderId, String status, DateTime date) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.updateDispatchInfo(orderId, status, date);
      return;
    }

    try {
      await SupabaseConfig.client.from('omtbl_orders').update({
        'dispatch_status': status,
        'dispatch_date': date.toIso8601String(),
      }).eq('id', orderId);

      await _localRepository.updateDispatchInfo(orderId, status, date);
      await _localRepository.markOrderAsSynced(orderId);
    } catch (e) {
      await _localRepository.updateDispatchInfo(orderId, status, date);
    }
  }

  @override
  Future<void> updateOrderInvoiced(String orderId, bool isInvoiced) async {
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _localRepository.updateOrderInvoiced(orderId, isInvoiced);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_orders')
          .update({'is_invoiced': isInvoiced}).eq('id', orderId);

      await _localRepository.updateOrderInvoiced(orderId, isInvoiced);
      await _localRepository.markOrderAsSynced(orderId);
    } catch (e) {
      await _localRepository.updateOrderInvoiced(orderId, isInvoiced);
    }
  }
}
