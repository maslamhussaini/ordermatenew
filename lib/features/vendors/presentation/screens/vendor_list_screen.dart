import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  final bool showSuppliersOnly;
  const VendorListScreen({super.key, this.showSuppliersOnly = false});

  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.showSuppliersOnly) {
        ref.read(vendorProvider.notifier).loadSuppliers();
      } else {
        ref.read(vendorProvider.notifier).loadVendors();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _deleteVendorWithProgress(Vendor vendor) async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor?'),
        content: Text('Are you sure you want to delete ${vendor.name}?'),
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
              Text('Deleting vendor...'),
            ],
          ),
        ),
      ),
    );

    // 3. Perform Delete
    var success = false;
    try {
      await ref.read(vendorProvider.notifier).deleteVendor(vendor.id);
      success = true;
    } catch (e) {
      // Error handled in provider/UI feedback usually
    }

    // 4. Pop Loading
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    // 5. Result
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${vendor.name} deleted successfully')),
      );
    }

    return success;
  }

  Future<void> _removeDuplicates() async {
    final vendors = ref.read(vendorProvider).vendors;
    if (vendors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vendors to check.')));
      }
      return;
    }

    final seenKeys = <String>{};
    final duplicates = <Vendor>[];

    // Identify duplicates (Name + Address)
    for (final v in vendors) {
      final key =
          '${v.name.trim().toLowerCase()}|${(v.address ?? '').trim().toLowerCase()}';
      if (seenKeys.contains(key)) {
        duplicates.add(v);
      } else {
        seenKeys.add(key);
      }
    }

    if (duplicates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No duplicate vendors found.')),
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
            'Found ${duplicates.length} duplicate entries based on Name and Address.\n\nAre you sure you want to delete them?'),
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
        await ref.read(vendorProvider.notifier).deleteVendor(duplicates[i].id);
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
      ref.read(vendorProvider.notifier).loadVendors();
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Vendors'),
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
                Navigator.pop(context); // Close dialog first
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
                Navigator.pop(context); // Close dialog first to pick file
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
          'Name',
          'Contact Person',
          'Phone',
          'Email',
          'Address',
          'Is Supplier (true/false)'
        ],
      ];
      final path =
          await CsvService().saveCsvFile('vendor_template.csv', headers);
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
          title: 'Importing Vendors',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      final existingVendors = ref.read(vendorProvider).vendors;
      final existingKeys = existingVendors.map((v) {
        final n = v.name.trim().toLowerCase();
        final a = (v.address ?? '').trim().toLowerCase();
        return '$n|$a';
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
          // Expected: Name, Contact Person, Phone, Email, Address, Is Supplier
          // Indices: 0, 1, 2, 3, 4, 5
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

          final contactPerson =
              row.length > 1 ? row[1].toString().trim() : null;
          final phone = row.length > 2 ? row[2].toString().trim() : null;
          final email = row.length > 3 ? row[3].toString().trim() : null;
          final address = row.length > 4
              ? row[4].toString().trim()
              : ''; // Default empty string for key check if null
          final isSupplierRaw =
              row.length > 5 ? row[5].toString().toLowerCase() : 'false';
          final isSupplier = isSupplierRaw == 'true';

          final currentKey = '${name.toLowerCase()}|${address.toLowerCase()}';

          if (existingKeys.contains(currentKey)) {
            duplicateCount++;
          } else {
            await ref.read(vendorProvider.notifier).addVendor(
                  Vendor(
                    id: '',
                    name: name,
                    contactPerson: contactPerson,
                    phone: phone,
                    email: email,
                    address:
                        address, // Ensure we pass potentially null if entity expects it, but here it expects? check entity
                    isSupplier: isSupplier,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    organizationId: ref
                            .read(organizationProvider)
                            .selectedOrganization
                            ?.id ??
                        0,
                    storeId:
                        ref.read(organizationProvider).selectedStore?.id ?? 0,
                  ),
                );
            existingKeys.add(currentKey);
            successCount++;
          }
        } catch (e) {
          debugPrint('Row $i failed: $e');
          failCount++;
        }

        // Update Progress
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
        ref.read(vendorProvider.notifier).loadVendors();
      }
    } catch (e) {
      if (mounted) {
        // Navigator.of(context).maybePop(); // Safe handled above mostly
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorProvider);
    var vendors = widget.showSuppliersOnly ? state.suppliers : state.vendors;

    final filteredVendors = vendors.where((v) {
      final query = _searchQuery.toLowerCase();
      return v.name.toLowerCase().contains(query) ||
          (v.contactPerson?.toLowerCase().contains(query) ?? false) ||
          (v.phone?.contains(query) ?? false) ||
          (v.email?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(widget.showSuppliersOnly ? 'Suppliers' : 'Vendors'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (widget.showSuppliersOnly) {
                ref.read(vendorProvider.notifier).loadSuppliers();
              } else {
                ref.read(vendorProvider.notifier).loadVendors();
              }
            },
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
            onPressed: () => context.push('/vendors/create'),
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
                hintText: widget.showSuppliersOnly
                    ? 'Search suppliers...'
                    : 'Search vendors...',
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

          // Vendor List
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredVendors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  vendors.isEmpty
                                      ? (widget.showSuppliersOnly
                                          ? 'No suppliers found.'
                                          : 'No vendors found.')
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
                            itemCount: filteredVendors.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final vendor = filteredVendors[index];
                              return _buildVendorItem(vendor);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorItem(Vendor vendor) {
    return Dismissible(
      key: Key(vendor.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _deleteVendorWithProgress(vendor),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          leading: CircleAvatar(
            backgroundColor: Colors.teal.shade50,
            child: Text(
              vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.teal.shade800),
            ),
          ),
          title: Text(
            vendor.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.teal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vendor.contactPerson != null &&
                  vendor.contactPerson!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      vendor.contactPerson!,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (vendor.phone != null && vendor.phone!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      vendor.phone!,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(),
            if (vendor.address != null && vendor.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.home, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vendor.address!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (vendor.email != null && vendor.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.email, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vendor.email!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Status Tags
            const SizedBox(height: 12),
            Row(
              children: [
                if (vendor.isSupplier) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Supplier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (vendor.productCount != null &&
                            vendor.productCount! > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${vendor.productCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: vendor.isActive
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: vendor.isActive
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        vendor.isActive ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: vendor.isActive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: vendor.isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (vendor.isSupplier && vendor.isActive) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        'order-create',
                        extra: {
                          'customerId': vendor.id,
                          'customerName': vendor.name,
                          'initialOrderType': 'PO',
                        },
                      );
                    },
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.shade200),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        'product-create',
                        extra: {'vendorId': vendor.id},
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add Products'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.push('/vendors/edit/${vendor.id}'),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: BorderSide(color: Colors.teal.shade200),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteVendorWithProgress(vendor),
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
