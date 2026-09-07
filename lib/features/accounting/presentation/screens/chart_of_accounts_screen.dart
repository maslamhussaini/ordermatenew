// lib/features/accounting/presentation/screens/chart_of_accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:uuid/uuid.dart';

class ChartOfAccountsScreen extends ConsumerStatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  ConsumerState<ChartOfAccountsScreen> createState() =>
      _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends ConsumerState<ChartOfAccountsScreen> {
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
        title: const Text('Import Chart of Accounts'),
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
          'Account Code',
          'Account Title',
          'Parent Account Code',
          'Account Type Name',
          'Account Category Name',
          'Level',
          'Status (1=Active, 0=Inactive)',
          'Is System (1=Yes, 0=No)'
        ],
      ];
      final path = await CsvService().saveCsvFile('coa_template.csv', headers);
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

      final state = ref.read(accountingProvider);
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;

      // Lookups
      final accountsMap = {
        for (var a in state.accounts) a.accountCode.toLowerCase().trim(): a
      };
      final typesMap = {
        for (var t in state.types) t.typeName.toLowerCase().trim(): t
      };
      final categoriesMap = {
        for (var c in state.categories) c.categoryName.toLowerCase().trim(): c
      };
      // If we encounter new accounts in the batch, we should add them to map so children in same batch can find them?
      // For now, let's assume parent exists or is imported in previous rows.
      // We will perform live query or just update local map as we go.

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Accounts',
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

            if (accountsMap.containsKey(code.toLowerCase())) {
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

            final title =
                row.length > 1 ? row[1].toString().trim() : 'Unknown Account';
            final parentCode = row.length > 2 ? row[2].toString().trim() : '';
            final typeName = row.length > 3 ? row[3].toString().trim() : '';
            final categoryName = row.length > 4 ? row[4].toString().trim() : '';
            final levelVal =
                row.length > 5 ? int.tryParse(row[5].toString()) : 1;
            final statusVal =
                row.length > 6 ? int.tryParse(row[6].toString()) : 1;
            final isSystemVal =
                row.length > 7 ? int.tryParse(row[7].toString()) : 0;

            int? typeId;
            if (typeName.isNotEmpty) {
              // 1. Try name lookup
              if (typesMap.containsKey(typeName.toLowerCase())) {
                typeId = typesMap[typeName.toLowerCase()]!.id;
              } else {
                // 2. Try direct ID if it's numeric
                typeId = int.tryParse(typeName);
              }
            }

            int? categoryId;
            if (categoryName.isNotEmpty) {
              // 1. Try name lookup
              if (categoriesMap.containsKey(categoryName.toLowerCase())) {
                categoryId = categoriesMap[categoryName.toLowerCase()]!.id;
              } else {
                // 2. Try direct ID if numeric
                categoryId = int.tryParse(categoryName);
              }
            }

            String? parentId;
            if (parentCode.isNotEmpty) {
              final lowParentCode = parentCode.toLowerCase();
              // 1. Exact match
              if (accountsMap.containsKey(lowParentCode)) {
                parentId = accountsMap[lowParentCode]!.id;
              } else {
                // 2. Try matching by prefix (e.g. '1000' matches '1000000000')
                // We find the first existing account that starts with this parent code
                final potentialParent = state.accounts
                    .where((a) => a.accountCode.startsWith(parentCode))
                    .toList();

                if (potentialParent.isNotEmpty) {
                  parentId = potentialParent.first.id;
                } else {
                  // 3. Try matching in the current batch too
                  final batchParent = accountsMap.values
                      .where((a) => a.accountCode.startsWith(parentCode))
                      .toList();
                  if (batchParent.isNotEmpty) {
                    parentId = batchParent.first.id;
                  }
                }
              }
            }

            final newId = const Uuid().v4();
            final newAccount = ChartOfAccount(
              id: newId,
              accountCode: code,
              accountTitle: title,
              parentId: parentId,
              level: levelVal ?? 1,
              accountTypeId: typeId,
              accountCategoryId: categoryId,
              organizationId: orgId ?? 0,
              isActive: statusVal == 1,
              isSystem: isSystemVal == 1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Add to map immediately so subsequent children in this import can find it
            accountsMap[code.toLowerCase()] = newAccount;

            await ref.read(accountingProvider.notifier).addAccount(newAccount);

            successCount++;
          } catch (e) {
            failCount++;
            debugPrint('Row $i error: $e');
          }
          processedCount++;
          progressNotifier.value = ImportProgress(
            total: totalRecords,
            processed: processedCount,
            success: successCount,
            failed: failCount,
            duplicate: duplicateCount,
          );

          await Future.delayed(Duration.zero);
        }

        if (mounted && !isCancelled) {
          // Add a small delay so user sees final counts
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.of(context, rootNavigator: true)
                .pop(); // Use rootNavigator
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Import Complete: $successCount success, $duplicateCount duplicate, $failCount failed')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart of Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(accountingProvider.notifier).loadAll(),
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
                          hintText: 'Search by title or code...',
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
                    Expanded(child: _buildAccountTree(state.accounts)),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAccountTree(List<ChartOfAccount> allAccounts) {
    // 1. Filter
    final filtered = allAccounts.where((a) {
      return a.accountCode.contains(_searchQuery) ||
          a.accountTitle.toLowerCase().contains(_searchQuery);
    }).toList();

    // 2. Sort by account code
    filtered.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final account = filtered[index];
        final padding = (account.level - 1) * 24.0;

        return Card(
          margin:
              EdgeInsets.only(left: padding + 8, right: 8, top: 4, bottom: 4),
          child: ListTile(
            onTap: () => context.push('/accounting/coa/edit/${account.id}'),
            leading: CircleAvatar(
              backgroundColor: _getLevelColor(account.level),
              radius: 12,
              child: Text(
                '${account.level}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
            title: Text(
              account.accountTitle,
              style: TextStyle(
                fontWeight:
                    account.level < 4 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(account.accountCode),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (account.isSystem)
                  const Tooltip(
                    message: 'System Account (Protected)',
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  ),
                const SizedBox(width: 8),
                // Delete logic: Hide if system. If not system, check usage.
                if (!account.isSystem)
                  FutureBuilder<bool>(
                      future: ref
                          .read(accountingRepositoryProvider)
                          .isAccountUsed(account.id),
                      builder: (context, snapshot) {
                        final isUsed = snapshot.data ??
                            true; // Default to used while loading
                        if (isUsed) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(account),
                        );
                      }),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () =>
                      context.push('/accounting/coa/edit/${account.id}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(ChartOfAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content:
            Text('Are you sure you want to delete ${account.accountTitle}?'),
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

    if (confirm == true) {
      try {
        await ref.read(accountingProvider.notifier).deleteAccount(account.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Account deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.indigo;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.teal;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    context.push('/accounting/coa/create');
  }
}
