import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/core/services/pdf_report_service.dart';

class ProductListReportScreen extends ConsumerStatefulWidget {
  const ProductListReportScreen({super.key});

  @override
  ConsumerState<ProductListReportScreen> createState() =>
      _ProductListReportScreenState();
}

class _ProductListReportScreenState extends ConsumerState<ProductListReportScreen> {
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

      final results = await repo.getProductListReport(
        organizationId: orgId,
        storeId: storeId,
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
      const ReportColumn(header: 'Name', dataKey: 'name'),
      const ReportColumn(header: 'SKU', dataKey: 'sku'),
      const ReportColumn(header: 'Category', dataKey: 'category_name'),
      const ReportColumn(header: 'Brand', dataKey: 'brand_name'),
      const ReportColumn(header: 'Type', dataKey: 'type_name'),
      const ReportColumn(header: 'Stock', dataKey: 'stock_qty', isNumeric: true),
      const ReportColumn(header: 'Rate', dataKey: 'rate', isNumeric: true),
    ];
    final service = PdfReportService();
    final bytes = await service.generateReport(
      title: 'Product List Report',
      columns: columns,
      data: _data,
      settings: settings,
      organizationName: orgState.selectedOrganization?.name,
      storeName: orgState.selectedStore?.name,
      storeAddress: orgState.selectedStore?.location ?? orgState.selectedStore?.city,
      storePhone: orgState.selectedStore?.phone,
      totalKeys: ['stock_qty'],
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'ProductList.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Product List',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(onPressed: _printPdf, icon: const Icon(Icons.print)),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text("No products found."))
              : _buildTable(),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('SKU')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Brand')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Stock'), numeric: true),
              DataColumn(label: Text('Rate'), numeric: true),
            ],
            rows: [
              ..._data.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['name']?.toString() ?? '')),
                  DataCell(Text(item['sku']?.toString() ?? '')),
                  DataCell(Text(item['category_name']?.toString() ?? '')),
                  DataCell(Text(item['brand_name']?.toString() ?? '')),
                  DataCell(Text(item['type_name']?.toString() ?? '')),
                  DataCell(Text(
                      ((item['stock_qty'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0))),
                  DataCell(Text(
                      ((item['rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2))),
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }
}
