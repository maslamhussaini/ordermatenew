import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';

class BrandListScreen extends ConsumerStatefulWidget {
  const BrandListScreen({super.key});

  @override
  ConsumerState<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends ConsumerState<BrandListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inventoryProvider.notifier).loadBrands());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(Brand brand) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Brand'),
          content: Text('Are you sure you want to delete "${brand.name}"?'),
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
                      .deleteBrand(brand.id);
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

  Future<void> _removeDuplicates() async {
    final brands = ref.read(inventoryProvider).brands;
    if (brands.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No brands to check.')));
      }
      return;
    }

    final seenKeys = <String>{};
    final duplicates = <Brand>[];

    // Identify duplicates (Name)
    for (final b in brands) {
      final key = b.name.trim().toLowerCase();
      if (seenKeys.contains(key)) {
        duplicates.add(b);
      } else {
        seenKeys.add(key);
      }
    }

    if (duplicates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No duplicate brands found.')),
        );
      }
      return;
    }

    // Confirm Deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Duplicates?'),
        content: Text(
            'Found ${duplicates.length} duplicate entries based on Name.\n\nAre you sure you want to delete them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Duplicates'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Process Deletion
    final progressNotifier = ValueNotifier<ImportProgress>(
      ImportProgress(total: duplicates.length),
    );
    var isCancelled = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchImportDialog(
        title: 'Deleting Duplicates',
        progressNotifier: progressNotifier,
        onStop: () {
          isCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );

    var successCount = 0;
    var failCount = 0;

    for (var i = 0; i < duplicates.length; i++) {
      if (isCancelled) break;

      try {
        await ref
            .read(inventoryProvider.notifier)
            .deleteBrand(duplicates[i].id);
        successCount++;
      } catch (e) {
        debugPrint('Failed to delete duplicate ${duplicates[i].name}: $e');
        failCount++;
      }

      progressNotifier.value = ImportProgress(
        total: duplicates.length,
        processed: i + 1,
        success: successCount,
        failed: failCount,
      );

      await Future.delayed(Duration.zero);
    }

    if (mounted) {
      if (!isCancelled) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCancelled
                  ? 'Deletion Cancelled'
                  : 'Removed $successCount duplicates. ($failCount failed)',
            ),
            backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
          ),
        );
        ref.read(inventoryProvider.notifier).loadBrands();
      }
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Brands'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Download template and fill this template and then import.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadTemplate();
              },
              icon: const Icon(Icons.download),
              label: const Text('Download CSV Template'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _importCsv();
              },
              icon: const Icon(Icons.file_upload),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final headers = [
        ['Name'],
      ];
      final path =
          await CsvService().saveCsvFile('brand_template.csv', headers);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      final rows = await CsvService().pickAndParseCsv();
      if (rows == null || rows.isEmpty) return;

      var startIndex = 0;
      if (rows.isNotEmpty &&
          rows[0].isNotEmpty &&
          rows[0][0].toString().toLowerCase() == 'name') {
        startIndex = 1;
      }

      final totalRecords = rows.length - startIndex;
      if (totalRecords <= 0) return;

      final progressNotifier = ValueNotifier<ImportProgress>(
        ImportProgress(total: totalRecords),
      );

      var isCancelled = false;

      final existing = ref
          .read(inventoryProvider)
          .brands
          .map((e) => e.name.toLowerCase().trim())
          .toSet();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Brands',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      await Future(() async {
        var successCount = 0;
        var failCount = 0;
        var duplicateCount = 0;
        var processedCount = 0;

        for (var i = startIndex; i < rows.length; i++) {
          if (isCancelled) break;

          final row = rows[i];
          if (row.isEmpty) {
            processedCount++;
            progressNotifier.value = ImportProgress(
              total: totalRecords,
              processed: processedCount,
              success: successCount,
              failed: failCount,
            );
            continue;
          }

          try {
            final name = row[0].toString().trim();
            if (name.isEmpty) {
              failCount++;
            } else if (existing.contains(name.toLowerCase())) {
              duplicateCount++;
            } else {
              await ref.read(inventoryProvider.notifier).addBrand(name);
              existing.add(name.toLowerCase());
              successCount++;
            }
          } catch (e) {
            debugPrint('Row $i failed: $e');
            failCount++;
          }
          processedCount++;

          progressNotifier.value = ImportProgress(
            total: totalRecords,
            processed: processedCount,
            success: successCount,
            failed: failCount,
            duplicate: duplicateCount,
          );

          await Future.delayed(const Duration(milliseconds: 10));
        }

        if (mounted) {
          if (!isCancelled) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) Navigator.of(context, rootNavigator: true).pop();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isCancelled
                      ? 'Import Cancelled'
                      : 'Import Complete: $successCount added, $duplicateCount duplicates, $failCount failed',
                ),
                backgroundColor:
                    successCount > 0 ? Colors.green : Colors.orange,
              ),
            );
            ref.read(inventoryProvider.notifier).loadBrands();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final brands = state.brands;

    final filteredBrands = brands.where((b) {
      if (b.status == 0) return false;
      final query = _searchQuery.toLowerCase();
      return b.name.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brands'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(inventoryProvider.notifier).loadBrands(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Remove Duplicates',
            onPressed: _removeDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import CSV',
            onPressed: _showImportDialog,
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () => context.push('/inventory/brands/create'),
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
                hintText: 'Search brands...',
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
            child: state.isLoading && brands.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && brands.isEmpty
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredBrands.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.branding_watermark_rounded,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  brands.isEmpty
                                      ? 'No brands found.'
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
                            itemCount: filteredBrands.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final brand = filteredBrands[index];
                              return _buildBrandItem(brand);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandItem(Brand brand) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: Border.all(color: Colors.transparent),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(
            brand.name.isNotEmpty ? brand.name[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.indigo.shade800),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              brand.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            if (brand.productCount != null && brand.productCount! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Text(
                  '${brand.productCount} Products',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Active',
          style: TextStyle(color: Colors.green.shade700, fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/inventory/brands/edit/${brand.id}'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: BorderSide(color: Colors.teal.shade200),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(brand),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
