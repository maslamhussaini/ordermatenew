import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/core/services/pdf_report_service.dart';

class SalesInvoiceItemWiseReportScreen extends ConsumerStatefulWidget {
  const SalesInvoiceItemWiseReportScreen({super.key});

  @override
  ConsumerState<SalesInvoiceItemWiseReportScreen> createState() =>
      _SalesInvoiceItemWiseReportScreenState();
}

class _SalesInvoiceItemWiseReportScreenState
    extends ConsumerState<SalesInvoiceItemWiseReportScreen> {
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
      if (orgId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an organization')));
        }
        return;
      }
      final results = await repo.getSalesDetailsByProduct(
        startDate: _startDate,
        endDate: _endDate,
        organizationId: orgId,
        type: 'SI',
      );
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

  Future<void> _printPdf() async {
    final settings = ref.read(settingsProvider).pdfSettings;
    final orgState = ref.read(organizationProvider);
    final columns = [
      const ReportColumn(header: 'Product', dataKey: 'product_name'),
      const ReportColumn(header: 'Invoice', dataKey: 'invoice_number'),
      const ReportColumn(header: 'Date', dataKey: 'invoice_date'),
      const ReportColumn(header: 'Customer', dataKey: 'customer_name'),
      const ReportColumn(header: 'Qty', dataKey: 'quantity', isNumeric: true),
      const ReportColumn(header: 'Amount', dataKey: 'amount', isNumeric: true),
    ];
    final service = PdfReportService();
    final bytes = await service.generateReport(
      title: 'Sales Invoice - Item Wise',
      columns: columns,
      data: _data,
      settings: settings,
      organizationName: orgState.selectedOrganization?.name,
      storeName: orgState.selectedStore?.name,
      storeAddress: orgState.selectedStore?.location ?? orgState.selectedStore?.city,
      storePhone: orgState.selectedStore?.phone,
      totalKeys: ['quantity', 'amount'],
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'SalesInvoiceItemWise_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Sales Invoice - Item Wise',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(onPressed: _printPdf, icon: const Icon(Icons.print)),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? const Center(
                        child: Text("No records found for the selected period."))
                    : _buildTable(),
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
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
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

  Widget _buildTable() {
    final currency =
        ref.read(organizationProvider).selectedStore?.storeDefaultCurrency ?? 'USD';
    double totalQty = 0;
    double totalAmount = 0;
    for (var item in _data) {
      totalQty += (item['quantity'] as num?)?.toDouble() ?? 0.0;
      totalAmount += (item['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Qty'), numeric: true),
              DataColumn(label: Text('Amount'), numeric: true),
            ],
            rows: [
              ..._data.map((item) {
                final rawDate = item['invoice_date'];
                DateTime date;
                if (rawDate is int) {
                  date = DateTime.fromMillisecondsSinceEpoch(rawDate);
                } else if (rawDate is String) {
                  date = DateTime.tryParse(rawDate) ?? DateTime.now();
                } else {
                  date = DateTime.now();
                }
                return DataRow(cells: [
                  DataCell(Text(item['product_name']?.toString() ?? '')),
                  DataCell(Text(item['invoice_number']?.toString() ?? '')),
                  DataCell(Text(DateFormat('MMM dd').format(date))),
                  DataCell(Text(item['customer_name']?.toString() ?? '')),
                  DataCell(Text(
                      ((item['quantity'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0))),
                  DataCell(Text(
                      '$currency ${((item['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                ]);
              }),
              DataRow(
                color: WidgetStateProperty.all(Colors.indigo.shade50),
                cells: [
                  const DataCell(Text('TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text(totalQty.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('$currency ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
