import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';

class UnitConversionsScreen extends ConsumerStatefulWidget {
  const UnitConversionsScreen({super.key});

  @override
  ConsumerState<UnitConversionsScreen> createState() =>
      _UnitConversionsScreenState();
}

class _UnitConversionsScreenState extends ConsumerState<UnitConversionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadUnitsOfMeasure();
      ref.read(inventoryProvider.notifier).loadUnitConversions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(UnitConversion conversion) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Conversion'),
          content:
              const Text('Are you sure you want to delete this conversion?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                try {
                  await ref
                      .read(inventoryProvider.notifier)
                      .deleteUnitConversion(conversion.id);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final conversions = state.unitConversions;
    final uoms = state.unitsOfMeasure;

    final filteredConversions = conversions.where((item) {
      final fromUnit = uoms.any((u) => u.id == item.fromUnitId)
          ? uoms.firstWhere((u) => u.id == item.fromUnitId).name.toLowerCase()
          : '';
      final toUnit = uoms.any((u) => u.id == item.toUnitId)
          ? uoms.firstWhere((u) => u.id == item.toUnitId).name.toLowerCase()
          : '';
      final query = _searchQuery.toLowerCase();

      return fromUnit.contains(query) || toUnit.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Conversions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(inventoryProvider.notifier).loadUnitsOfMeasure();
              ref.read(inventoryProvider.notifier).loadUnitConversions();
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () => context.push('/inventory/unit-conversions/create'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: state.isLoading && conversions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && conversions.isEmpty
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredConversions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  conversions.isEmpty
                                      ? 'No conversions found.'
                                      : 'No results found.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredConversions.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final item = filteredConversions[index];
                              final fromUnit =
                                  uoms.any((u) => u.id == item.fromUnitId)
                                      ? uoms
                                          .firstWhere(
                                              (u) => u.id == item.fromUnitId)
                                          .name
                                      : 'Unit ${item.fromUnitId}';
                              final toUnit = uoms
                                      .any((u) => u.id == item.toUnitId)
                                  ? uoms
                                      .firstWhere((u) => u.id == item.toUnitId)
                                      .name
                                  : 'Unit ${item.toUnitId}';

                              return _buildListItem(item, fromUnit, toUnit);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(UnitConversion item, String fromUnit, String toUnit) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: Icon(Icons.sync_alt, color: Colors.orange.shade800),
        ),
        title: Text(
          '$fromUnit to $toUnit',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text('1 $fromUnit = ${item.conversionFactor} $toUnit'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.teal),
              onPressed: () =>
                  context.push('/inventory/unit-conversions/edit/${item.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(item),
            ),
          ],
        ),
      ),
    );
  }
}
