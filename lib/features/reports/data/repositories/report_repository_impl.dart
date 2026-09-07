// lib/features/reports/data/repositories/report_repository_impl.dart

import 'package:ordermate/core/database/database_helper.dart';
import '../../domain/repositories/report_repository.dart';
import '../../../accounting/domain/entities/chart_of_account.dart';
import '../../../accounting/data/models/accounting_models.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SupabaseClient _supabase = SupabaseConfig.client;

  @override
  Future<Map<String, dynamic>> getLedgerData(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    int? storeId,
    int? sYear,
    String? moduleAccount,
  }) async {
    final db = await _dbHelper.database;

    // Determine if we are looking for a sub-ledger (BP/Bank/Cash) or a GL account
    final isSubLedger = moduleAccount != null && moduleAccount.isNotEmpty;
    final targetId = isSubLedger ? moduleAccount : accountId;

    // We need to find the specific GL account associated if it's a sub-ledger
    String? glAccountId = accountId; // Default to the provided accountId
    if (isSubLedger) {
      final bp = await db.query('local_businesspartners',
          where: 'id = ?', whereArgs: [targetId]);
      if (bp.isNotEmpty) {
        glAccountId = bp.first['chart_of_account_id'] as String?;
      } else {
        // If moduleAccount is provided but no BP found, it might be a Bank/Cash account
        final bc = await db
            .query('local_bank_cash', where: 'id = ?', whereArgs: [targetId]);
        if (bc.isNotEmpty) {
          glAccountId = bc.first['chart_of_account_id'] as String?;
        }
      }
    }

    // For queries, if glAccountId is null, use a dummy value that won't match anything
    final searchGlAccountId = glAccountId ?? 'NON_EXISTENT_ID_XYZ';

    // Filters Construction
    String extraWhere = '';
    final List<dynamic> extraArgs = [];
    if (organizationId != null && organizationId != 0) {
      extraWhere +=
          ' AND (t.organization_id = ? OR t.organization_id IS NULL OR t.organization_id = 0)';
      extraArgs.add(organizationId);
    }
    if (storeId != null && storeId != 0) {
      // Be inclusive: show specific store XOR global/null entries
      extraWhere +=
          ' AND (t.store_id = ? OR t.store_id IS NULL OR t.store_id = 0)';
      extraArgs.add(storeId);
    }
    if (sYear != null && sYear != 0) {
      extraWhere += ' AND (t.syear = ? OR t.syear IS NULL OR t.syear = 0)';
      extraArgs.add(sYear);
    }

    // 1. Calculate Opening Balance
    double openingBalance = 0.0;
    if (startDate != null) {
      // Inclusive search for opening balance
      String opWhere =
          '(t.module_account = ? OR t.account_id = ? OR t.offset_module_account = ? OR t.offset_account_id = ?)';

      final opSql = '''
        SELECT 
          SUM(CASE WHEN (t.module_account = ? OR t.account_id = ?) THEN t.amount ELSE 0 END) as total_debit,
          SUM(CASE WHEN (t.offset_module_account = ? OR t.offset_account_id = ?) THEN t.amount ELSE 0 END) as total_credit
        FROM local_transactions t
        WHERE $opWhere AND t.voucher_date < ? $extraWhere
      ''';

      // Args: 2 for first SUM, 2 for second SUM, 4 for WHERE, 1 for date, then extra filters
      final opArgs = [
        targetId,
        searchGlAccountId,
        targetId,
        searchGlAccountId,
        targetId,
        searchGlAccountId,
        targetId,
        searchGlAccountId,
        startDate.millisecondsSinceEpoch,
        ...extraArgs
      ];

      print('SQL (Opening Balance): $opSql');
      print('Args (Opening Balance): $opArgs');

      final opResult = await db.rawQuery(opSql, opArgs);

      if (opResult.isNotEmpty) {
        final dr = (opResult.first['total_debit'] as num?)?.toDouble() ?? 0.0;
        final cr = (opResult.first['total_credit'] as num?)?.toDouble() ?? 0.0;
        openingBalance = dr - cr;
      }
    }

    // --- DEEP DIAGNOSTICS ---
    print('--- DEEP DATABASE SCAN ---');
    // 1. Check if the target exists in Business Partners
    final bpCheck = await db.query('local_businesspartners',
        where: 'id = ?', whereArgs: [targetId]);
    print(
        'BP Lookup: ${bpCheck.isNotEmpty ? "FOUND" : "NOT FOUND"} (ID: $targetId)');

    // 2. Scan for ANY row containing the ID in any column
    final anyMatches = await db.rawQuery('''
      SELECT voucher_number, module_account, offset_module_account, organization_id, store_id, syear 
      FROM local_transactions 
      WHERE module_account LIKE ? OR offset_module_account LIKE ? 
      LIMIT 10
    ''', ['%$targetId%', '%$targetId%']);
    print('Broad Partial ID Match: Found ${anyMatches.length} rows');
    for (var m in anyMatches) {
      print(
          '  - ${m['voucher_number']} | Mod: ${m['module_account']} | Org: ${m['organization_id']} | Store: ${m['store_id']}');
    }

    // 3. Scan specifically for the missing INV vouchers to see their metadata
    final invCheck = await db.rawQuery(
        "SELECT voucher_number, module_account, account_id, organization_id, store_id FROM local_transactions WHERE voucher_number LIKE 'INV%' LIMIT 10");
    print(
        'INV Prefix Scan: Found ${invCheck.length} total Sales Invoices in DB');
    for (var i in invCheck) {
      print(
          '  - ${i['voucher_number']} | Mod: ${i['module_account']} (GL: ${i['account_id']}) | Org: ${i['organization_id']}');
    }

    final glCheck = await db.rawQuery(
        "SELECT voucher_number, module_account, account_id, organization_id, store_id FROM local_transactions WHERE account_id = ? OR module_account = ? LIMIT 10",
        [searchGlAccountId, targetId]);
    print(
        'Target ID Direct Scan (ID: $targetId / GL: $searchGlAccountId): Found ${glCheck.length} rows');
    for (var g in glCheck) {
      print(
          '  - ${g['voucher_number']} | Mod: ${g['module_account']} (GL: ${g['account_id']})');
    }
    print('--------------------------');

    // 2. Main Ledger Query matching User's Snippet logic (but with flexible metadata)
    final dateWhere = startDate != null ? ' AND t.voucher_date >= ?' : '';
    final dateEndWhere = endDate != null ? ' AND t.voucher_date <= ?' : '';

    String metaWhere = '';
    final filterArgs = [];
    if (organizationId != null && organizationId != 0) {
      metaWhere +=
          ' AND (t.organization_id = ? OR t.organization_id IS NULL OR t.organization_id = 0)';
      filterArgs.add(organizationId);
    }
    if (storeId != null && storeId != 0) {
      metaWhere +=
          ' AND (t.store_id = ? OR t.store_id IS NULL OR t.store_id = 0)';
      filterArgs.add(storeId);
    }
    if (sYear != null && sYear != 0) {
      metaWhere += ' AND (t.syear = ? OR t.syear IS NULL OR t.syear = 0)';
      filterArgs.add(sYear);
    }
    if (startDate != null) filterArgs.add(startDate.millisecondsSinceEpoch);
    if (endDate != null) filterArgs.add(endDate.millisecondsSinceEpoch);

    final sql = '''
      WITH unified_accounts AS (
        SELECT id as acid, account_code as accode, account_title as acname FROM local_chart_of_accounts
        UNION ALL
        SELECT id as acid, 'BP' as accode, name as acname FROM local_businesspartners
        UNION ALL
        SELECT id as acid, 'BC' as accode, bank_name as acname FROM local_bank_cash
      ),
      LedgerEntries AS (
        -- 1. Debits (Target as Primary)
        SELECT 
            t.id, 
            t.voucher_number, 
            t.voucher_date, 
            t.description, 
            COALESCE(vm.accode, vg.accode, '') as accode, 
            CASE 
              WHEN vm.acname IS NOT NULL AND vg.acname IS NOT NULL AND vm.acname != vg.acname 
              THEN vm.acname || ' (' || vg.acname || ')'
              ELSE COALESCE(vm.acname, vg.acname, 'General Ledger')
            END as acname,
            t.amount as debit, 
            0.0 as credit
        FROM local_transactions t
        LEFT JOIN unified_accounts vm ON t.offset_module_account = vm.acid
        LEFT JOIN unified_accounts vg ON t.offset_account_id = vg.acid
        WHERE (t.module_account = ? OR t.account_id = ?)
          $metaWhere
          $dateWhere
          $dateEndWhere

        UNION ALL

        -- 2. Credits (Target as Offset)
        SELECT 
            t.id, 
            t.voucher_number, 
            t.voucher_date, 
            t.description, 
            COALESCE(vm.accode, vg.accode, '') as accode, 
            CASE 
              WHEN vm.acname IS NOT NULL AND vg.acname IS NOT NULL AND vm.acname != vg.acname 
              THEN vm.acname || ' (' || vg.acname || ')'
              ELSE COALESCE(vm.acname, vg.acname, 'General Ledger')
            END as acname,
            0.0 as debit, 
            t.amount as credit
        FROM local_transactions t
        LEFT JOIN unified_accounts vm ON t.module_account = vm.acid
        LEFT JOIN unified_accounts vg ON t.account_id = vg.acid
        WHERE (t.offset_module_account = ? OR t.offset_account_id = ?)
          $metaWhere
          $dateWhere
          $dateEndWhere
    )
    SELECT *,
        SUM(debit - credit) OVER (ORDER BY voucher_date ASC, id ASC) as running_sum
    FROM LedgerEntries
    ORDER BY voucher_date ASC, id ASC;
    ''';

    final queryArgs = [
      targetId,
      searchGlAccountId,
      ...filterArgs,
      targetId,
      searchGlAccountId,
      ...filterArgs,
    ];

    // --- DIAGNOSTIC DEBUG ---
    print('DEBUG: Running Ledger for $targetId');
    print(
        'DEBUG: Meta Filters: org=$organizationId, store=$storeId, year=$sYear');

    // Check total records for this ID ignoring everything else
    final globalCheck = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM local_transactions WHERE module_account = ? OR offset_module_account = ?',
        [targetId, targetId]);
    print(
        'DEBUG: GLOBAL COUNT for this ID (no filters): ${globalCheck.first['cnt']}');

    final periodMaps = await db.rawQuery(sql, queryArgs);
    print('DEBUG: PERIOD MATCHES found: ${periodMaps.length}');

    return {
      'openingBalance': openingBalance,
      'transactions': periodMaps.map((m) {
        final map = Map<String, dynamic>.from(m);
        final runningSum = (m['running_sum'] as num?)?.toDouble() ?? 0.0;
        map['running_balance'] = runningSum + openingBalance;
        return map;
      }).toList(),
    };
  }

  @override
  Future<List<Transaction>> getAccountLedger(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? moduleAccount,
  }) async {
    final db = await _dbHelper.database;

    // Determine Filter: Sub-Ledger (Customer/Vendor) OR General Ledger (Account)
    String where = '';
    List<dynamic> args = [];

    if (moduleAccount != null && moduleAccount.isNotEmpty) {
      // Search by Sub-Ledger ID (e.g. Customer ID)
      where = '(module_account = ? OR offset_module_account = ?)';
      args = [moduleAccount, moduleAccount];
    } else {
      // Search by General Ledger Account ID
      where = '(account_id = ? OR offset_account_id = ?)';
      args = [accountId, accountId];
    }

    if (organizationId != null) {
      where += ' AND organization_id = ?';
      args.add(organizationId);
    }

    if (startDate != null) {
      where += ' AND voucher_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND voucher_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    final maps = await db.query('local_transactions',
        where: where, whereArgs: args, orderBy: 'voucher_date ASC');
    return maps
        .map((e) => TransactionModel(
              id: e['id'] as String,
              voucherPrefixId: e['voucher_prefix_id'] as int,
              voucherNumber: e['voucher_number'] as String,
              voucherDate:
                  DateTime.fromMillisecondsSinceEpoch(e['voucher_date'] as int),
              accountId: e['account_id'] as String,
              offsetAccountId: e['offset_account_id'] as String?,
              amount: (e['amount'] as num).toDouble(),
              description: e['description'] as String?,
              status: e['status'] as String? ?? 'posted',
              organizationId: (e['organization_id'] as int?) ?? 0,
              storeId: (e['store_id'] as int?) ?? 0,
              sYear: e['syear'] as int?,
              moduleAccount: e['module_account'] as String?,
              offsetModuleAccount: e['offset_module_account'] as String?,
            ))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesByProduct({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type,
  }) async {
    // try online first
    if (organizationId != null) {
      final connectivity = await ConnectivityHelper.check();
      if (!connectivity.contains(ConnectivityResult.none)) {
        try {
          final dates = await _resolveDates(
            organizationId: organizationId,
            sYear: (startDate ?? DateTime.now()).year,
            startDate: startDate,
            endDate: endDate,
          );
          final start = dates['start']!;
          final end = dates['end']!;
          final typeIds = await _getInvoiceTypeIds(type ?? 'SI',
              organizationId: organizationId);

          if (typeIds.isNotEmpty) {
            final res = await _supabase
                .from('omtbl_invoice_items')
                .select('*, omtbl_invoices!inner(*)')
                .eq('omtbl_invoices.organization_id', organizationId)
                .filter('omtbl_invoices.id_invoice_type', 'in', typeIds)
                .gte('omtbl_invoices.invoice_date',
                    DateFormat('yyyy-MM-dd').format(start))
                .lte('omtbl_invoices.invoice_date',
                    DateFormat('yyyy-MM-dd').format(end));

            final Map<String, Map<String, dynamic>> grouped = {};
            for (var item in res as List) {
              final pId = item['product_id'].toString();
              final pName = item['product_name'] ?? 'Unknown Product';
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
              final total = (item['total'] as num?)?.toDouble() ?? 0.0;

              if (!grouped.containsKey(pId)) {
                grouped[pId] = {
                  'product_id': pId,
                  'product_name': pName,
                  'total_quantity': 0.0,
                  'total_amount': 0.0,
                };
              }
              grouped[pId]!['total_quantity'] =
                  (grouped[pId]!['total_quantity'] as double) + qty;
              grouped[pId]!['total_amount'] =
                  (grouped[pId]!['total_amount'] as double) + total;
            }
            return grouped.values.toList();
          }
        } catch (e) {
          debugPrint('Online getSalesByProduct failed: $e');
        }
      }
    }

    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        ii.product_id, 
        MAX(COALESCE(p.name, ii.product_name, 'Unknown Product')) as product_name, 
        SUM(COALESCE(ii.quantity, 0)) as total_quantity, 
        SUM(COALESCE(ii.total, 0)) as total_amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }

    if (type != null) {
      // For local, we assume types are synced correctly or we use names
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }

    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY ii.product_id ORDER BY total_amount DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesDetailsByProduct({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type,
  }) async {
    if (organizationId != null) {
      final connectivity = await ConnectivityHelper.check();
      if (!connectivity.contains(ConnectivityResult.none)) {
        try {
          final dates = await _resolveDates(
            organizationId: organizationId,
            sYear: (startDate ?? DateTime.now()).year,
            startDate: startDate,
            endDate: endDate,
          );
          final start = dates['start']!;
          final end = dates['end']!;
          final typeIds = await _getInvoiceTypeIds(type ?? 'SI',
              organizationId: organizationId);

          if (typeIds.isNotEmpty) {
            final res = await _supabase
                .from('omtbl_invoice_items')
                .select(
                    '*, omtbl_invoices!inner(*, omtbl_businesspartners(name))')
                .eq('omtbl_invoices.organization_id', organizationId)
                .filter('omtbl_invoices.id_invoice_type', 'in', typeIds)
                .gte('omtbl_invoices.invoice_date',
                    DateFormat('yyyy-MM-dd').format(start))
                .lte('omtbl_invoices.invoice_date',
                    DateFormat('yyyy-MM-dd').format(end));

            return (res as List).map((e) {
              final inv = e['omtbl_invoices'];
              final bp = inv['omtbl_businesspartners'];
              return {
                'product_id': e['product_id'],
                'product_name': e['product_name'] ?? 'Unknown Product',
                'invoice_number': inv['invoice_number'],
                'invoice_date': inv['invoice_date'], // String
                'customer_name': bp != null ? bp['name'] : 'Unknown Customer',
                'quantity': e['quantity'],
                'amount': e['total'],
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('Online getSalesDetailsByProduct failed: $e');
        }
      }
    }

    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        ii.product_id, 
        COALESCE(p.name, ii.product_name, 'Unknown Product') as product_name, 
        i.invoice_number,
        i.invoice_date,
        COALESCE(bp.name, 'Unknown Customer') as customer_name,
        ii.quantity, 
        ii.total as amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }

    if (type != null) {
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }

    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    // Order by Product Name and then Invoice Date
    sql += ' ORDER BY product_name, i.invoice_date DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesByCustomer({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type,
  }) async {
    if (organizationId != null) {
      final connectivity = await ConnectivityHelper.check();
      if (!connectivity.contains(ConnectivityResult.none)) {
        try {
          final dates = await _resolveDates(
            organizationId: organizationId,
            sYear: (startDate ?? DateTime.now()).year,
            startDate: startDate,
            endDate: endDate,
          );
          final start = dates['start']!;
          final end = dates['end']!;
          final typeIds = await _getInvoiceTypeIds(type ?? 'SI',
              organizationId: organizationId);

          if (typeIds.isNotEmpty) {
            final res = await _supabase
                .from('omtbl_invoices')
                .select('*, omtbl_businesspartners(name)')
                .eq('organization_id', organizationId)
                .filter('id_invoice_type', 'in', typeIds)
                .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
                .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

            final Map<String, Map<String, dynamic>> grouped = {};
            for (var item in res as List) {
              final bp = item['omtbl_businesspartners'];
              final name = bp != null ? bp['name'] : 'Unknown Customer';
              final amt = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

              if (!grouped.containsKey(name)) {
                grouped[name] = {
                  'business_partner_id': item['business_partner_id'],
                  'customer_name': name,
                  'total_invoices': 0,
                  'total_amount': 0.0,
                };
              }
              grouped[name]!['total_invoices'] =
                  (grouped[name]!['total_invoices'] as int) + 1;
              grouped[name]!['total_amount'] =
                  (grouped[name]!['total_amount'] as double) + amt;
            }
            return grouped.values.toList();
          }
        } catch (e) {
          debugPrint('Online getSalesByCustomer failed: $e');
        }
      }
    }

    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        i.business_partner_id, 
        MAX(COALESCE(bp.name, 'Unknown Customer')) as customer_name,
        COUNT(i.id) as total_invoices,
        SUM(COALESCE(i.total_amount, 0)) as total_amount
      FROM local_invoices i
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }

    if (type != null) {
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }

    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY i.business_partner_id';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getAgingData(
    String partnerId, {
    int? organizationId,
    int? storeId,
  }) async {
    final db = await _dbHelper.database;

    // We select unpaid invoices and calculate their age
    String sql = '''
      SELECT 
        id as invoice_id,
        invoice_number,
        invoice_date,
        due_date,
        total_amount,
        paid_amount,
        (total_amount - paid_amount) as outstanding_amount
      FROM local_invoices
      WHERE business_partner_id = ?
      AND (total_amount - paid_amount) > 0
    ''';

    List<dynamic> args = [partnerId];

    if (organizationId != null) {
      sql += ' AND organization_id = ?';
      args.add(organizationId);
    }

    if (storeId != null) {
      sql += ' AND store_id = ?';
      args.add(storeId);
    }

    sql += ' ORDER BY invoice_date ASC';

    return await db.rawQuery(sql, args);
  }

  // --- Helper to calculate Opening Stocks for Products ---
  Future<Map<String, double>> _calculateOpeningStocks({
    required int organizationId,
    int? storeId,
    required DateTime beforeDate,
    List<String>? productIds,
  }) async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(beforeDate);
    final Map<String, double> stockAtDate = {};

    // 1. Get CURRENT Stock
    var productQuery = _supabase
        .from('omtbl_products')
        .select('id, stock_qty')
        .eq('organization_id', organizationId);
    if (productIds != null && productIds.isNotEmpty) {
      productQuery = productQuery.filter('id', 'in', productIds);
    }

    final productsRes = await productQuery;
    for (var p in productsRes as List) {
      stockAtDate[p['id'].toString()] =
          (p['stock_qty'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Adjust BACKWARDS from transactions >= beforeDate
    // Logic: Opening = Current - (Net Change since Date)
    // If we bought (PI/SR) since date, we remove it.
    // If we sold (SI/PR) since date, we add it back.
    
    final piIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    final prIds =
        await _getInvoiceTypeIds('PR', organizationId: organizationId);
    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final srIds =
        await _getInvoiceTypeIds('SR', organizationId: organizationId);
    final allTypeIds = [...piIds, ...prIds, ...siIds, ...srIds];

    if (allTypeIds.isNotEmpty) {
      var invItemQuery = _supabase
          .from('omtbl_invoice_items')
          .select('product_id, quantity, omtbl_invoices!inner(id_invoice_type)')
          .eq('omtbl_invoices.organization_id', organizationId)
          .gte('omtbl_invoices.invoice_date', dateStr)
          .filter('omtbl_invoices.id_invoice_type', 'in', allTypeIds);

      if (storeId != null) {
        invItemQuery = invItemQuery.eq('omtbl_invoices.store_id', storeId);
      }
      if (productIds != null && productIds.isNotEmpty) {
        invItemQuery = invItemQuery.filter('product_id', 'in', productIds);
      }

      final invItemsRes = await invItemQuery;
      for (var item in invItemsRes as List) {
        final pId = item['product_id'].toString();
        if (!stockAtDate.containsKey(pId)) continue; 

        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final typeId = item['omtbl_invoices']['id_invoice_type'] as int;

        if (piIds.contains(typeId) || srIds.contains(typeId)) {
          // Purchase or Sales Return increased stock later. Subtract to go back.
          stockAtDate[pId] = stockAtDate[pId]! - qty;
        } else if (prIds.contains(typeId) || siIds.contains(typeId)) {
          // Purchase Return or Sales decreased stock later. Add to go back.
          stockAtDate[pId] = stockAtDate[pId]! + qty;
        }
      }
    }

    // 3. Adjust with Stock Transfers (only if storeId is specified)
    if (storeId != null) {
      // Outward Transfers (Source = storeId)
      // These DECREASED stock later. Add back.
      var outTransferQuery = _supabase
          .from('omtbl_stock_transfer_items')
          .select(
              'product_id, quantity, omtbl_stock_transfers!inner(source_store_id, status)')
          .eq('omtbl_stock_transfers.organization_id', organizationId)
          .eq('omtbl_stock_transfers.source_store_id', storeId)
          .eq('omtbl_stock_transfers.status', 'Completed')
          .gte('omtbl_stock_transfers.transfer_date', dateStr);

      if (productIds != null && productIds.isNotEmpty) {
        outTransferQuery =
            outTransferQuery.filter('product_id', 'in', productIds);
      }

      final outRes = await outTransferQuery;
      for (var item in outRes as List) {
        final pId = item['product_id'].toString();
        if (stockAtDate.containsKey(pId)) {
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          stockAtDate[pId] = stockAtDate[pId]! + qty;
        }
      }

      // Inward Transfers (Destination = storeId)
      // These INCREASED stock later. Subtract.
      var inTransferQuery = _supabase
          .from('omtbl_stock_transfer_items')
          .select(
              'product_id, quantity, omtbl_stock_transfers!inner(destination_store_id, status)')
          .eq('omtbl_stock_transfers.organization_id', organizationId)
          .eq('omtbl_stock_transfers.destination_store_id', storeId)
          .eq('omtbl_stock_transfers.status', 'Completed')
          .gte('omtbl_stock_transfers.transfer_date', dateStr);

      if (productIds != null && productIds.isNotEmpty) {
        inTransferQuery =
            inTransferQuery.filter('product_id', 'in', productIds);
      }

      final inRes = await inTransferQuery;
      for (var item in inRes as List) {
        final pId = item['product_id'].toString();
        if (stockAtDate.containsKey(pId)) {
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          stockAtDate[pId] = stockAtDate[pId]! - qty;
        }
      }
    }

    return stockAtDate;
  }

  // --- Helper to get Invoice Type IDs by Prefix ---
  Future<List<int>> _getInvoiceTypeIds(String prefix,
      {int? organizationId}) async {
    var query = _supabase.from('omtbl_invoice_types').select('id_invoice_type');
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    final res = await query.eq('for_used', prefix);
    return (res as List).map((e) => e['id_invoice_type'] as int).toList();
  }

  // --- Helper to resolve report dates from financial session if not provided ---
  Future<Map<String, DateTime>> _resolveDates({
    required int organizationId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (startDate != null && endDate != null) {
      return {'start': startDate, 'end': endDate};
    }

    final res = await _supabase
        .from('omtbl_financial_sessions')
        .select('start_date, end_date')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .maybeSingle();

    if (res == null) {
      // If we can't find the session, we might be in trouble, but let's fallback to current month
      final now = DateTime.now();
      return {
        'start': startDate ?? DateTime(now.year, now.month, 1),
        'end': endDate ?? DateTime(now.year, now.month + 1, 0),
      };
    }

    return {
      'start': startDate ?? DateTime.parse(res['start_date']),
      'end': endDate ?? DateTime.parse(res['end_date']),
    };
  }

  // --- Gross Sales ---

  @override
  Future<Map<String, dynamic>> getGrossSalesSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    if (typeIds.isEmpty) return {'total_gross_sales': 0.0, 'invoice_count': 0};

    var query = _supabase
        .from('omtbl_invoices')
        .select('total_amount')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', typeIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    final list = res as List;

    final count = list.length;
    final total = list.fold(
        0.0,
        (sum, item) =>
            sum + ((item['total_amount'] as num?)?.toDouble() ?? 0.0));

    return {
      'total_invoices': count,
      'total_gross_sales': total,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossSalesDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    if (typeIds.isEmpty) {
      return [];
    }

    var query = _supabase
        .from('omtbl_invoices')
        .select('*, omtbl_businesspartners(name)')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', typeIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    return (res as List).map((e) {
      final bp = e['omtbl_businesspartners'];
      return {
        'invoice_date': e['invoice_date'],
        'invoice_number': e['invoice_number'],
        'customer_name': bp != null ? bp['name'] : 'Unknown',
        'gross_amount': e['total_amount'],
        'status': e['status'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossSalesByCustomer({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final details = await getGrossSalesDetails(
      organizationId: organizationId,
      storeId: storeId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in details) {
      final name = item['customer_name'] as String;
      final amt = (item['gross_amount'] as num).toDouble();

      if (!grouped.containsKey(name)) {
        grouped[name] = {
          'customer_name': name,
          'invoice_count': 0,
          'total_sales_amount': 0.0
        };
      }

      grouped[name]!['invoice_count'] =
          (grouped[name]!['invoice_count'] as int) + 1;
      grouped[name]!['total_sales_amount'] =
          (grouped[name]!['total_sales_amount'] as double) + amt;
    }

    final result = grouped.values.toList();
    result.sort((a, b) => (b['total_sales_amount'] as double)
        .compareTo(a['total_sales_amount'] as double));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossSalesByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    if (typeIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoice_items')
        .select(
            '*, omtbl_invoices!inner(*), omtbl_products!inner(*, omtbl_categories(*), omtbl_units_of_measure(*))')
        .eq('omtbl_invoices.organization_id', organizationId)
        .eq('omtbl_invoices.syear', sYear)
        .filter('omtbl_invoices.id_invoice_type', 'in', typeIds)
        .gte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(start))
        .lte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) {
      query = query.eq('omtbl_invoices.store_id', storeId);
    }

    if (categoryId != null) {
      query = query.eq('omtbl_products.category_id', categoryId);
    }

    final res = await query as List;

    // Fetch product IDs to calculate opening stocks for
    final List<String> pIds =
        res.map((e) => e['product_id'].toString()).toSet().toList();
    final Map<String, double> openingStocks = pIds.isEmpty
        ? {}
        : await _calculateOpeningStocks(
            organizationId: organizationId,
            storeId: storeId,
            beforeDate: start,
            productIds: pIds,
          );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in res) {
      final product = item['omtbl_products'];
      final cat = product['omtbl_categories'];
      final uom = product['omtbl_units_of_measure'];

      final pId = product['id'].toString();
      final pName = product['name'];
      final cName =
          cat != null ? cat['category'] ?? cat['name'] : 'Uncategorized';
      final uName = uom != null ? uom['unit_symbol'] : '';

      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;

      if (!grouped.containsKey(pId)) {
        grouped[pId] = {
          'product_name': pName,
          'category_name': cName,
          'uom': uName,
          'opening_stock': openingStocks[pId] ?? 0.0,
          'total_qty_sold': 0.0,
          'total_sales_value': 0.0,
        };
      }

      grouped[pId]!['total_qty_sold'] =
          (grouped[pId]!['total_qty_sold'] as double) + qty;
      grouped[pId]!['total_sales_value'] =
          (grouped[pId]!['total_sales_value'] as double) + total;
    }

    final result = grouped.values.toList();
    result.sort((a, b) => (b['total_sales_value'] as double)
        .compareTo(a['total_sales_value'] as double));
    return result;
  }
  // --- Net Sales ---

  @override
  Future<Map<String, dynamic>> getNetSalesSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final srIds =
        await _getInvoiceTypeIds('SR', organizationId: organizationId);
    final allIds = [...siIds, ...srIds];

    if (allIds.isEmpty) {
      return {'net_sales': 0.0, 'invoice_count': 0};
    }

    var query = _supabase
        .from('omtbl_invoices')
        .select('*')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', allIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    final list = res as List;

    double gross = 0.0;
    double returns = 0.0;

    for (var item in list) {
      final typeId = item['id_invoice_type'] as int;
      final amt = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

      if (siIds.contains(typeId)) {
        gross += amt;
      } else if (srIds.contains(typeId)) {
        returns += amt;
      }
    }

    return {
      'gross_sales': gross,
      'sales_returns': returns,
      'net_sales': gross - returns,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getNetSalesDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final srIds =
        await _getInvoiceTypeIds('SR', organizationId: organizationId);
    final allIds = [...siIds, ...srIds];

    if (allIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoices')
        .select('*, omtbl_businesspartners(name)')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', allIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    return (res as List).map((e) {
      final bp = e['omtbl_businesspartners'];
      final typeId = e['id_invoice_type'] as int;
      final isReturn = srIds.contains(typeId);
      final amt = (e['total_amount'] as num?)?.toDouble() ?? 0.0;

      return {
        'invoice_date': e['invoice_date'],
        'invoice_number': e['invoice_number'],
        'type': isReturn ? 'SR' : 'SI',
        'customer_name': bp != null ? bp['name'] : 'Unknown',
        'net_amount': isReturn
            ? -amt
            : amt, // Negative for display/sorting context if needed
        'gross_amount': amt, // Original amount
        'status': e['status'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getNetSalesByCustomer({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final details = await getNetSalesDetails(
      organizationId: organizationId,
      storeId: storeId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    // Note: net_amount is already signed in details method above

    final Map<String, double> grouped = {};

    for (var item in details) {
      final name = item['customer_name'] as String;
      final netAmt = (item['net_amount'] as num).toDouble();

      if (!grouped.containsKey(name)) {
        grouped[name] = 0.0;
      }
      grouped[name] = grouped[name]! + netAmt;
    }

    final result = grouped.entries
        .map((e) => {
              'customer_name': e.key,
              'net_purchase_amount': e
                  .value, // Reusing field name style from request? Or 'net_sales_amount'
              'net_sales_amount': e.value,
            })
        .toList();

    result.sort((a, b) => (b['net_sales_amount'] as double)
        .compareTo(a['net_sales_amount'] as double));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getNetSalesByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final srIds =
        await _getInvoiceTypeIds('SR', organizationId: organizationId);
    final allIds = [...siIds, ...srIds];

    if (allIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoice_items')
        .select(
            '*, omtbl_invoices!inner(*), omtbl_products!inner(*, omtbl_units_of_measure(*))')
        .eq('omtbl_invoices.organization_id', organizationId)
        .eq('omtbl_invoices.syear', sYear)
        .filter('omtbl_invoices.id_invoice_type', 'in', allIds)
        .gte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(start))
        .lte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) {
      query = query.eq('omtbl_invoices.store_id', storeId);
    }

    final res = await query as List;

    // Fetch product IDs to calculate opening stocks for
    final List<String> pIds =
        res.map((e) => e['product_id'].toString()).toSet().toList();
    final Map<String, double> openingStocks = pIds.isEmpty
        ? {}
        : await _calculateOpeningStocks(
            organizationId: organizationId,
            storeId: storeId,
            beforeDate: start,
            productIds: pIds,
          );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in res) {
      final inv = item['omtbl_invoices'];
      final product = item['omtbl_products'];
      final uom = product['omtbl_units_of_measure'];

      final typeId = inv['id_invoice_type'] as int;
      final isReturn = srIds.contains(typeId);

      final pId = product['id'].toString();
      final pName = product['name'];
      final uName = uom != null ? uom['unit_symbol'] : '';

      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;

      if (!grouped.containsKey(pId)) {
        grouped[pId] = {
          'product_name': pName,
          'uom': uName,
          'opening_stock': openingStocks[pId] ?? 0.0,
          'net_qty': 0.0,
          'net_amount': 0.0,
        };
      }

      if (isReturn) {
        grouped[pId]!['net_qty'] = (grouped[pId]!['net_qty'] as double) - qty;
        grouped[pId]!['net_amount'] =
            (grouped[pId]!['net_amount'] as double) - total;
      } else {
        grouped[pId]!['net_qty'] = (grouped[pId]!['net_qty'] as double) + qty;
        grouped[pId]!['net_amount'] =
            (grouped[pId]!['net_amount'] as double) + total;
      }
    }

    final result = grouped.values.toList();
    result.sort((a, b) =>
        (b['net_amount'] as double).compareTo(a['net_amount'] as double));
    return result;
  }

  // --- Gross Purchase ---

  @override
  Future<Map<String, dynamic>> getGrossPurchaseSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    if (typeIds.isEmpty) {
      return {'total_gross_purchase': 0.0, 'invoice_count': 0};
    }

    var query = _supabase
        .from('omtbl_invoices')
        .select('total_amount')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', typeIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    final list = res as List;

    final count = list.length;
    final total = list.fold(
        0.0,
        (sum, item) =>
            sum + ((item['total_amount'] as num?)?.toDouble() ?? 0.0));

    return {
      'total_invoices': count,
      'total_gross_purchase': total,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossPurchaseDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    if (typeIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoices')
        .select('*, omtbl_businesspartners(name)')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', typeIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    return (res as List).map((e) {
      final bp = e['omtbl_businesspartners'];
      return {
        'invoice_date': e['invoice_date'],
        'invoice_number': e['invoice_number'],
        'vendor_name': bp != null ? bp['name'] : 'Unknown', // Vendor
        'gross_amount': e['total_amount'],
        'status': e['status'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossPurchaseByVendor({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final details = await getGrossPurchaseDetails(
      organizationId: organizationId,
      storeId: storeId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in details) {
      final name = item['vendor_name'] as String;
      final amt = (item['gross_amount'] as num).toDouble();

      if (!grouped.containsKey(name)) {
        grouped[name] = {
          'vendor_name': name,
          'invoice_count': 0,
          'total_purchase_amount': 0.0
        };
      }

      grouped[name]!['invoice_count'] =
          (grouped[name]!['invoice_count'] as int) + 1;
      grouped[name]!['total_purchase_amount'] =
          (grouped[name]!['total_purchase_amount'] as double) + amt;
    }

    final result = grouped.values.toList();
    result.sort((a, b) => (b['total_purchase_amount'] as double)
        .compareTo(a['total_purchase_amount'] as double));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getGrossPurchaseByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final typeIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    if (typeIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoice_items')
        .select(
            '*, omtbl_invoices!inner(*), omtbl_products!inner(*, omtbl_categories(*), omtbl_units_of_measure(*))')
        .eq('omtbl_invoices.organization_id', organizationId)
        .eq('omtbl_invoices.syear', sYear)
        .filter('omtbl_invoices.id_invoice_type', 'in', typeIds)
        .gte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(start))
        .lte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) {
      query = query.eq('omtbl_invoices.store_id', storeId);
    }
    if (categoryId != null) {
      query = query.eq('omtbl_products.category_id', categoryId);
    }

    final res = await query as List;

    // Fetch product IDs to calculate opening stocks for
    final List<String> pIds =
        res.map((e) => e['product_id'].toString()).toSet().toList();
    final Map<String, double> openingStocks = pIds.isEmpty
        ? {}
        : await _calculateOpeningStocks(
            organizationId: organizationId,
            storeId: storeId,
            beforeDate: start,
            productIds: pIds,
          );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in res) {
      final product = item['omtbl_products'];
      final cat = product['omtbl_categories'];
      final uom = product['omtbl_units_of_measure'];

      final pId = product['id'].toString();
      final pName = product['name'];
      final cName =
          cat != null ? cat['category'] ?? cat['name'] : 'Uncategorized';
      final uName = uom != null ? uom['unit_symbol'] : '';

      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;

      if (!grouped.containsKey(pId)) {
        grouped[pId] = {
          'product_name': pName,
          'category_name': cName,
          'uom': uName,
          'opening_stock': openingStocks[pId] ?? 0.0,
          'purchased_qty': 0.0,
          'purchased_value': 0.0,
        };
      }

      grouped[pId]!['purchased_qty'] =
          (grouped[pId]!['purchased_qty'] as double) + qty;
      grouped[pId]!['purchased_value'] =
          (grouped[pId]!['purchased_value'] as double) + total;
    }

    final result = grouped.values.toList();
    result.sort((a, b) => (b['purchased_value'] as double)
        .compareTo(a['purchased_value'] as double));
    return result;
  }

  // --- Net Purchase ---

  @override
  Future<Map<String, dynamic>> getNetPurchaseSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final piIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    final prIds =
        await _getInvoiceTypeIds('PR', organizationId: organizationId);
    final allIds = [...piIds, ...prIds];

    if (allIds.isEmpty) {
      return {'net_purchase': 0.0, 'invoice_count': 0};
    }

    var query = _supabase
        .from('omtbl_invoices')
        .select('*')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', allIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query as List;
    double gross = 0.0;
    double returns = 0.0;

    for (var item in res) {
      final typeId = item['id_invoice_type'] as int;
      final amt = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

      if (piIds.contains(typeId)) {
        gross += amt;
      } else if (prIds.contains(typeId)) {
        returns += amt;
      }
    }

    return {
      'gross_purchase': gross,
      'purchase_returns': returns,
      'net_purchase': gross - returns,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getNetPurchaseDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final piIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    final prIds =
        await _getInvoiceTypeIds('PR', organizationId: organizationId);
    final allIds = [...piIds, ...prIds];

    if (allIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoices')
        .select('*, omtbl_businesspartners(name)')
        .eq('organization_id', organizationId)
        .eq('syear', sYear)
        .filter('id_invoice_type', 'in', allIds)
        .gte('invoice_date', DateFormat('yyyy-MM-dd').format(start))
        .lte('invoice_date', DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) query = query.eq('store_id', storeId);

    final res = await query.order('invoice_date', ascending: false);
    return (res as List).map((e) {
      final bp = e['omtbl_businesspartners'];
      final typeId = e['id_invoice_type'] as int;
      final isReturn = prIds.contains(typeId);
      final amt = (e['total_amount'] as num?)?.toDouble() ?? 0.0;

      return {
        'invoice_date': e['invoice_date'],
        'invoice_number': e['invoice_number'],
        'type': isReturn ? 'PR' : 'PI',
        'vendor_name': bp != null ? bp['name'] : 'Unknown',
        'net_amount': isReturn ? -amt : amt,
        'gross_amount': amt,
        'status': e['status'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getNetPurchaseByVendor({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final details = await getNetPurchaseDetails(
      organizationId: organizationId,
      storeId: storeId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, double> grouped = {};

    for (var item in details) {
      final name = item['vendor_name'] as String;
      final netAmt = (item['net_amount'] as num).toDouble();

      if (!grouped.containsKey(name)) {
        grouped[name] = 0.0;
      }
      grouped[name] = grouped[name]! + netAmt;
    }

    final result = grouped.entries
        .map((e) => {
              'vendor_name': e.key,
              'net_purchase_amount': e.value,
            })
        .toList();

    result.sort((a, b) => (b['net_purchase_amount'] as double)
        .compareTo(a['net_purchase_amount'] as double));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getNetPurchaseByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dates = await _resolveDates(
      organizationId: organizationId,
      sYear: sYear,
      startDate: startDate,
      endDate: endDate,
    );
    final start = dates['start']!;
    final end = dates['end']!;

    final piIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    final prIds =
        await _getInvoiceTypeIds('PR', organizationId: organizationId);
    final allIds = [...piIds, ...prIds];

    if (allIds.isEmpty) return [];

    var query = _supabase
        .from('omtbl_invoice_items')
        .select(
            '*, omtbl_invoices!inner(*), omtbl_products!inner(*, omtbl_units_of_measure(*))')
        .eq('omtbl_invoices.organization_id', organizationId)
        .eq('omtbl_invoices.syear', sYear)
        .filter('omtbl_invoices.id_invoice_type', 'in', allIds)
        .gte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(start))
        .lte('omtbl_invoices.invoice_date',
            DateFormat('yyyy-MM-dd').format(end));

    if (storeId != null) {
      query = query.eq('omtbl_invoices.store_id', storeId);
    }

    final res = await query as List;

    // Fetch product IDs to calculate opening stocks for
    final List<String> pIds =
        res.map((e) => e['product_id'].toString()).toSet().toList();
    final Map<String, double> openingStocks = pIds.isEmpty
        ? {}
        : await _calculateOpeningStocks(
            organizationId: organizationId,
            storeId: storeId,
            beforeDate: start,
            productIds: pIds,
          );

    final Map<String, Map<String, dynamic>> grouped = {};

    for (var item in res) {
      final inv = item['omtbl_invoices'];
      final product = item['omtbl_products'];
      final uom = product['omtbl_units_of_measure'];

      final typeId = inv['id_invoice_type'] as int;
      final isReturn = prIds.contains(typeId);

      final pId = product['id'].toString();
      final pName = product['name'];
      final uName = uom != null ? uom['unit_symbol'] : '';

      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;

      if (!grouped.containsKey(pId)) {
        grouped[pId] = {
          'product_name': pName,
          'uom': uName,
          'opening_stock': openingStocks[pId] ?? 0.0,
          'net_qty': 0.0,
          'net_amount': 0.0,
        };
      }

      if (isReturn) {
        grouped[pId]!['net_qty'] = (grouped[pId]!['net_qty'] as double) - qty;
        grouped[pId]!['net_amount'] =
            (grouped[pId]!['net_amount'] as double) - total;
      } else {
        grouped[pId]!['net_qty'] = (grouped[pId]!['net_qty'] as double) + qty;
        grouped[pId]!['net_amount'] =
            (grouped[pId]!['net_amount'] as double) + total;
      }
    }

    final result = grouped.values.toList();
    result.sort((a, b) =>
        (b['net_amount'] as double).compareTo(a['net_amount'] as double));
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getReceivableReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final sirIds =
        await _getInvoiceTypeIds('SIR', organizationId: organizationId);
    final allIds = [...siIds, ...sirIds];
    if (allIds.isEmpty) return [];

    String sql = '''
      SELECT 
        i.business_partner_id,
        MAX(COALESCE(bp.name, 'Unknown Customer')) as customer_name,
        SUM(COALESCE(i.total_amount, 0)) as total_amount,
        SUM(COALESCE(i.paid_amount, 0)) as paid_amount,
        SUM(COALESCE(i.total_amount, 0) - COALESCE(i.paid_amount, 0)) as outstanding
      FROM local_invoices i
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE i.organization_id = ?
        AND i.id_invoice_type IN (${List.filled(allIds.length, '?').join(',')})
        AND i.syear = ?
    ''';
    List<dynamic> args = [organizationId, ...allIds, sYear];

    if (storeId != null) {
      sql += ' AND i.store_id = ?';
      args.add(storeId);
    }
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY i.business_partner_id ORDER BY outstanding DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerBalanceReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    final sirIds =
        await _getInvoiceTypeIds('SIR', organizationId: organizationId);
    final allIds = [...siIds, ...sirIds];
    if (allIds.isEmpty) return [];

    String sql = '''
      SELECT 
        i.business_partner_id,
        MAX(COALESCE(bp.name, 'Unknown Customer')) as customer_name,
        SUM(CASE WHEN i.id_invoice_type IN (${List.filled(siIds.length, '?').join(',')}) THEN COALESCE(i.total_amount, 0) ELSE 0 END) as sales,
        SUM(CASE WHEN i.id_invoice_type IN (${List.filled(sirIds.length, '?').join(',')}) THEN COALESCE(i.total_amount, 0) ELSE 0 END) as returns,
        SUM(COALESCE(i.paid_amount, 0)) as payments,
        (SUM(CASE WHEN i.id_invoice_type IN (${List.filled(siIds.length, '?').join(',')}) THEN COALESCE(i.total_amount, 0) ELSE 0 END)
          - SUM(CASE WHEN i.id_invoice_type IN (${List.filled(sirIds.length, '?').join(',')}) THEN COALESCE(i.total_amount, 0) ELSE 0 END)
          - SUM(COALESCE(i.paid_amount, 0))) as balance
      FROM local_invoices i
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE i.organization_id = ?
        AND i.syear = ?
    ''';
    List<dynamic> args = [
      organizationId,
      sYear,
      ...siIds,
      ...sirIds,
      ...siIds,
      ...sirIds,
      ...siIds,
      ...sirIds,
    ];

    if (storeId != null) {
      sql += ' AND i.store_id = ?';
      args.add(storeId);
    }
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY i.business_partner_id ORDER BY balance DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getBrandWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    if (siIds.isEmpty) return [];

    String sql = '''
      SELECT 
        b.id as brand_id,
        MAX(COALESCE(b.name, 'Unknown')) as brand_name,
        SUM(COALESCE(ii.quantity, 0)) as total_quantity,
        SUM(COALESCE(ii.total, 0)) as total_amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      LEFT JOIN local_brands b ON p.brand_id = b.id
      WHERE i.organization_id = ?
        AND i.id_invoice_type IN (${List.filled(siIds.length, '?').join(',')})
        AND i.syear = ?
    ''';
    List<dynamic> args = [organizationId, ...siIds, sYear];

    if (storeId != null) {
      sql += ' AND i.store_id = ?';
      args.add(storeId);
    }
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY b.id ORDER BY total_amount DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getTypeWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final siIds =
        await _getInvoiceTypeIds('SI', organizationId: organizationId);
    if (siIds.isEmpty) return [];

    String sql = '''
      SELECT 
        pt.id as product_type_id,
        MAX(COALESCE(pt.name, 'Unknown')) as type_name,
        SUM(COALESCE(ii.quantity, 0)) as total_quantity,
        SUM(COALESCE(ii.total, 0)) as total_amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      LEFT JOIN local_product_types pt ON p.product_type_id = pt.id
      WHERE i.organization_id = ?
        AND i.id_invoice_type IN (${List.filled(siIds.length, '?').join(',')})
        AND i.syear = ?
    ''';
    List<dynamic> args = [organizationId, ...siIds, sYear];

    if (storeId != null) {
      sql += ' AND i.store_id = ?';
      args.add(storeId);
    }
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY pt.id ORDER BY total_amount DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getProductListReport({
    required int organizationId,
    int? storeId,
  }) async {
    final db = await _dbHelper.database;

    String sql = '''
      SELECT 
        p.id,
        p.name,
        p.sku,
        MAX(COALESCE(c.category, c.name, 'Uncategorized')) as category_name,
        MAX(COALESCE(b.name, '')) as brand_name,
        MAX(COALESCE(pt.name, '')) as type_name,
        p.stock_qty,
        p.rate
      FROM local_products p
      LEFT JOIN local_categories c ON p.category_id = c.id
      LEFT JOIN local_brands b ON p.brand_id = b.id
      LEFT JOIN local_product_types pt ON p.product_type_id = pt.id
      WHERE p.organization_id = ?
    ''';
    List<dynamic> args = [organizationId];

    if (storeId != null) {
      sql += ' AND p.store_id = ?';
      args.add(storeId);
    }

    sql += ' GROUP BY p.id ORDER BY p.name ASC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getSupplierWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    final piIds =
        await _getInvoiceTypeIds('PI', organizationId: organizationId);
    if (piIds.isEmpty) return [];

    String sql = '''
      SELECT 
        i.business_partner_id,
        MAX(COALESCE(bp.name, 'Unknown Vendor')) as vendor_name,
        COUNT(i.id) as total_invoices,
        SUM(COALESCE(i.total_amount, 0)) as total_amount
      FROM local_invoices i
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE i.organization_id = ?
        AND i.id_invoice_type IN (${List.filled(piIds.length, '?').join(',')})
        AND i.syear = ?
    ''';
    List<dynamic> args = [organizationId, ...piIds, sYear];

    if (storeId != null) {
      sql += ' AND i.store_id = ?';
      args.add(storeId);
    }
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }

    sql += ' GROUP BY i.business_partner_id ORDER BY total_amount DESC';

    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getInventoryMovements({
    required int organizationId,
    int? storeId,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
  }) async {
    try {
      dynamic query = _supabase
          .from('omtbl_inventory_movements')
          .select()
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);

      if (storeId != null) {
        query = (query as dynamic).eq('store_id', storeId);
      }
      if (startDate != null) {
        query = (query as dynamic).gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = (query as dynamic).lte('created_at', endDate.toIso8601String());
      }
      if (productId != null) {
        query = (query as dynamic).eq('product_id', productId);
      }

      final response = await (query as dynamic).limit(1000);
      return (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('ReportRepository: getInventoryMovements failed: $e');
      return [];
    }
  }
}
