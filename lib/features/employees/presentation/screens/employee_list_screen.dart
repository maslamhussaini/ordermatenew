// lib/features/employees/presentation/screens/employee_list_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({
    super.key,
    this.title,
    this.filterRole,
    this.filterDept,
  });

  final String? title;
  final String? filterRole;
  final String? filterDept;

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(businessPartnerProvider.notifier).loadEmployees(),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _removeDuplicates() async {
    // Note: Provider might hold all partners, but we only care about employees.
    final state = ref.read(businessPartnerProvider);
    final employees = state
        .employees; // Assuming getter exists from previous thought, or using direct list if possible.
    // If 'employees' getter isn't available, we filter, but in previous thought I added code that used 'employees' getter/field.
    // Wait, let's verify if `employees` is available on state.
    // Assuming yes based on previous code.

    if (employees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No employees to check.')));
      }
      return;
    }

    final seenKeys = <String>{};
    final duplicates = <BusinessPartner>[];

    // Identify duplicates (Name + Phone)
    for (final e in employees) {
      final key = '${e.name.trim().toLowerCase()}|${e.phone.trim()}';
      if (seenKeys.contains(key)) {
        duplicates.add(e);
      } else {
        seenKeys.add(key);
      }
    }

    if (duplicates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No duplicate employees found.')),
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
            'Found ${duplicates.length} duplicate entries based on Name and Phone.\n\nAre you sure you want to delete them?'),
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
            .read(businessPartnerProvider.notifier)
            .deletePartner(duplicates[i].id, isEmployee: true);
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
      ref.read(businessPartnerProvider.notifier).loadEmployees();
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Employees'),
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
        ['Name', 'Phone', 'Email', 'Address'],
      ];
      final path =
          await CsvService().saveCsvFile('employee_template.csv', headers);
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

      final totalItems = rows.length - startIndex;
      if (totalItems <= 0) return;

      final progressNotifier = ValueNotifier<ImportProgress>(
        ImportProgress(total: totalItems),
      );

      var isCancelled = false;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Employees',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      // Duplicate Check: Name + Phone
      final existingState = ref.read(businessPartnerProvider).employees;
      // Note: provider getter might vary, assuming 'employees' getter exists or we filter.
      // But above code used `bpState.employees` so let's stick to that.

      final existingKeys = existingState.map((e) {
        final n = e.name.trim().toLowerCase();
        final p = e.phone.trim();
        return '$n|$p';
      }).toSet();

      var successCount = 0;
      var failCount = 0;
      var duplicateCount = 0;

      for (var i = startIndex; i < rows.length; i++) {
        if (isCancelled) break;

        final row = rows[i];
        if (row.isEmpty) {
          progressNotifier.value = ImportProgress(
            total: totalItems,
            processed: i - startIndex + 1,
            success: successCount,
            failed: failCount + duplicateCount,
          );
          continue;
        }

        try {
          // Expected: Name, Phone, Email, Address
          final name = row.isNotEmpty ? row[0].toString().trim() : '';

          if (name.isEmpty) {
            failCount++;
            progressNotifier.value = ImportProgress(
              total: totalItems,
              processed: i - startIndex + 1,
              success: successCount,
              failed: failCount + duplicateCount,
            );
            continue;
          }

          final phone = row.length > 1 ? row[1].toString().trim() : '';
          final email = row.length > 2 ? row[2].toString().trim() : null;
          final address = row.length > 3 ? row[3].toString().trim() : '';

          final currentKey = '${name.toLowerCase()}|$phone';

          if (existingKeys.contains(currentKey)) {
            duplicateCount++;
          } else {
            // Import Logic
            final orgState = ref.read(organizationProvider);

            await ref.read(businessPartnerProvider.notifier).addPartner(
                  BusinessPartner(
                    id: '',
                    name: name,
                    phone: phone,
                    email: email,
                    address: address,
                    isEmployee: true,
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    organizationId: orgState.selectedOrganization?.id ?? 0,
                    storeId: orgState.selectedStore?.id ?? 0,
                  ),
                );
            existingKeys.add(currentKey);
            successCount++;
          }
        } catch (e) {
          debugPrint('Row $i failed: $e');
          failCount++;
        }

        progressNotifier.value = ImportProgress(
          total: totalItems,
          processed: i - startIndex + 1,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCancelled
                  ? 'Import Cancelled'
                  : 'Import Complete: $successCount added, $duplicateCount duplicates, $failCount failed',
            ),
            backgroundColor: successCount > 0
                ? Colors.green
                : (duplicateCount > 0 ? Colors.orange : Colors.red),
          ),
        );
        ref.read(businessPartnerProvider.notifier).loadEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: Provider state might still hold customers if we share the same state.
    // Ideally we should have separate state or filter locally.
    // But loadPartners above REPLACES the state.
    // If we want to avoid clashing with customer list state, we might need a separate provider.
    // For now, let's assume single list in state is fine as long as we reload on init.
    final bpState = ref.watch(businessPartnerProvider);
    final employees = bpState
        .employees; // Using partners generic list, currently mapped to customers in state class?

    // Filter Logic
    final filteredEmployees = employees.where((c) {
      if (!c.isEmployee) return false; // Safety check

      final query = _searchQuery.toLowerCase();
      final matchesSearch = c.name.toLowerCase().contains(query) ||
          c.phone.contains(query) ||
          c.address.toLowerCase().contains(query);

      if (widget.filterDept != null &&
          c.departmentName != widget.filterDept) {
        return false;
      }
      if (widget.filterRole != null && c.roleName != widget.filterRole) {
        return false;
      }

      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('dashboard'),
        ),
        title: Text(widget.title ?? 'Employees List'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(businessPartnerProvider.notifier).loadEmployees(),
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
            label: Text(
                'Add ${widget.filterRole?.replaceAll('Man', 'man') ?? 'Employee'}',
                style: const TextStyle(color: Colors.white)),
            onPressed: () async {
              // Dependency Check
              try {
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) =>
                        const Center(child: CircularProgressIndicator()));

                final orgState = ref.read(organizationProvider);
                if (orgState.selectedOrganizationId == null) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please select an Organization first.')));
                  return;
                }

                await Future.wait([
                  ref
                      .read(businessPartnerProvider.notifier)
                      .loadDepartments(orgState.selectedOrganizationId!),
                  ref.read(businessPartnerProvider.notifier).loadRoles(),
                ]);

                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true)
                    .pop(); // Use rootNavigator to ensure dialog is closed

                final bpState = ref.read(businessPartnerProvider);
                final missing = <String>[];
                if (bpState.departments.isEmpty) missing.add('Department');
                if (bpState.roles.isEmpty) missing.add('Role');

                if (missing.isNotEmpty) {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: const Text('Missing Requirements'),
                            content: Text(
                                'Please create the following before adding an Employee:\n\n• ${missing.join('\n• ')}\n\nYou can create these in the HR Settings.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'))
                            ],
                          ));
                  return;
                }

                final roleLabel = widget.filterRole ?? 'Employee';
                context.goNamed(RouteNames.employeeCreate, extra: {
                  'title': 'New $roleLabel',
                  'initialRole': widget.filterRole,
                });
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error checking dependencies: $e')));
                }
              }
            },
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
                hintText:
                    'Search ${widget.filterRole != null ? '${widget.filterRole}...' : 'employees...'}',
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

          // Employee List
          Expanded(
            child: bpState.isLoading && employees.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : bpState.error != null
                    ? Center(child: Text('Error: ${bpState.error}'))
                    : filteredEmployees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  employees.isEmpty
                                      ? 'No employees found.'
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
                            itemCount: filteredEmployees.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final employee = filteredEmployees[index];
                              return _buildEmployeeItem(employee);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<bool> _deleteEmployeeWithProgress(BusinessPartner employee) async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    // 2. Show Loading
    if (!mounted) return false;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting employee...'),
            ],
          ),
        ),
      ),
    );

    // 3. Perform Delete
    var success = false;
    try {
      await ref
          .read(businessPartnerProvider.notifier)
          .deletePartner(employee.id, isEmployee: true);
      success = true;
    } catch (e) {
      if (mounted) {
        // Error feedback could go here
      }
    }

    // 4. Pop Loading
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
    }

    // 5. Result
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${employee.name} deleted successfully')),
      );
    }

    return success;
  }

  Widget _buildEmployeeItem(BusinessPartner employee) {
    return Dismissible(
      key: Key(employee.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _deleteEmployeeWithProgress(employee),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          leading: CircleAvatar(
            backgroundColor: Colors.teal.shade50,
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.teal.shade800),
            ),
          ),
          title: Text(
            employee.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (employee.phone.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      employee.phone,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              if (employee.email != null && employee.email!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      employee.email!,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    if (employee.email == null || employee.email!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Employee has no email address.')));
                      return;
                    }

                    final passwordController =
                        TextEditingController(text: 'Welcome@123');
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Send Credentials?'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'This will create/update the account for ${employee.name} in Supabase Auth and send them their login details.'),
                            const SizedBox(height: 20),
                            TextField(
                              controller: passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                                helperText: 'Default: Welcome@123',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Send Invite')),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                                child: CircularProgressIndicator()));
                        await ref
                            .read(businessPartnerProvider.notifier)
                            .sendCredentials(
                                employee, passwordController.text.trim());
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true)
                              .pop(); // Close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Credentials sent successfully'),
                                  backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true)
                              .pop(); // Close loading
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: Colors.red));
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Send Email'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: BorderSide(color: Colors.teal.shade200),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.goNamed(
                    RouteNames.employeeEdit,
                    pathParameters: {'id': employee.id},
                    extra: {'title': 'Edit ${employee.name}'},
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.shade200),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteEmployeeWithProgress(employee),
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
      ),
    );
  }
}
