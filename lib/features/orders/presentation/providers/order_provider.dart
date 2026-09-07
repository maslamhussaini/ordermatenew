import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ordermate/features/orders/data/repositories/order_repository_impl.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/domain/repositories/order_repository.dart';
import 'package:ordermate/core/providers/session_provider.dart'; // Add SessionProvider

import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart'; // Import Accounting Provider
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart'; // Import FinancialSession model

import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';

// State
class OrderState {
  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Order> orders;
  final bool isLoading;
  final String? error;

  OrderState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this.ref, this.repository, this.localRepository)
      : super(const OrderState());

  final Ref ref;

  final OrderRepository repository;
  final OrderLocalRepository localRepository;

  Future<void> loadOrders({int? sYear}) async {
    state = state.copyWith(isLoading: true);
    final store = ref.read(organizationProvider).selectedStore;

    // Use passed sYear or fallback to global selection
    final effectiveSYear =
        sYear ?? ref.read(accountingProvider).selectedFinancialSession?.sYear;

    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    // Always load local data first as fallback
    List<Order> localData = [];
    try {
      localData = await localRepository.getLocalOrders(
          organizationId: orgId, storeId: store?.id, sYear: effectiveSYear);
    } catch (localError) {
      debugPrint('Local load failed: $localError');
    }

    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      state = state.copyWith(isLoading: false, orders: localData);
      return;
    }
    // if (store == null) {
    //   state = state.copyWith(isLoading: false, error: 'No store selected');
    //   return;
    // }

    try {
      final remoteOrders = await repository.getOrders(
          organizationId: orgId,
          storeId: store?.id,
          sYear: effectiveSYear);
      if (!mounted) return;
      // Merge local and remote data
      List<Order> mergedOrders = [...localData];
      for (var remoteOrder in remoteOrders) {
        var existingIndex =
            mergedOrders.indexWhere((o) => o.id == remoteOrder.id);
        if (existingIndex != -1) {
          mergedOrders[existingIndex] = remoteOrder; // Prefer remote if exists
        } else {
          mergedOrders.add(remoteOrder);
        }
      }
      state = state.copyWith(isLoading: false, orders: mergedOrders);
    } catch (e) {
      debugPrint('Remote fetch failed, using local cache: $e');
      if (mounted) state = state.copyWith(isLoading: false, orders: localData);
    }
  }

  Future<Order> _attachLocation(Order order) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return order;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return order;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      // Get Login Location from Session
      final session = ref.read(sessionProvider);

      return order.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        loginLatitude: session.loginLatitude, // Attach Login Lat
        loginLongitude: session.loginLongitude, // Attach Login Lng
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Even if current location fails, try to attach Login Location if available
      try {
        final session = ref.read(sessionProvider);
        if (session.loginLatitude != null) {
          debugPrint(
              'Attaching Login Location fallback: ${session.loginLatitude}');
          return order.copyWith(
            loginLatitude: session.loginLatitude,
            loginLongitude: session.loginLongitude,
          );
        }
      } catch (_) {}
      return order;
    }
  }

  int _validateAndGetSYear(DateTime date) {
    final accountingState = ref.read(accountingProvider);
    if (accountingState.financialSessions.isEmpty) {
      throw Exception(
          'No financial years configured. Please configure a financial session first.');
    }

    if (accountingState.selectedFinancialSession == null) {
      throw Exception(
          'No Financial Year selected. Please select a Financial Session before creating orders.');
    }

    // Find a session that covers this date
    final session =
        accountingState.financialSessions.cast<FinancialSession?>().firstWhere(
              (s) =>
                  s != null &&
                  (date.isAtSameMomentAs(s.startDate) ||
                      date.isAfter(s.startDate)) &&
                  (date.isAtSameMomentAs(s.endDate) ||
                      date.isBefore(
                          s.endDate.add(const Duration(days: 1)))), // inclusive
              orElse: () => null,
            );

    if (session == null) {
      final dateStr = date.toIso8601String().split('T')[0];
      throw Exception(
          'Date $dateStr does not fall within any configured Financial Year.');
    }

    if (session.isClosed) {
      throw Exception(
          'Financial Year ${session.sYear} is closed. Cannot transact.');
    }

    if (session.sYear != accountingState.selectedFinancialSession!.sYear) {
      throw Exception(
          'Date falls in Financial Year ${session.sYear}, but you have selected ${accountingState.selectedFinancialSession!.sYear}. Please switch financial years to create orders.');
    }

    return session.sYear;
  }

  Future<Order> createOrder(Order order) async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    try {
      final sYear = _validateAndGetSYear(order.orderDate);
      final orderWithOrg = order.copyWith(organizationId: orgId, sYear: sYear);
      final orderWithLocation = await _attachLocation(orderWithOrg);

      try {
        final newOrder = await repository.createOrder(orderWithLocation);
        if (!mounted) return orderWithLocation; // Or some default
        // Ideally cache local too
        state = state
            .copyWith(isLoading: false, orders: [newOrder, ...state.orders]);
        ref.read(dashboardProvider.notifier).refresh();
        return newOrder;
      } catch (netErr) {
        if (netErr.toString().contains('SocketException') ||
            netErr.toString().contains('Network')) {
          debugPrint('Network error, saving locally');
          await localRepository.addOrder(orderWithLocation);
          if (!mounted) return orderWithLocation;
          state = state.copyWith(
              isLoading: false, orders: [orderWithLocation, ...state.orders]);
          ref.read(dashboardProvider.notifier).refresh();
          return orderWithLocation;
        }
        rethrow;
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> updateOrder(Order order) async {
    try {
      final sYear = _validateAndGetSYear(order.orderDate);
      final orderWithYear = order.copyWith(sYear: sYear);

      await repository.updateOrder(orderWithYear);
      if (!mounted) return;
      state = state.copyWith(
        orders: state.orders
            .map((o) => o.id == order.id ? orderWithYear : o)
            .toList(),
      );
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        debugPrint('Network error updating order, saving locally: $e');
        try {
          // We should try to update locally with sYear too
          // If original 'order' didn't have sYear, we need validate first.
          // We can't easily jump to 'orderWithYear' here if it wasn't created.
          // So repeat validation:
          final sYearLocal = _validateAndGetSYear(order.orderDate);
          final orderLocal = order.copyWith(sYear: sYearLocal);

          await localRepository.updateOrder(orderLocal);
          if (!mounted) return;
          state = state.copyWith(
            orders: state.orders
                .map((o) => o.id == order.id ? orderLocal : o)
                .toList(),
          );
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          if (!mounted) return;
          state = state.copyWith(error: 'Offline update failed: $localE');
          rethrow;
        }
      }
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    final orderIndex = state.orders.indexWhere((o) => o.id == orderId);
    if (orderIndex == -1) return;

    final order = state.orders[orderIndex];
    final updatedOrder = order.copyWith(status: newStatus);

    // Note: updating status doesn't change Date usually, so existing sYear should be fine.
    // If we want to be strict, we can re-validate orderDate.
    try {
      _validateAndGetSYear(updatedOrder
          .orderDate); // validate but no need to update sYear if not invalid
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return;
    }

    try {
      await repository.updateOrder(updatedOrder);
      state = state.copyWith(
        orders: state.orders
            .map((o) => o.id == orderId ? updatedOrder : o)
            .toList(),
      );
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        try {
          await localRepository.updateOrder(updatedOrder);
          state = state.copyWith(
            orders: state.orders
                .map((o) => o.id == orderId ? updatedOrder : o)
                .toList(),
          );
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          state =
              state.copyWith(error: 'Offline status update failed: $localE');
          rethrow;
        }
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteOrder(String id) async {
    try {
      await repository.deleteOrder(id);
      state = state.copyWith(
        orders: state.orders.where((o) => o.id != id).toList(),
      );
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        try {
          await localRepository.deleteOrder(id);
          state = state.copyWith(
            orders: state.orders.where((o) => o.id != id).toList(),
          );
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          state = state.copyWith(error: 'Offline delete failed: $localE');
          rethrow;
        }
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<String> generateOrderNumber(String prefix) {
    return repository.generateOrderNumber(prefix);
  }

  Future<void> createOrderWithItems(
      Order order, List<Map<String, dynamic>> items) async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    try {
      final sYear = _validateAndGetSYear(order.orderDate);
      final orderWithOrg = order.copyWith(organizationId: orgId, sYear: sYear);

      // 1. Attach Location
      final orderWithLocation = await _attachLocation(orderWithOrg);

      // 2. Create Order
      final newOrder = await repository.createOrder(orderWithLocation);

      // 3. Assign the new Order ID to items
      final itemsWithOrderId = items.map((item) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['order_id'] =
            newOrder.id; // Correctly link to the created order
        newItem.remove('product_name'); // Database doesn't have this column
        return newItem;
      }).toList();

      // 4. Create Items
      await repository.createOrderItems(itemsWithOrderId);
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        orders: [newOrder, ...state.orders],
      );
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        debugPrint(
            'Network error creating order with items, saving locally: $e');
        try {
          final sYear = _validateAndGetSYear(order.orderDate);
          final orderWithOrg =
              order.copyWith(organizationId: orgId, sYear: sYear);

          await localRepository.addOrder(orderWithOrg, items: items);
          if (!mounted) return;

          state = state.copyWith(
            isLoading: false,
            orders: [orderWithOrg, ...state.orders],
          );
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          if (!mounted) return;
          state = state.copyWith(
              isLoading: false,
              error: 'Offline createWithItems failed: $localE');
          rethrow;
        }
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    try {
      return await repository.getOrderItems(orderId);
    } catch (e) {
      // Fallback to local
      try {
        return await localRepository.getLocalOrderItems(orderId);
      } catch (localE) {
        return [];
      }
    }
  }

  Future<void> updateOrderWithItems(
      Order order, List<Map<String, dynamic>> items) async {
    state = state.copyWith(isLoading: true);
    try {
      final sYear = _validateAndGetSYear(order.orderDate);
      final orderWithYear = order.copyWith(sYear: sYear);

      // 1. Update Order Details
      await repository.updateOrder(orderWithYear);

      // 2. Delete existing items
      await repository.deleteOrderItems(order.id);

      // 3. Re-create Items with correct Order ID
      if (items.isNotEmpty) {
        final itemsWithOrderId = items.map((item) {
          final newItem = Map<String, dynamic>.from(item);
          newItem['order_id'] = order.id;
          // Ensure generated ID is removed if we are copying from existing items that have an ID
          newItem.remove('id');
          newItem.remove('created_at');
          newItem.remove('product_name'); // Database doesn't have this column
          return newItem;
        }).toList();
        await repository.createOrderItems(itemsWithOrderId);
      }
      if (!mounted) return;

      // 4. Update State
      final updatedOrders = state.orders
          .map((o) => o.id == order.id ? orderWithYear : o)
          .toList();
      state = state.copyWith(isLoading: false, orders: updatedOrders);
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        try {
          final sYear = _validateAndGetSYear(
              order.orderDate); // validate again for safe local
          final orderWithYear = order.copyWith(sYear: sYear);

          await localRepository.updateOrder(orderWithYear, items: items);
          if (!mounted) return;
          final updatedOrders = state.orders
              .map((o) => o.id == order.id ? orderWithYear : o)
              .toList();
          state = state.copyWith(isLoading: false, orders: updatedOrders);
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          if (!mounted) return;
          state = state.copyWith(
              isLoading: false, error: 'Offline update failed: $localE');
          rethrow;
        }
      }
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateDispatchInfo(
      String orderId, String status, DateTime date) async {
    try {
      await repository.updateDispatchInfo(orderId, status, date);
      state = state.copyWith(
        orders: state.orders
            .map((o) => o.id == orderId
                ? o.copyWith(dispatchStatus: status, dispatchDate: date)
                : o)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateOrderInvoiced(String orderId, bool isInvoiced) async {
    try {
      await repository.updateOrderInvoiced(orderId, isInvoiced);
      state = state.copyWith(
        orders: state.orders
            .map(
                (o) => o.id == orderId ? o.copyWith(isInvoiced: isInvoiced) : o)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

// Providers
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl();
});

final orderLocalRepositoryProvider = Provider<OrderLocalRepository>((ref) {
  return OrderLocalRepository();
});

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  final localRepository = ref.watch(orderLocalRepositoryProvider);

  // Watch store to trigger refresh
  ref.watch(organizationProvider.select((s) => s.selectedStore?.id));

  final notifier = OrderNotifier(ref, repository, localRepository);
  // Auto-load on init/rebuild
  Future.microtask(() => notifier.loadOrders());
  return notifier;
});
