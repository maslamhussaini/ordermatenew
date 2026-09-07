import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/network/supabase_client.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ordermate/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:sqflite/sqflite.dart';

class DashboardState {
  DashboardState({
    this.stats,
    this.isLoading = false,
    this.error,
    this.lastRefreshed,
  });
  final DashboardStats? stats;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefreshed;

  DashboardState copyWith({
    DashboardStats? stats,
    bool? isLoading,
    String? error,
    DateTime? lastRefreshed,
  }) {
    return DashboardState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}

// Notifier
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this.syncService,
      {required this.ref, this.storeId, this.organizationId})
      : super(DashboardState()) {
    // Automatically load stats when the notifier is created
    Future.microtask(() => refresh());

    // Listen for sync completion to refresh local stats
    _listenToSync();
  }

  void _listenToSync() {
    ref.listen<SyncStatus>(syncProgressProvider, (previous, next) async {
      if (previous?.isSyncing == true && next.isSyncing == false) {
        debugPrint('DashboardNotifier: Sync finished, refreshing stats...');

        // Check if still mounted before refreshing
        if (!mounted) {
          debugPrint('DashboardNotifier: Already disposed, skipping refresh');
          return;
        }

        // CONSISTENT BEHAVIOR for all platforms:
        // Always try Online first unless explicitly in Offline Mode.
        // We catch errors in _loadOnlineStats and fallback to local.
        if (SupabaseConfig.isOfflineLoggedIn) {
          _loadLocalStats(null);
        } else {
          _loadOnlineStats();
        }
      }
    });
  }

  final SyncService syncService;
  final int? storeId;
  final int? organizationId;
  final Ref ref;

  Future<void> refresh() async {
    // If no organization is selected (e.g. during logout or initial load),
    // do not attempt to fetch stats.
    if (organizationId == null) {
      debugPrint(
          'Dashboard: No organization selected. Skipping stats refresh.');
      state = state.copyWith(isLoading: false);
      return;
    }

    debugPrint(
        'Dashboard: Refreshing stats for orgId: $organizationId, storeId: $storeId');

    // CONSISTENT BEHAVIOR:
    // Remove ConnectivityHelper check which might vary by OS (Desktop vs Mobile).
    // Always attempt Online fetch. If it fails (network issue), _loadOnlineStats falls back to local.
    bool tryOnline = !SupabaseConfig.isOfflineLoggedIn;

    state = state.copyWith(isLoading: true);
    if (tryOnline) {
      await _loadOnlineStats();
    } else {
      await _loadLocalStats(null);
    }

    // Background Sync
    if (tryOnline && !ref.read(syncProgressProvider).isSyncing) {
      // Add null check for organizationId before syncing
      if (organizationId == null) {
        debugPrint(
            'Dashboard: Cannot start background sync, no organization selected.');
        return;
      }
      syncService
          .syncAll()
          .catchError((e) => debugPrint('Dashboard Sync Bg Error: $e'));
    }
  }

  Future<void> _loadOnlineStats() async {
    if (!mounted) return;
    try {
      final client = SupabaseConfig.client;

      // helper for count
      Future<int> fetchCount(
        String table,
        String? statusCol,
        String? statusVal, {
        bool isCustomer = false,
        bool isVendor = false,
        bool isSupplier = false,
        String? invoiceType,
      }) async {
        // Start filter builder
        var query = client.from(table).select();

        if (organizationId != null) {
          query = query.eq('organization_id', organizationId!);
        }

        if (storeId != null) {
          // Strict filtering as requested by user's SQL
          query = query.eq('store_id', storeId!);
        }

        if (statusCol != null && statusVal != null) {
          query = query.eq(statusCol, statusVal);
        }

        if (isCustomer) query = query.eq('is_customer', 1);
        if (isVendor) query = query.eq('is_vendor', 1).eq('is_supplier', 0);
        if (isSupplier) query = query.eq('is_supplier', 1);

        if (table == 'omtbl_businesspartners' && statusCol == 'is_employee') {
          query = query.eq('is_employee', 1);
        } else if (statusCol != null && statusVal != null) {
          // For orders status, it's a string
          query = query.eq(statusCol, statusVal);
        }

        if (invoiceType != null) {
          query = query.eq('id_invoice_type', invoiceType);
        }

        final res = await query.count(CountOption.exact);
        return res.count;
      }

      // Partners
      final customers = await fetchCount('omtbl_businesspartners', null, null,
          isCustomer: true);
      final vendors = await fetchCount('omtbl_businesspartners', null, null,
          isVendor: true);
      final suppliers = await fetchCount('omtbl_businesspartners', null, null,
          isSupplier: true);
      final employees =
          await fetchCount('omtbl_businesspartners', 'is_employee', '1');

      debugPrint(
          'Dashboard Online Counts: Customers=$customers, Vendors=$vendors, Suppliers=$suppliers, Employees=$employees');

      // Products
      var productsQuery = client.from('omtbl_products').select();
      if (organizationId != null) {
        productsQuery = productsQuery.eq('organization_id', organizationId!);
      }
      final productsRes = await productsQuery.count(CountOption.exact);
      final products = productsRes.count;

      // Orders
      final booked = await fetchCount('omtbl_orders', 'status', 'Booked');
      final approved = await fetchCount('omtbl_orders', 'status', 'Approved');
      final pending = await fetchCount('omtbl_orders', 'status', 'Pending');
      final rejected = await fetchCount('omtbl_orders', 'status', 'Rejected');

      // Invoices
      final si =
          await fetchCount('omtbl_invoices', null, null, invoiceType: 'SI');
      final sr =
          await fetchCount('omtbl_invoices', null, null, invoiceType: 'SR');
      final pi =
          await fetchCount('omtbl_invoices', null, null, invoiceType: 'PI');
      final pr =
          await fetchCount('omtbl_invoices', null, null, invoiceType: 'PR');

      final newStats = DashboardStats(
        totalCustomers: customers,
        totalProducts: products,
        customersInArea: 0,
        ordersBooked: booked,
        ordersApproved: approved,
        ordersPending: pending,
        ordersRejected: rejected,
        totalVendors: vendors,
        totalSuppliers: suppliers,
        totalEmployees: employees,
        salesInvoicesCount: si,
        salesReturnsCount: sr,
        purchaseInvoicesCount: pi,
        purchaseReturnsCount: pr,
      );

      if (!mounted) return;
      state = DashboardState(
        stats: newStats,
        lastRefreshed: DateTime.now(),
        error: null,
      );
    } catch (e) {
      debugPrint('Dashboard: Online fetch failed ($e). Falling back to local.');
      await _loadLocalStats(e);
    }
  }

  Future<void> _loadLocalStats(Object? originalError) async {
    if (!mounted) return;

    try {
      final db = await DatabaseHelper.instance.database;

      // --- Filter Setup ---
      // 1. Master Filter (Loose): Helper method for Products/Partners (Includes Global Items)
      String masterFilter = '';
      List<dynamic> masterArgs = [];

      if (organizationId != null) {
        masterFilter += ' AND organization_id = ?';
        masterArgs.add(organizationId);
      }

      if (storeId != null) {
        masterFilter += ' AND (store_id = ? OR store_id IS NULL)';
        masterArgs.add(storeId);
      }

      // 2. Transaction Filter (Strict): Helper for Orders (Strictly Store-Bound)
      String txFilter = '';
      List<dynamic> txArgs = [];

      if (organizationId != null) {
        txFilter += ' AND organization_id = ?';
        txArgs.add(organizationId);
      }

      if (storeId != null) {
        txFilter += ' AND store_id = ?';
        txArgs.add(storeId);
      } else {
        // If storeId is null (All Stores), we might want all transactions for the org.
        // The organization_id check above handles this.
      }

      // --- Queries ---

      // 1. Customers
      final customersMap = await db.rawQuery(
          'SELECT COUNT(*) as count FROM local_businesspartners p WHERE p.is_customer = 1$txFilter',
          txArgs);
      final customersCount = Sqflite.firstIntValue(customersMap) ?? 0;

      // 2. Products
      // Products (Loose Filter matches Online Loose Logic)
      final productsMap = await db.rawQuery(
          'SELECT COUNT(*) as count FROM local_products p WHERE 1=1$masterFilter',
          masterArgs);
      final productsCount = Sqflite.firstIntValue(productsMap) ?? 0;

      // 3. Vendors
      final vendorsMap = await db.rawQuery(
          'SELECT COUNT(*) as count FROM local_businesspartners p WHERE p.is_vendor = 1 AND is_supplier = 0$txFilter',
          txArgs);
      final vendorsCount = Sqflite.firstIntValue(vendorsMap) ?? 0;

      // 4. Suppliers
      final suppliersMap = await db.rawQuery(
          'SELECT COUNT(*) as count FROM local_businesspartners p WHERE p.is_supplier = 1$txFilter',
          txArgs);
      final suppliersCount = Sqflite.firstIntValue(suppliersMap) ?? 0;

      // 5. Employees
      final employeesMap = await db.rawQuery(
          'SELECT COUNT(*) as count FROM local_businesspartners p WHERE p.is_employee = 1$txFilter',
          txArgs);
      final employeesCount = Sqflite.firstIntValue(employeesMap) ?? 0;

      debugPrint(
          'Dashboard Local Counts: Customers=$customersCount, Vendors=$vendorsCount, Suppliers=$suppliersCount, Employees=$employeesCount');

      // 5. Orders
      int getCount(List<Map<String, Object?>> res) =>
          Sqflite.firstIntValue(res) ?? 0;

      // Fixed: Using txFilter (Strict) and case-insensitive check
      final booked = await db.rawQuery(
          "SELECT COUNT(*) FROM local_orders WHERE status = 'Booked' COLLATE NOCASE$txFilter",
          txArgs);
      final approved = await db.rawQuery(
          "SELECT COUNT(*) FROM local_orders WHERE status = 'Approved' COLLATE NOCASE$txFilter",
          txArgs);
      final pending = await db.rawQuery(
          "SELECT COUNT(*) FROM local_orders WHERE status = 'Pending' COLLATE NOCASE$txFilter",
          txArgs);
      final rejected = await db.rawQuery(
          "SELECT COUNT(*) FROM local_orders WHERE status = 'Rejected' COLLATE NOCASE$txFilter",
          txArgs);
      // Removed duplicate rejected line

      // 6. Invoices (Strict filtering similar to Tx)
      // Note: Invoices table doesn't use alias 'p' in our previous logic, so strict construction here
      String invFilter = '';
      List<dynamic> invArgs = [];

      if (organizationId != null) {
        invFilter += ' AND organization_id = ?';
        invArgs.add(organizationId);
      }
      if (storeId != null) {
        invFilter += ' AND store_id = ?';
        invArgs.add(storeId);
      }

      final si = await db.rawQuery(
          "SELECT COUNT(*) FROM local_invoices WHERE id_invoice_type = 'SI'$invFilter",
          invArgs);
      final sr = await db.rawQuery(
          "SELECT COUNT(*) FROM local_invoices WHERE id_invoice_type = 'SR'$invFilter",
          invArgs);
      final pi = await db.rawQuery(
          "SELECT COUNT(*) FROM local_invoices WHERE id_invoice_type = 'PI'$invFilter",
          invArgs);
      final pr = await db.rawQuery(
          "SELECT COUNT(*) FROM local_invoices WHERE id_invoice_type = 'PR'$invFilter",
          invArgs);

      final newStats = DashboardStats(
        totalCustomers: customersCount,
        totalProducts: productsCount,
        customersInArea: 0,
        ordersBooked: getCount(booked),
        ordersApproved: getCount(approved),
        ordersPending: getCount(pending),
        ordersRejected: getCount(rejected),
        totalVendors: vendorsCount, // Using aligned Vendor Logic
        totalSuppliers: suppliersCount,
        totalEmployees: employeesCount,
        salesInvoicesCount: getCount(si),
        salesReturnsCount: getCount(sr),
        purchaseInvoicesCount: getCount(pi),
        purchaseReturnsCount: getCount(pr),
      );

      // debugPrint('Dashboard: Stats loaded for store $storeId. Vendors: $vendorsCount');

      if (!mounted) return;
      state = DashboardState(
        stats: newStats,
        lastRefreshed: DateTime.now(),
        error: null,
      );
    } catch (e) {
      if (!mounted) return;

      // On web, SQLite errors are common but shouldn't distract from the main Online error
      String displayError = originalError?.toString() ?? e.toString();

      // If we detect recursion error, make it more helpful
      if (displayError.contains('infinite recursion')) {
        displayError =
            'Database Security Error (Infinite Recursion). Please run the fix script in Supabase SQL Editor.';
      } else if (kIsWeb && displayError.contains('SqfliteFfiWebException')) {
        displayError = originalError?.toString() ??
            'Connection error. Please check your Supabase settings.';
      }

      state = DashboardState(
        error: displayError,
        stats: state.stats,
        isLoading: false,
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  // Watch organization changes to trigger rebuild/refresh
  final orgState = ref.watch(organizationProvider);
  final storeId = orgState.selectedStore?.id;
  final organizationId = orgState.selectedOrganization?.id;

  return DashboardNotifier(
    syncService,
    ref: ref,
    storeId: storeId,
    organizationId: organizationId,
  );
});
