// lib/features/reports/presentation/screens/sales_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';

import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  final String groupBy; // product, customer
  final String invoiceType; // SI, SIR
  const SalesReportScreen(
      {super.key, required this.groupBy, required this.invoiceType});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;

      List<Map<String, dynamic>> results;

      if (widget.groupBy == 'product') {
        // Use detailed view for products
        results = await repo.getSalesDetailsByProduct(
          startDate: _startDate,
          endDate: _endDate,
          organizationId: orgId,
          type: widget.invoiceType,
        );
      } else {
        results = await repo.getSalesByCustomer(
          startDate: _startDate,
          endDate: _endDate,
          organizationId: orgId,
          type: widget.invoiceType,
        );
      }

      if (mounted) {
        setState(() {
          _data = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title =
        widget.invoiceType == 'SI' ? "Sales Report" : "Returns Report";
    title +=
        widget.groupBy == 'product' ? " (Product-wise)" : " (Customer-wise)";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? const Center(
                        child:
                            Text("No records found for the selected period."))
                    : _buildReportTableView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildDatePicker(
              label: 'Start Date',
              value: _startDate,
              onChanged: (date) {
                setState(() => _startDate = date);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDatePicker(
              label: 'End Date',
              value: _endDate,
              onChanged: (date) {
                setState(() => _endDate = date);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.indigo),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      {required String label,
      required DateTime value,
      required ValueChanged<DateTime> onChanged}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onChanged(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text(DateFormat('MMM dd, yyyy').format(value),
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTableView() {
    final currency =
        ref.watch(organizationProvider).selectedStore?.storeDefaultCurrency ??
            'USD';

    if (widget.groupBy == 'product') {
      // Group by Product Name
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var item in _data) {
        String key = item['product_name'] ?? 'Unknown Product';
        if (!grouped.containsKey(key)) grouped[key] = [];
        grouped[key]!.add(item);
      }

      return ListView.builder(
        itemCount: grouped.keys.length,
        itemBuilder: (context, index) {
          final product = grouped.keys.elementAt(index);
          final items = grouped[product]!;

          double totalAmt = 0;
          double totalQty = 0;
          for (var i in items) {
            totalAmt += (i['amount'] as num?)?.toDouble() ?? 0.0;
            totalQty += (i['quantity'] as num?)?.toDouble() ?? 0.0;
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ExpansionTile(
              title: Text(product,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Sold: $totalQty"),
              trailing: Text(
                "$currency ${totalAmt.toStringAsFixed(2)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16),
              ),
              children: items.map((item) {
                final rawDate = item['invoice_date'];
                final DateTime date;
                if (rawDate is int) {
                  date = DateTime.fromMillisecondsSinceEpoch(rawDate);
                } else if (rawDate is String) {
                  date = DateTime.parse(rawDate);
                } else {
                  date = DateTime.now();
                }

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  title: Text(
                      "${item['invoice_number']} • ${DateFormat('MMM dd').format(date)}"),
                  subtitle: Text(item['customer_name'] ?? ''),
                  trailing: Text(
                      "$currency ${((item['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}"),
                );
              }).toList(),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: _data.length,
        itemBuilder: (context, index) {
          final item = _data[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(item['customer_name'] ?? 'Unknown Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${item['total_invoices']} Invoices"),
              trailing: Text(
                "$currency ${((item['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                    fontSize: 16),
              ),
            ),
          );
        },
      );
    }
  }
}
