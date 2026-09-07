import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/core/services/pdf_report_service.dart';

class NetSalesReportScreen extends ConsumerStatefulWidget {
  const NetSalesReportScreen({super.key});

  @override
  ConsumerState<NetSalesReportScreen> createState() =>
      _NetSalesReportScreenState();
}

class _NetSalesReportScreenState extends ConsumerState<NetSalesReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _details = [];
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
      final storeId = ref.read(organizationProvider).selectedStore?.id;
      final sYear = (ref.read(organizationProvider).selectedFinancialYear ??
          DateTime.now().year);

      final summary = await repo.getNetSalesSummary(
        organizationId: orgId,
        storeId: storeId,
        sYear: sYear,
        startDate: _startDate,
        endDate: _endDate,
      );
      final details = await repo.getNetSalesDetails(
        organizationId: orgId,
        storeId: storeId,
        sYear: sYear,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _details = details;
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
      const ReportColumn(header: 'Date', dataKey: 'invoice_date'),
      const ReportColumn(header: 'Invoice', dataKey: 'invoice_number'),
      const ReportColumn(header: 'Type', dataKey: 'type'),
      const ReportColumn(header: 'Customer', dataKey: 'customer_name'),
      const ReportColumn(header: 'Net Amount', dataKey: 'net_amount', isNumeric: true),
    ];
    final service = PdfReportService();
    final bytes = await service.generateReport(
      title: 'Net Sales Report',
      columns: columns,
      data: _details,
      settings: settings,
      organizationName: orgState.selectedOrganization?.name,
      storeName: orgState.selectedStore?.name,
      storeAddress: orgState.selectedStore?.location ?? orgState.selectedStore?.city,
      storePhone: orgState.selectedStore?.phone,
      totalKeys: ['net_amount'],
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'NetSales_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Net Sales Report',
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
                : _details.isEmpty
                    ? const Center(
                        child: Text("No records found for the selected period."))
                    : _buildBody(),
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

  Widget _buildBody() {
    final currency =
        ref.read(organizationProvider).selectedStore?.storeDefaultCurrency ?? 'USD';
    final gross = (_summary['gross_sales'] as num?)?.toDouble() ?? 0.0;
    final returns = (_summary['sales_returns'] as num?)?.toDouble() ?? 0.0;
    final net = (_summary['net_sales'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryCard('Gross Sales', '$currency ${gross.toStringAsFixed(2)}',
                    Icons.trending_up, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard('Returns', '$currency ${returns.toStringAsFixed(2)}',
                    Icons.undo, Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard('Net Sales', '$currency ${net.toStringAsFixed(2)}',
                    Icons.account_balance_wallet, Colors.indigo),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Net Amount'), numeric: true),
                ],
                rows: _details.map((item) {
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
                    DataCell(Text(DateFormat('MMM dd').format(date))),
                    DataCell(Text(item['invoice_number']?.toString() ?? '')),
                    DataCell(Text(item['type']?.toString() ?? '')),
                    DataCell(Text(item['customer_name']?.toString() ?? '')),
                    DataCell(Text(
                        '$currency ${((item['net_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
