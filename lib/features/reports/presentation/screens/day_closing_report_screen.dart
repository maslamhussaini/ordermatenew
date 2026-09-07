import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:intl/intl.dart';

class DayClosingReportScreen extends ConsumerStatefulWidget {
  const DayClosingReportScreen({super.key});

  @override
  ConsumerState<DayClosingReportScreen> createState() =>
      _DayClosingReportScreenState();
}

class _DayClosingReportScreenState
    extends ConsumerState<DayClosingReportScreen> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedOrganizationId;
  int? _selectedStoreId;
  int? _selectedSyear;
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];

  // Metadata for dropdowns (fetched on init)
  // We can just use the provider's current context, but technically "Admin" might want to pick ANY org.
  // For now, let's stick to the current user's available context or provider lists.

  @override
  void initState() {
    super.initState();
    // Defer the dialog until after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showParameterDialog();
    });
  }

  void _showParameterDialog() async {
    // Pre-fill with current context
    final orgState = ref.read(organizationProvider);
    _selectedOrganizationId = orgState.selectedOrganization?.id;
    _selectedStoreId = orgState.selectedStore?.id;
    // Simple logic for financial year: assume current year
    _selectedSyear = DateTime.now().year;
    // Wait, your system uses 2025 for "2025-2026"? Or purely calendar year?
    // Checking previous queries: "syear": 2025. It seems to be an integer.

    await showDialog(
      context: context,
      barrierDismissible: false, // Force them to pick
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Day Closing Report Parameters'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Organization (Read Only if not Super Admin, but let's show it)
                    if (orgState.organizations.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: _selectedOrganizationId,
                        decoration:
                            const InputDecoration(labelText: 'Organization'),
                        items: orgState.organizations.map((org) {
                          return DropdownMenuItem<int>(
                            value: org.id,
                            child: Text(org.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => _selectedOrganizationId = val);
                        },
                      ),
                    const SizedBox(height: 16),
                    // Store
                    DropdownButtonFormField<int>(
                      initialValue: _selectedStoreId,
                      decoration: const InputDecoration(labelText: 'Store'),
                      items: orgState.stores.map((store) {
                        return DropdownMenuItem<int>(
                          value: store.id,
                          child: Text(store.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => _selectedStoreId = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Year
                    TextFormField(
                      initialValue: _selectedSyear.toString(),
                      decoration: const InputDecoration(
                          labelText: 'Financial Year (syear)'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        _selectedSyear = int.tryParse(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Picker
                    ListTile(
                      title: const Text('Report Date (As On)'),
                      subtitle:
                          Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    // Future: Salesman Dropdown
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to previous screen
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedOrganizationId != null &&
                        _selectedStoreId != null) {
                      Navigator.pop(context); // Close dialog
                      _fetchReport(); // Load data
                    }
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);

    // Format date for SQL
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // We'll execute a custom SQL func or raw query (via RPC or client if permitted)
    // Providing raw SQL here based on our earlier analysis
    // NOTE: RLS might block "omtbl_transactions" direct viewing if not configured correctly for "read".

    final query = '''
      WITH target_date AS (
        SELECT '$dateStr'::date as d, 
               $_selectedOrganizationId as org_id,
               $_selectedStoreId as store_id
      ),
      current_sales AS (
        SELECT 
            1 as sort_order,
            'Current Sales' as report_section,
            i.invoice_number as inv_no,
            i.invoice_date::text as txn_date,
            i.total_amount as bill_amount,
            
            -- Cash Received Today
            COALESCE(SUM(CASE 
                WHEN lower(t.description) LIKE '%cash%' OR lower(t.payment_mode) = 'cash' 
                THEN t.amount ELSE 0 
            END), 0) as cash,

            -- Cheque Received Today
            COALESCE(SUM(CASE 
                WHEN lower(t.description) LIKE '%cheque%' OR lower(t.payment_mode) = 'cheque' 
                THEN t.amount ELSE 0 
            END), 0) as cheque,

            -- Credit (Balance)
            (i.total_amount - COALESCE(SUM(t.amount), 0)) as credit_amount

        FROM omtbl_invoices i
        LEFT JOIN omtbl_transactions t 
            ON i.id = t.invoice_id 
            AND t.voucher_date = i.invoice_date
        WHERE i.invoice_date = (SELECT d FROM target_date)
        AND i.organization_id = (SELECT org_id FROM target_date)
        AND i.store_id = (SELECT store_id FROM target_date)
        GROUP BY i.id, i.invoice_number, i.invoice_date, i.total_amount
      ),
      prev_collections AS (
        SELECT 
            2 as sort_order,
            'Previous Bill Collection' as report_section,
            COALESCE(i.invoice_number, t.description) as inv_no,
            t.voucher_date::text as txn_date,
            COALESCE(i.total_amount, 0) as bill_amount,

            -- Cash Collection
            CASE 
                WHEN lower(t.description) LIKE '%cash%' OR lower(t.payment_mode) = 'cash' 
                THEN t.amount ELSE 0 
            END as cash,

            -- Cheque Collection
            CASE 
                WHEN lower(t.description) LIKE '%cheque%' OR lower(t.payment_mode) = 'cheque' 
                THEN t.amount ELSE 0 
            END as cheque,

            -- Credit Column (Balance of that invoice)
            CASE 
                WHEN i.id IS NOT NULL THEN (i.total_amount - i.paid_amount) 
                ELSE 0 
            END as credit_amount

        FROM omtbl_transactions t
        LEFT JOIN omtbl_invoices i ON t.invoice_id = i.id
        WHERE t.voucher_date = (SELECT d FROM target_date)
        AND t.organization_id = (SELECT org_id FROM target_date)
        AND t.store_id = (SELECT store_id FROM target_date)
        -- Exclude transactions that match Today's Invoices (already covered)
        AND (i.invoice_date < (SELECT d FROM target_date) OR i.id IS NULL)
        -- Filter for Receipts
        AND (
            t.voucher_number ILIKE 'CRV%' 
            OR t.description ILIKE '%Receive%' 
            OR t.status = 'posted' -- Broad filter if desc is missing
        )
      )
      SELECT * FROM current_sales
      UNION ALL
      SELECT * FROM prev_collections
      ORDER BY sort_order, inv_no;
    ''';

    try {
      // USING RPC "execute_sql" IF AVAILABLE?
      // USUALLY Frontend cannot run raw SQL.
      // DO WE HAVE A "rpc" function for arbitrary SQL? NO. That is dangerous.
      // WE MUST USE SUPABASE DART CLIENT OR A VIEW.

      // STRATEGY: Since we can't run RAW SQL from Flutter client (security risk),
      // We will fetch the raw data and process it in Dart.

      // 1. Fetch Invoices for today
      final invoicesRes = await SupabaseConfig.client
          .from('omtbl_invoices')
          .select('*, omtbl_transactions(*)')
          .eq('organization_id', _selectedOrganizationId!)
          .eq('store_id', _selectedStoreId!)
          .eq('invoice_date', dateStr);

      // 2. Fetch Transactions for today (Collections)
      final transactionsRes = await SupabaseConfig.client
          .from('omtbl_transactions')
          .select('*, omtbl_invoices(*)') // Get parent invoice if linked
          .eq('organization_id', _selectedOrganizationId!)
          .eq('store_id', _selectedStoreId!)
          .eq('voucher_date', dateStr);

      final List<Map<String, dynamic>> processedData = [];

      // PROCESS CURRENT SALES
      for (final inv in (invoicesRes as List)) {
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
        final txns = (inv['omtbl_transactions'] as List?) ?? [];

        // Filter transactions only for TODAY involved with this invoice
        // (Actually the query above fetched the invoice, so its transactions are all related to it.
        // But we only want the ones PAID TODAY).
        final todaysPayments =
            txns.where((t) => t['voucher_date'] == dateStr).toList();

        double cash = 0;
        double cheque = 0;

        for (final t in todaysPayments) {
          final desc = (t['description'] as String? ?? '').toLowerCase();
          final mode = (t['payment_mode'] as String? ?? '').toLowerCase();
          final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;

          if (desc.contains('cash') || mode == 'cash') {
            cash += amt;
          } else if (desc.contains('cheque') || mode == 'cheque') {
            cheque += amt;
          } else {
            // Fallback: Assume Cash if not specified? Or separate column?
            // For now, put in Cash
            cash += amt;
          }
        }

        // The "Credit" column in the report means "How much was NOT paid today" i.e. Debt Issued
        final paidToday = cash + cheque;
        final credit = total - paidToday;

        processedData.add({
          'section': 'Current Sales',
          'inv_no': inv['invoice_number'],
          'date': inv['invoice_date'],
          'bill_amount': total,
          'cash': cash,
          'cheque': cheque,
          'credit': credit,
        });
      }

      // PROCESS PREVIOUS COLLECTIONS
      for (final txn in (transactionsRes as List)) {
        // Check if this transaction is linked to an invoice created TODAY.
        // If so, skip it (already handled in Current Sales section).
        final linkedInvoice = txn['omtbl_invoices'];
        if (linkedInvoice != null && linkedInvoice['invoice_date'] == dateStr) {
          continue;
        }

        // Filter: Must be a receipt (Positive flow? OR specific types?)
        // Simple check: Look for "Receipt" patterns or presume 'CRV' voucher prefix
        final vNo = (txn['voucher_number'] as String? ?? '');
        final desc = (txn['description'] as String? ?? '').toLowerCase();
        // If it's a Sales Invoice voucher (SINV), it's a sale, but we handled sales via the Invoices table.
        // Transactions table usually contains the GL entries.
        // We want pure Receipts here.

        if (!vNo.contains('CRV') &&
            !desc.contains('recei') &&
            !desc.contains('payment')) {
          // Likely not a receipt we care about for this report
          // (Could be an expense, journal, etc.)
          continue;
        }

        final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
        double cash = 0;
        double cheque = 0;
        final mode = (txn['payment_mode'] as String? ?? '').toLowerCase();

        if (desc.contains('cash') || mode == 'cash') {
          cash = amount;
        } else if (desc.contains('cheque') || mode == 'cheque') {
          cheque = amount;
        } else {
          cash = amount; // Default
        }

        // For Previous collections, "Bill Amount" is just info.
        // "Credit" usually shows remaining balance of that customer/bill.
        final billAmount = (linkedInvoice != null)
            ? (linkedInvoice['total_amount'] as num).toDouble()
            : 0.0;
        final remainingBalance = (linkedInvoice != null)
            ? ((linkedInvoice['total_amount'] as num) -
                    (linkedInvoice['paid_amount'] as num))
                .toDouble()
            : 0.0;

        processedData.add({
          'section': 'Previous Bill Collection',
          'inv_no':
              linkedInvoice?['invoice_number'] ?? txn['description'] ?? 'Rcpt',
          'date': txn['voucher_date'],
          'bill_amount': billAmount, // Show original bill amount
          'cash': cash,
          'cheque': cheque,
          'credit': remainingBalance, // Show remaining active credit
        });
      }

      setState(() {
        _reportData = processedData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Report Generation Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Closing Report'),
        actions: [
          IconButton(
              onPressed: _showParameterDialog,
              icon: const Icon(Icons.filter_list)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportData.isEmpty
              ? const Center(
                  child: Text('No parameters selected or No Data found.'))
              : _buildReportTable(),
    );
  }

  Widget _buildReportTable() {
    // Separate Lists
    final sales =
        _reportData.where((d) => d['section'] == 'Current Sales').toList();
    final collections = _reportData
        .where((d) => d['section'] == 'Previous Bill Collection')
        .toList();

    // Totals
    double totalBill = 0;
    double totalCash = 0;
    double totalCheque = 0;
    double totalCredit = 0;

    for (var x in _reportData) {
      // Allow bill amount only from sales to be summed?
      // Usually "Total" row sums the cash/cheque collected.
      // The "Bill Amount" sum usually implies "Total Sales Volume" (Section 1 only).
      if (x['section'] == 'Current Sales') {
        totalBill += (x['bill_amount'] as num?)?.toDouble() ?? 0.0;
      }
      totalCash += (x['cash'] as num?)?.toDouble() ?? 0.0;
      totalCheque += (x['cheque'] as num?)?.toDouble() ?? 0.0;
      // Credit sum?
      // For sales: New debt issued.
      // For collections: Remaining debt? Mixing them is weird.
      // Let's sum "New Credit Issued" and "Remaining Collections" separately?
      // The image shows a single total line.
      // Usually: Total Cash In Hand = Sum(Cash).
      // Total Credit = Sum(Credit Issued in Sales).
      if (x['section'] == 'Current Sales') {
        totalCredit += (x['credit'] as num?)?.toDouble() ?? 0.0;
      } else {
        // For collections, do we add to credit? No, that's remaining balance.
        // Wait, the image writes "3500" in total credit.
        // Row 1: 2000 credit. Row 2: 0. Row 3: 1500 (Collection?).
        // 2000 + 1500 = 3500.
        // So "Credit" column in collection section means "Amount NOT collecting today"?
        // Or "Amount still pending"?
        // Just summing the visible column for now as per image logic.
        totalCredit += (x['credit'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            // Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.indigo.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day Closing Report',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                      'As On: ${DateFormat('dd-MMM-yyyy').format(_selectedDate)}'),
                  Text(
                      'Org: $_selectedOrganizationId | Store: $_selectedStoreId'),
                ],
              ),
            ),

            // Current Sales Table
            _buildSectionTitle('Current Sales'),
            _buildDataTable(sales),

            // Previous Collections Table
            _buildSectionTitle('Previous Bill Collection'),
            _buildDataTable(collections, hideHeader: true),

            const Divider(thickness: 2),

            // Grand Total
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('TOTAL',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(), // Empty space for inv/date
                  // We need to align these with columns.
                  // A simple Row spacer might not align perfectly with DataTable.
                  // Ideally we add a "Footer Row" to the DataTable or use a fixed width layout.
                  // For now, let's just show key summary.
                  _summaryBox('Sales', totalBill),
                  const SizedBox(width: 8),
                  _summaryBox('Cash', totalCash, color: Colors.green.shade100),
                  const SizedBox(width: 8),
                  _summaryBox('Cheque', totalCheque,
                      color: Colors.orange.shade100),
                  const SizedBox(width: 8),
                  _summaryBox('Credit', totalCredit,
                      color: Colors.red.shade100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> data,
      {bool hideHeader = false}) {
    if (data.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(16), child: Text('No records.'));
    }

    return DataTable(
      headingRowHeight: hideHeader ? 0 : 48,
      columns: const [
        DataColumn(label: Text('Inv No')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Bill Amount'), numeric: true),
        DataColumn(label: Text('Cash'), numeric: true),
        DataColumn(label: Text('Cheque'), numeric: true),
        DataColumn(label: Text('Credit'), numeric: true),
      ],
      rows: data.map((row) {
        return DataRow(cells: [
          DataCell(Text(row['inv_no'].toString())),
          DataCell(Text(row['date'].toString())),
          DataCell(Text(
              (row['bill_amount'] as num?)?.toDouble().toStringAsFixed(0) ??
                  '0')),
          DataCell(Text(
              (row['cash'] as num?)?.toDouble().toStringAsFixed(0) ?? '0')),
          DataCell(Text(
              (row['cheque'] as num?)?.toDouble().toStringAsFixed(0) ?? '0')),
          DataCell(Text(
              (row['credit'] as num?)?.toDouble().toStringAsFixed(0) ?? '0')),
        ]);
      }).toList(),
    );
  }

  Widget _summaryBox(String label, double value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
