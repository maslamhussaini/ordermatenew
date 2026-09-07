import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class SalesLocationReportScreen extends ConsumerStatefulWidget {
  const SalesLocationReportScreen({super.key});

  @override
  ConsumerState<SalesLocationReportScreen> createState() =>
      _SalesLocationReportScreenState();
}

class _SalesLocationReportScreenState
    extends ConsumerState<SalesLocationReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<Order> _reportData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final store = ref.read(organizationProvider).selectedStore;
    try {
      final repo = ref.read(orderRepositoryProvider);
      // Ensure end date includes the whole day
      final end =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final start =
          DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);

      final data = await repo.getOrdersByDateRange(start, end,
          organizationId: store?.organizationId, storeId: store?.id);

      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _fetchReport();
    }
  }

  String _calculateDifference(Order order) {
    if (order.latitude == null ||
        order.longitude == null ||
        order.loginLatitude == null ||
        order.loginLongitude == null) {
      return 'N/A';
    }

    final distanceMeters = Geolocator.distanceBetween(
      order.loginLatitude!,
      order.loginLongitude!,
      order.latitude!,
      order.longitude!,
    );

    if (distanceMeters > 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Location Report'),
      ),
      body: Column(
        children: [
          // Filter Section
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                      onPressed: () => _selectDate(context, true),
                    ),
                  ),
                  const Text(' - '),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                      onPressed: () => _selectDate(context, false),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchReport,
                  )
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(child: Text('No orders found in range'))
                    : ListView.builder(
                        itemCount: _reportData.length,
                        itemBuilder: (context, index) {
                          final order = _reportData[index];
                          final diff = _calculateDifference(order);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(
                                  '${order.orderNumber} - ${DateFormat('MM/dd HH:mm').format(order.createdAt)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'By: ${order.createdByName ?? order.createdBy}'),
                                  Text(
                                      'Login Loc: ${order.loginLatitude != null ? "${order.loginLatitude!.toStringAsFixed(4)}, ${order.loginLongitude!.toStringAsFixed(4)}" : "Not Recorded"}'),
                                  Text(
                                      'Order Loc: ${order.latitude != null ? "${order.latitude!.toStringAsFixed(4)}, ${order.longitude!.toStringAsFixed(4)}" : "Not Recorded"}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Distance',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color)),
                                  Text(diff,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
