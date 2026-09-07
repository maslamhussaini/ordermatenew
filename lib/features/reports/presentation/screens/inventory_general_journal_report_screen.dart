import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';

class InventoryGeneralJournalReportScreen extends ConsumerStatefulWidget {
  const InventoryGeneralJournalReportScreen({super.key});

  @override
  ConsumerState<InventoryGeneralJournalReportScreen> createState() =>
      _InventoryGeneralJournalReportScreenState();
}

class _InventoryGeneralJournalReportScreenState
    extends ConsumerState<InventoryGeneralJournalReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedProductId;
  int? _selectedStoreId;

  bool _isLoading = false;
  List<JournalEntry> _reportData = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productProvider.notifier).loadProducts();
      ref
          .read(organizationProvider.notifier)
          .loadOrganizations();
      _generateReport();
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    final repo = ref.read(reportRepositoryProvider);
    final orgState = ref.read(organizationProvider);
    final orgId = orgState.selectedOrganization?.id;

    if (orgId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final movements = await repo.getInventoryMovements(
      organizationId: orgId,
      storeId: _selectedStoreId,
      startDate: _startDate,
      endDate: _endDate,
      productId: _selectedProductId,
    );

    final products = ref.read(productProvider).products;
    final productMap = {for (final p in products) p.id: p};

    List<JournalEntry> entries = [];
    for (final m in movements) {
      final productId = m['product_id'] as String?;
      final productName = productId != null
          ? (productMap[productId]?.name ?? 'Unknown Product')
          : 'Unknown Product';
      final storeId = m['store_id'] as int?;
      final movementType = m['movement_type'] as String? ?? '';
      final quantity = (m['quantity'] as num?)?.toDouble() ?? 0.0;
      final createdAt = DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now();

      String type;
      double qtyIn = 0;
      double qtyOut = 0;

      switch (movementType) {
        case 'PURCHASE':
        case 'TRANSFER_IN':
          type = movementType;
          qtyIn = quantity;
          break;
        case 'PURCHASE_RETURN':
        case 'SALE':
        case 'TRANSFER_OUT':
          type = movementType;
          qtyOut = quantity.abs();
          break;
        case 'SALE_RETURN':
          type = movementType;
          qtyIn = quantity;
          break;
        default:
          type = movementType;
          if (quantity >= 0) {
            qtyIn = quantity;
          } else {
            qtyOut = quantity.abs();
          }
      }

      entries.add(JournalEntry(
        date: createdAt,
        type: type,
        reference: _buildReference(m),
        productName: productName,
        qtyIn: qtyIn,
        qtyOut: qtyOut,
        storeId: storeId,
        storeName: _getStoreName(storeId),
      ));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _reportData = entries;
      _isLoading = false;
    });
  }

  String _buildReference(Map<String, dynamic> m) {
    final table = m['reference_table'] as String?;
    final id = m['reference_id'] as String?;
    if (table != null && id != null) {
      final shortId = id.length > 8 ? id.substring(0, 8) : id;
      return '$table:$shortId';
    }
    return '-';
  }

  String _getStoreName(int? id) {
    final stores = ref.read(organizationProvider).stores;
    return stores.where((s) => s.id == id).firstOrNull?.name ?? '#$id';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider).products;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory General Journal')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedStoreId,
                          decoration: const InputDecoration(
                              labelText: 'Store',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<int>(
                                value: null, child: Text('All Stores')),
                            ...ref
                                .read(organizationProvider)
                                .stores
                                .map((s) => DropdownMenuItem(
                                    value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedStoreId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedProductId,
                          decoration: const InputDecoration(
                              labelText: 'Product',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('All Products')),
                            ...products.map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedProductId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _generateReport,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white),
                        child: const Text('Generate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(
                        child: Text('No records found for criteria.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Store')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Reference')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Qty In'), numeric: true),
                              DataColumn(label: Text('Qty Out'), numeric: true),
                            ],
                            rows: _reportData
                                .map((e) => DataRow(cells: [
                                      DataCell(Text(DateFormat('yy-MM-dd')
                                          .format(e.date))),
                                      DataCell(Text(e.storeName)),
                                      DataCell(Text(e.productName)),
                                      DataCell(Text(e.reference)),
                                      DataCell(Text(e.type)),
                                      DataCell(Text(
                                          e.qtyIn > 0
                                              ? e.qtyIn.toStringAsFixed(2)
                                              : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green))),
                                      DataCell(Text(
                                          e.qtyOut > 0
                                              ? e.qtyOut.toStringAsFixed(2)
                                              : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red))),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class JournalEntry {
  final DateTime date;
  final String type;
  final String reference;
  final String productName;
  final double qtyIn;
  final double qtyOut;
  final int? storeId;
  final String storeName;

  JournalEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.productName,
    required this.qtyIn,
    required this.qtyOut,
    this.storeId,
    required this.storeName,
  });
}
