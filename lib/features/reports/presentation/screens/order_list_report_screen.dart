import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class OrderListReportScreen extends ConsumerStatefulWidget {
  const OrderListReportScreen({super.key});

  @override
  ConsumerState<OrderListReportScreen> createState() =>
      _OrderListReportScreenState();
}

class _OrderListReportScreenState extends ConsumerState<OrderListReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedOrderType;
  String? _selectedStatus;
  int? _selectedStoreId;

  bool _isLoading = false;
  List<Order> _reportData = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadOrders();
      ref
          .read(organizationProvider.notifier)
          .loadOrganizations();
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(businessPartnerProvider.notifier).loadVendors();
      _generateReport();
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    await ref.read(orderProvider.notifier).loadOrders();
    final orders = ref.read(orderProvider).orders;

    List<Order> filtered = orders;

    if (_selectedOrderType != null) {
      filtered = filtered
          .where((o) => o.orderType == _selectedOrderType)
          .toList();
    }
    if (_selectedStatus != null) {
      filtered = filtered
          .where((o) => o.status.displayName == _selectedStatus)
          .toList();
    }
    if (_selectedStoreId != null) {
      filtered = filtered.where((o) => o.storeId == _selectedStoreId).toList();
    }
    filtered = filtered.where((o) {
      final date = o.orderDate;
      return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          date.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();

    filtered.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    setState(() {
      _reportData = filtered;
      _isLoading = false;
    });
  }

  String _getPartnerName(String? partnerId) {
    if (partnerId == null || partnerId.isEmpty) return '-';
    final bpState = ref.read(businessPartnerProvider);
    final all = <String, BusinessPartner>{};
    for (final p in bpState.customers) {
      all[p.id] = p;
    }
    for (final p in bpState.vendors) {
      all[p.id] = p;
    }
    return all[partnerId]?.name ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.read(organizationProvider).stores;

    return Scaffold(
      appBar: AppBar(title: const Text('Order List Report')),
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
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedOrderType,
                          decoration: const InputDecoration(
                              labelText: 'Order Type',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'SO', child: Text('Sales Order')),
                            DropdownMenuItem(value: 'PO', child: Text('Purchase Order')),
                            DropdownMenuItem(value: 'SR', child: Text('Sales Return')),
                            DropdownMenuItem(value: 'PR', child: Text('Purchase Return')),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedOrderType = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                              labelText: 'Status',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All')),
                            DropdownMenuItem(value: 'Booked', child: Text('Booked')),
                            DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedStatus = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                            ...stores.map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedStoreId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _generateReport,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                    child: const Text('Generate'),
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
                        child: Text('No orders found for criteria.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Order #')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Customer/Vendor')),
                              DataColumn(label: Text('Store')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Dispatch')),
                              DataColumn(label: Text('Invoiced')),
                              DataColumn(label: Text('Total'), numeric: true),
                            ],
                            rows: _reportData.map((o) {
                              final partnerName = _getPartnerName(o.businessPartnerId);
                              Store? store;
                              for (final s in stores) {
                                if (s.id == o.storeId) {
                                  store = s;
                                  break;
                                }
                              }
                              return DataRow(cells: [
                                DataCell(Text(DateFormat('yy-MM-dd').format(o.orderDate))),
                                DataCell(Text(o.orderNumber)),
                                DataCell(Text(o.orderType)),
                                DataCell(Text(partnerName)),
                                DataCell(Text(store?.name ?? '#${o.storeId}')),
                                DataCell(Text(o.status.displayName)),
                                DataCell(Text(o.dispatchStatus)),
                                DataCell(Text(o.isInvoiced ? 'Yes' : 'No')),
                                DataCell(Text(o.totalAmount.toStringAsFixed(2))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
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
}
