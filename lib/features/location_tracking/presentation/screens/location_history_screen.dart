import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/location_tracking/presentation/providers/location_tracking_provider.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(businessPartnerProvider.notifier).loadEmployees();
      _fetchHistory();
    });
  }

  void _fetchHistory() {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    ref.read(locationTrackingProvider.notifier).loadHistory(
          start: startOfDay,
          end: endOfDay,
          userId: _selectedUserId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationTrackingProvider);
    final employees = ref.watch(businessPartnerProvider).employees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Movement History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Implementation for printing/PDF generation would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Print functionality to be implemented with pdf package')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _selectedDate = date);
                                _fetchHistory();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(DateFormat('yyyy-MM-dd')
                                  .format(_selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LookupField<dynamic, String>(
                            label: 'User (Booker)',
                            value: _selectedUserId,
                            items: employees,
                            labelBuilder: (e) => e.name,
                            valueBuilder: (e) => e.id,
                            onChanged: (val) {
                              setState(() => _selectedUserId = val);
                              _fetchHistory();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.history.isEmpty
                    ? const Center(
                        child: Text(
                            'No movement history found for this selection'))
                    : ListView.separated(
                        itemCount: state.history.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = state.history[index];
                          // Note: In real app, we'd join with business partners to show name
                          // Here we assume getHistory already handles it or we use userId
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.1),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(DateFormat('hh:mm a')
                                .format(item.createdAt.toLocal())),
                            subtitle: Text(
                                'Lat: ${item.latitude.toStringAsFixed(6)}, Lon: ${item.longitude.toStringAsFixed(6)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.map_outlined),
                              onPressed: () {
                                // open maps implementation
                              },
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
