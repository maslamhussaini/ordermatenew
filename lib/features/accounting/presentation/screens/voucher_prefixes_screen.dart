// lib/features/accounting/presentation/screens/voucher_prefixes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class VoucherPrefixesScreen extends ConsumerStatefulWidget {
  const VoucherPrefixesScreen({super.key});

  @override
  ConsumerState<VoucherPrefixesScreen> createState() =>
      _VoucherPrefixesScreenState();
}

class _VoucherPrefixesScreenState extends ConsumerState<VoucherPrefixesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      ref.read(accountingProvider.notifier).loadAll(organizationId: org?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Voucher Prefixes'),
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
        [
          'Prefix Code',
          'Description',
          'Voucher Type',
          'Status (1=Active, 0=Inactive)'
        ],
      ];
      final path = await CsvService()
          .saveCsvFile('voucher_prefix_template.csv', headers);
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
          rows[0][0].toString().toLowerCase().contains('code')) {
        startIndex = 1;
      }

      final totalRecords = rows.length - startIndex;
      if (totalRecords <= 0) return;

      final progressNotifier = ValueNotifier<ImportProgress>(
        ImportProgress(total: totalRecords),
      );
      var isCancelled = false;

      // Prepare existing map for duplicate check
      final existingState = ref.read(accountingProvider).voucherPrefixes;
      final existingMap = {
        for (final p in existingState) p.prefixCode.toLowerCase().trim(): p,
      };

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Prefixes',
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
              duplicate: duplicateCount,
            );
            continue;
          }

          try {
            final code = row.isNotEmpty ? row[0].toString().trim() : '';
            if (code.isEmpty) {
              failCount++;
              processedCount++;
              continue;
            }

            if (existingMap.containsKey(code.toLowerCase())) {
              duplicateCount++;
              processedCount++;
              progressNotifier.value = ImportProgress(
                total: totalRecords,
                processed: processedCount,
                success: successCount,
                failed: failCount,
                duplicate: duplicateCount,
              );
              continue;
            }

            final description = row.length > 1 ? row[1].toString().trim() : '';
            final voucherType =
                row.length > 2 ? row[2].toString().trim() : 'General';
            final statusVal =
                row.length > 3 ? int.tryParse(row[3].toString()) : 1;
            final isActive = statusVal == 1;

            final newPrefix = VoucherPrefix(
              id: 0, // Auto-increment assumed
              prefixCode: code,
              description: description.isEmpty ? null : description,
              voucherType: voucherType,
              organizationId:
                  ref.read(organizationProvider).selectedOrganizationId ?? 0,
              status: isActive,
            );

            await ref
                .read(accountingProvider.notifier)
                .addVoucherPrefix(newPrefix);

            successCount++;
          } catch (e) {
            debugPrint('Row $i error: $e');
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

          // Yield to prevent UI freeze
          await Future.delayed(Duration.zero);
        }

        // Final UI Update
        if (mounted && !isCancelled) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Import Complete: $successCount, Duplicates: $duplicateCount, Failed: $failCount')),
            );
            ref.read(accountingProvider.notifier).loadAll();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final filtered = state.voucherPrefixes.where((p) {
      return p.prefixCode.toLowerCase().contains(_searchQuery) ||
          (p.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Prefixes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final orgId =
                  ref.read(organizationProvider).selectedOrganization?.id;
              ref
                  .read(accountingProvider.notifier)
                  .loadAll(organizationId: orgId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import CSV',
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search prefixes...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear())
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final prefix = filtered[index];
                          return Card(
                            child: ListTile(
                              onTap: () {
                                if (prefix.isSystem) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'System defined prefixes cannot be edited.')),
                                  );
                                } else {
                                  context.push(
                                      '/accounting/voucher-prefixes/edit/${prefix.id}');
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.purple.withValues(alpha: 0.12)
                                    : Colors.purple.shade50,
                                child: Icon(
                                  prefix.isSystem ? Icons.lock : Icons.tag,
                                  color: prefix.isSystem
                                      ? Colors.grey
                                      : Colors.purple,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(prefix.prefixCode,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (prefix.isSystem)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.blue
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Text('SYSTEM',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue)),
                                    ),
                                ],
                              ),
                              subtitle: prefix.description != null
                                  ? Text(prefix.description!)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    prefix.status
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: prefix.status
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  if (!prefix.isSystem)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.grey),
                                      onPressed: () => _confirmDelete(prefix),
                                    )
                                  else
                                    const SizedBox(
                                        width: 48), // Placeholder for alignment
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/accounting/voucher-prefixes/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(VoucherPrefix prefix) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voucher Prefix'),
        content:
            Text('Are you sure you want to delete "${prefix.prefixCode}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final orgId = ref.read(organizationProvider).selectedOrganization?.id;
        await ref
            .read(accountingProvider.notifier)
            .deleteVoucherPrefix(prefix.id, organizationId: orgId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Voucher prefix deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
