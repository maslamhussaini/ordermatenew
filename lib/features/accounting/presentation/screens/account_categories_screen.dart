// lib/features/accounting/presentation/screens/account_categories_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class AccountCategoriesScreen extends ConsumerStatefulWidget {
  const AccountCategoriesScreen({super.key});

  @override
  ConsumerState<AccountCategoriesScreen> createState() =>
      _AccountCategoriesScreenState();
}

class _AccountCategoriesScreenState
    extends ConsumerState<AccountCategoriesScreen> {
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
        title: const Text('Import Account Categories'),
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
          'ID',
          'Category Name',
          'Account Type ID',
          'Status (1=Active, 0=Inactive)',
          'Is System (1=Yes, 0=No)'
        ],
      ];
      final path = await CsvService()
          .saveCsvFile('account_categories_template.csv', headers);
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
          rows[0][0].toString().toLowerCase().contains('id')) {
        startIndex = 1;
      }

      final totalRecords = rows.length - startIndex;
      if (totalRecords <= 0) return;

      final progressNotifier = ValueNotifier<ImportProgress>(
        ImportProgress(total: totalRecords),
      );
      var isCancelled = false;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Account Categories',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      final List<AccountCategory> importList = [];
      for (var i = startIndex; i < rows.length; i++) {
        if (isCancelled) break;
        final row = rows[i];
        if (row.isEmpty) continue;

        try {
          final id = int.tryParse(row[0].toString()) ?? 0;
          final name = row.length > 1 ? row[1].toString().trim() : '';
          final typeId =
              row.length > 2 ? int.tryParse(row[2].toString()) ?? 0 : 0;
          final status =
              row.length > 3 ? int.tryParse(row[3].toString()) == 1 : true;
          final isSystem =
              row.length > 4 ? int.tryParse(row[4].toString()) == 1 : false;

          if (name.isNotEmpty && typeId > 0) {
            importList.add(AccountCategory(
              id: id,
              categoryName: name,
              accountTypeId: typeId,
              status: status,
              isSystem: isSystem,
              organizationId:
                  ref.read(organizationProvider).selectedOrganizationId ?? 0,
            ));
          }
        } catch (e) {
          debugPrint('Row $i error: $e');
        }
      }

      if (importList.isNotEmpty) {
        await ref
            .read(accountingProvider.notifier)
            .bulkAddAccountCategories(importList);
      }

      if (mounted && !isCancelled) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Import Complete: ${importList.length} categories imported')),
          );
        }
      }
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
        title: const Text('Account Categories'),
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
                          hintText: 'Search categories...',
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
                      child: _buildList(state.categories, state.types),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/accounting/account-categories/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(
      List<AccountCategory> allCategories, List<AccountType> allTypes) {
    final filtered = allCategories.where((c) {
      return c.categoryName.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final category = filtered[index];
        final type = allTypes.any((t) => t.id == category.accountTypeId)
            ? allTypes
                .firstWhere((t) => t.id == category.accountTypeId)
                .typeName
            : 'Unknown Type';

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Text('${category.id}'),
            ),
            title: Text(category.categoryName),
            subtitle:
                Text('$type | ${category.status ? 'Active' : 'Inactive'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (category.isSystem)
                  const Tooltip(
                    message: 'System Category (Protected)',
                    child: Icon(Icons.lock, size: 16, color: Colors.grey),
                  ),
                const SizedBox(width: 8),
                if (!category.isSystem)
                  FutureBuilder<bool>(
                      future: ref
                          .read(accountingRepositoryProvider)
                          .isAccountCategoryUsed(category.id),
                      builder: (context, snapshot) {
                        final isUsed = snapshot.data ?? true;
                        if (isUsed) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _confirmDelete(category),
                        );
                      }),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(
                      '/accounting/account-categories/edit/${category.id}'),
                ),
              ],
            ),
            onTap: () => context
                .push('/accounting/account-categories/edit/${category.id}'),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(AccountCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete Account Category "${category.categoryName}"?'),
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
        await ref
            .read(accountingProvider.notifier)
            .deleteAccountCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account category deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
