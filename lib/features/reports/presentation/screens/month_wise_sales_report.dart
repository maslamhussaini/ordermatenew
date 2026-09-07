import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/core/services/pdf_report_service.dart';

class MonthWiseSalesReportScreen extends ConsumerStatefulWidget {
  const MonthWiseSalesReportScreen({super.key});

  @override
  ConsumerState<MonthWiseSalesReportScreen> createState() =>
      _MonthWiseSalesReportScreenState();
}

class _MonthWiseSalesReportScreenState
    extends ConsumerState<MonthWiseSalesReportScreen> {
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
      final storeId = ref.read(organizationProvider).selectedStore?.id;
      final sYear = (ref.read(organizationProvider).selectedFinancialYear ??
          DateTime.now().year);

      final details = await repo.getGrossSalesDetails(
        organizationId: orgId,
        storeId: storeId,
        sYear: sYear,
        startDate: _startDate,
        endDate: _endDate,
      );

      final Map<String, Map<String, dynamic>> grouped = {};
      for (var item in details) {
        final rawDate = item['invoice_date'];
        DateTime date;
        if (rawDate is int) {
          date = DateTime.fromMillisecondsSinceEpoch(rawDate);
        } else if (rawDate is String) {
          date = DateTime.tryParse(rawDate) ?? DateTime.now();
        } else {
          date = DateTime.now();
        }
        final monthKey = DateFormat('yyyy-MM').format(date);
        final monthLabel = DateFormat('MMM yyyy').format(date);

        if (!grouped.containsKey(monthKey)) {
          grouped[monthKey] = {
            'month': monthLabel,
            'invoice_count': 0,
            'total_amount': 0.0,
          };
        }
        grouped[monthKey]!['invoice_count'] =
            (grouped[monthKey]!['invoice_count'] as int) + 1;
        grouped[monthKey]!['total_amount'] =
            (grouped[monthKey]!['total_amount'] as double) +
                ((item['gross_amount'] as num?)?.toDouble() ?? 0.0);
      }

      final result = grouped.values.toList();
      result.sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));

      if (mounted) {
        setState(() {
          _data = result;
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
      const ReportColumn(header: 'Month', dataKey: 'month'),
      const ReportColumn(
          header: 'Invoices', dataKey: 'invoice_count', isNumeric: true),
      const ReportColumn(
          header: 'Amount', dataKey: 'total_amount', isNumeric: true),
    ];
    final service = PdfReportService();
    final bytes = await service.generateReport(
      title: 'Month Wise Sales Report',
      columns: columns,
      data: _data,
      settings: settings,
      organizationName: orgState.selectedOrganization?.name,
      storeName: orgState.selectedStore?.name,
      storeAddress: orgState.selectedStore?.location ?? orgState.selectedStore?.city,
      storePhone: orgState.selectedStore?.phone,
      totalKeys: ['total_amount'],
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'MonthWiseSales_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Month Wise Sales',
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
    double totalAmount = 0;
    int totalInvoices = 0;
    for (var item in _data) {
      totalAmount += (item['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalInvoices += (item['invoice_count'] as int?) ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Month')),
              DataColumn(label: Text('Invoices'), numeric: true),
              DataColumn(label: Text('Amount'), numeric: true),
            ],
            rows: [
              ..._data.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['month']?.toString() ?? '')),
                  DataCell(Text(
                      ((item['invoice_count'] as num?)?.toInt() ?? 0).toString())),
                  DataCell(Text(
                      '$currency ${((item['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                ]);
              }),
              DataRow(
                color: WidgetStateProperty.all(Colors.indigo.shade50),
                cells: [
                  const DataCell(Text('TOTAL',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(totalInvoices.toString(),
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
