// lib/features/customers/presentation/screens/customer_list_screen.dart

import 'dart:async';

import 'package:dio/dio.dart'; // Add Dio import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/business_partners/presentation/widgets/create_salesman_dialog.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

enum CustomerFilterMode { all, myCustomers, nearby }

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  // Added methods from previous partial class
  Future<List<Map<String, dynamic>>> _searchAddressWithOSM(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': 1,
          'limit': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'OrderMate_FlutterApp/1.0',
            'Accept-Language': 'en',
          },
        ),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('OSM Search Error: $e');
    }
    return [];
  }

  // Customer creation requires at least one Salesman to exist, using the
  // exact same Salesman definition as the SalesMan picker in
  // customer_form_screen.dart (department == 'sales', role == 'salesman').
  Future<void> _navigateToCustomerCreate(BuildContext context) async {
    // Root cause of the false "No Salesman" positive: `employees` is only
    // ever populated by loadEmployees(), which this screen never called --
    // it was only loaded incidentally if the user had already visited an
    // Employee/User/Stock-Transfer screen earlier in the session. Ensure
    // it's actually loaded before evaluating, not just whatever happens to
    // already be in memory. Skip the reload when data is already present,
    // to avoid an unnecessary duplicate fetch.
    if (ref.read(businessPartnerProvider).employees.isEmpty) {
      try {
        await ref.read(businessPartnerProvider.notifier).loadEmployees();
      } catch (e) {
        // A genuine failure to load must not be silently treated as "no
        // Salesman exists" -- surface it distinctly instead.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load Salesman information: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
    }

    final hasSalesman =
        ref.read(businessPartnerProvider).employees.any((e) {
      final dept = e.departmentName?.toLowerCase() ?? '';
      final role = e.roleName?.toLowerCase() ?? '';
      return dept == 'sales' && role == 'salesman';
    });

    if (hasSalesman) {
      context.goNamed(RouteNames.customerCreate);
      return;
    }

    final wantsToCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salesman Required'),
        content: const Text(
            'A Salesman is required before you can create a Customer.\n\n'
            'Would you like to create a Salesman now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create Salesman'),
          ),
        ],
      ),
    );

    if (wantsToCreate != true || !mounted) return;

    final newSalesmanId = await showCreateSalesmanDialog(context);
    if (newSalesmanId == null || !mounted) return;

    // Salesman created successfully -- proceed straight into Customer
    // Creation, exactly as if a Salesman had already existed.
    context.goNamed(RouteNames.customerCreate);
  }

  Future<void> _removeDuplicates() async {
    final customers = ref.read(businessPartnerProvider).customers;
    if (customers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No customers to check.')));
      }
      return;
    }

    final seenKeys = <String>{};
    final duplicates = <BusinessPartner>[];

    // Identify duplicates (Name + Address)
    for (final c in customers) {
      final key =
          '${c.name.trim().toLowerCase()}|${c.address.trim().toLowerCase()}';
      if (seenKeys.contains(key)) {
        duplicates.add(c);
      } else {
        seenKeys.add(key);
      }
    }

    if (duplicates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No duplicate customers found.')),
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
        await ref
            .read(businessPartnerProvider.notifier)
            .deletePartner(duplicates[i].id);
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

      // Yield to UI
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
      ref.read(businessPartnerProvider.notifier).loadCustomers();
    }
  }

  Future<void> _updateAllClientGps() async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update All GPS?'),
        content: const Text(
          'This will look up coordinates for ALL customers based on their address. '
          'This process takes time (~1 sec per customer) to respect API limits.\n\n'
          'Existing coordinates will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Start Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Setup
    final customers = ref.read(businessPartnerProvider).customers;
    final total = customers.length;

    final progressNotifier = ValueNotifier<ImportProgress>(
      ImportProgress(total: total),
    );

    var successCount = 0;
    var failCount = 0;
    var skippedCount = 0; // No address
    var isCancelled = false;

    if (!mounted) return;

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchImportDialog(
        title: 'Updating Locations',
        progressNotifier: progressNotifier,
        onStop: () {
          isCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );

    // 3. Process Loop
    for (var i = 0; i < customers.length; i++) {
      if (isCancelled) break;

      final c = customers[i];

      if (c.address.trim().isEmpty) {
        skippedCount++; // Count skipped as failed or just ignore?
        // Dialog shows Success/Failed. Maybe we treat skipped as Failed or just don't count them in success?
        // Let's treat them as skipped (neither success nor fail in strict sense, but for UI maybe fail?)
        // Or we can add skipped to failed count for simplicity in this context.
        // Let's just track them separately for the final snackbar, but maybe not update progress success.
      } else {
        try {
          // 1s delay for OSM Nominatim policy
          await Future.delayed(const Duration(milliseconds: 1100));

          if (isCancelled) break;

          final results = await _searchAddressWithOSM(c.address);
          if (results.isNotEmpty) {
            final lat = double.tryParse(results.first['lat'].toString());
            final lon = double.tryParse(results.first['lon'].toString());

            if (lat != null && lon != null) {
              final updated = c.copyWith(
                latitude: lat,
                longitude: lon,
              );
              // Silent update (true to avoid full reload on every item)
              await ref
                  .read(businessPartnerProvider.notifier)
                  .updatePartner(updated);
              successCount++;
            } else {
              failCount++;
            }
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint('GPS Update Fail for ${c.name}: $e');
        }
      }

      progressNotifier.value = ImportProgress(
        total: total,
        processed: i + 1,
        success: successCount,
        failed: failCount + skippedCount,
      );
    }

    // 4. Finish
    if (mounted) {
      if (!isCancelled) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close progress
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCancelled
                ? 'Update Cancelled'
                : 'Update Complete: $successCount updated, $failCount failed, $skippedCount skipped (no address)',
          ),
        ),
      );
      // Refresh list to show new data
      ref.read(businessPartnerProvider.notifier).loadCustomers();
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(businessPartnerProvider.notifier).loadCustomers(),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  CustomerFilterMode _filterMode = CustomerFilterMode.all;
  Position? _currentPosition;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndSort() async {
    try {
      final position = await LocationHelper.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _filterMode = CustomerFilterMode.nearby;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Customers'),
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
          'Name',
          'Contact Person',
          'Phone',
          'Email',
          'Address',
          'Latitude',
          'Longitude'
        ],
      ];
      final path =
          await CsvService().saveCsvFile('customer_template.csv', headers);
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

      // New Progress Notifier
      final progressNotifier = ValueNotifier<ImportProgress>(
        ImportProgress(total: totalRecords),
      );

      var isCancelled = false;

      // Duplicate Check key: Name|Address -> Partner
      final existingState = ref.read(businessPartnerProvider).customers;
      final existingMap = {
        for (final c in existingState)
          '${c.name.toLowerCase().trim()}|${c.address.toLowerCase().trim()}': c,
      };

      if (!mounted) return;

      // Show Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => BatchImportDialog(
          title: 'Importing Customers',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      await Future(() async {
        final currentBatch = <BusinessPartner>[];
        const batchSize = 50;

        var successCount = 0;
        var failCount = 0;
        var duplicateCount = 0; // or skipped
        var updatedCount = 0;
        var processedCount = 0;

        for (var i = startIndex; i < rows.length; i++) {
          if (isCancelled) break;

          final row = rows[i];
          if (row.isEmpty) {
            processedCount++;
            progressNotifier.value = ImportProgress(
              total: totalRecords,
              processed: processedCount,
              success: successCount + updatedCount,
              failed: failCount + duplicateCount,
            );
            continue;
          }

          try {
            // Parsing Logic
            final name = row.isNotEmpty ? row[0].toString().trim() : '';
            if (name.isEmpty) {
              failCount++;
              processedCount++;
              continue;
            }

            final contactPerson =
                row.length > 1 ? row[1].toString().trim() : '';
            final phone = row.length > 2 ? row[2].toString().trim() : '';
            final email = row.length > 3 ? row[3].toString().trim() : '';
            final address = row.length > 4 ? row[4].toString().trim() : '';

            double? lat;
            double? lon;
            if (row.length > 6) {
              lat = double.tryParse(row[5].toString().trim());
              lon = double.tryParse(row[6].toString().trim());
            }

            // Key: Name + Address
            final key = '${name.toLowerCase()}|${address.toLowerCase()}';

            if (existingMap.containsKey(key)) {
              // UPDATE LOGIC
              final existingPartner = existingMap[key]!;
              if (lat != null && lon != null && (lat != 0 || lon != 0)) {
                final updated =
                    existingPartner.copyWith(latitude: lat, longitude: lon);
                await ref
                    .read(businessPartnerProvider.notifier)
                    .updatePartner(updated);
                updatedCount++;
              } else {
                duplicateCount++;
              }
            } else {
              // INSERT LOGIC
              final orgState = ref.read(organizationProvider);
              currentBatch.add(
                BusinessPartner(
                  id: '',
                  name: name,
                  contactPerson: contactPerson.isEmpty ? null : contactPerson,
                  phone: phone,
                  email: email.isEmpty ? null : email,
                  address: address,
                  latitude: lat,
                  longitude: lon,
                  isCustomer: true,
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  storeId: orgState.selectedStore?.id ?? 0,
                  organizationId: orgState.selectedOrganization?.id ?? 0,
                ),
              );
            }
            // If we successfully processed an item (add to batch or updated directly)
            // Note: Batch items are not "success" yet until saved.
            // But for progress bar, we count them as processed step.
          } catch (e) {
            debugPrint('Row $i parse failed: $e');
            failCount++;
          }

          processedCount++;

          // Process batch if full
          if (currentBatch.length >= batchSize) {
            try {
              await ref
                  .read(businessPartnerProvider.notifier)
                  .addPartners(currentBatch, refresh: false);
              successCount += currentBatch.length;
            } catch (e) {
              debugPrint('Batch import failed: $e');
              failCount += currentBatch.length;
            }
            currentBatch.clear();

            // Allow UI update
            await Future.delayed(Duration.zero);
          }

          // Update Progress UI
          progressNotifier.value = ImportProgress(
            total: totalRecords,
            processed: processedCount,
            success: successCount +
                updatedCount, // Counting updates as success? Or separate? Image has 2 counters. Let's merge for "Success"
            failed:
                failCount, // + duplicates? No, duplicates are just skipped/neutral.
            // Maybe failed needs to include failed batches.
          );
        }

        // Process remaining
        if (currentBatch.isNotEmpty && !isCancelled) {
          try {
            await ref
                .read(businessPartnerProvider.notifier)
                .addPartners(currentBatch, refresh: false);
            successCount += currentBatch.length;
          } catch (e) {
            debugPrint('Final batch failed: $e');
            failCount += currentBatch.length;
          }
        }

        // Final Update
        progressNotifier.value = ImportProgress(
          total: totalRecords,
          processed: totalRecords,
          success: successCount + updatedCount,
          failed: failCount,
        );

        if (mounted && !isCancelled) {
          // Close Dialog automatically when done
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCancelled
                    ? 'Import Stopped'
                    : 'Import Complete: ${successCount + updatedCount} success, $duplicateCount duplicates, $failCount failed',
              ),
              backgroundColor: (successCount > 0 || updatedCount > 0)
                  ? Colors.green
                  : Colors.orange,
            ),
          );
          // Single refresh at the end
          ref.read(businessPartnerProvider.notifier).loadCustomers();
        }
      });

      // Wait for future? No, showDialog blocks until popped.
      // So we wait for showDialog to return (which happens on Stop or Done).
      // But if we await showDialog, the code after it runs after pop.
      // The `importFuture` runs in parallel.
      // If user clicks Stop, `isCancelled` becomes true, `importFuture` loop breaks, and it finishes.
      // If `importFuture` finishes, it pops dialog.

      // So we just need to ensure `importFuture` is started. It is.
      // We don't strictly need to await `importFuture` here if we rely on its internal completion callback.
    } catch (e) {
      if (mounted) {
        // Navigator.of(context).maybePop(); // Might close wrong thing if not careful
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bpState = ref.watch(businessPartnerProvider);
    final customers = bpState.customers;

    // Filter Logic
    var filteredCustomers = customers.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = c.name.toLowerCase().contains(query) ||
          c.phone.contains(query) ||
          c.address.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_filterMode == CustomerFilterMode.myCustomers) {
        // Customer -> Salesman assignment (manager_id), not record
        // ownership (createdBy). businessPartnerId is null for the org
        // owner/admin and any user without a linked BusinessPartner row --
        // in that case "My Customers" correctly shows no assigned customers
        // rather than matching on a null==null coincidence.
        final myBusinessPartnerId = ref.read(authProvider).businessPartnerId;
        if (myBusinessPartnerId == null) return false;
        return c.managerId == myBusinessPartnerId;
      }

      // For nearby, we filter out those without location, OR we keep them but put them at bottom?
      // Let's filter out ones without location for now to be strict about "match location"
      if (_filterMode == CustomerFilterMode.nearby &&
          _currentPosition != null) {
        return c.latitude != null && c.longitude != null;
      }

      return true;
    }).toList();

    // Sort if nearby mode
    if (_filterMode == CustomerFilterMode.nearby && _currentPosition != null) {
      filteredCustomers.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;

        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude!,
          a.longitude!,
        );
        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude!,
          b.longitude!,
        );

        return distA.compareTo(distB);
      });

      // Update the distanceMeters property in a copy for display?
      // Since it's a list of existing objects, we can't easily modify them without copying.
      // But the display logic might need valid distance.
      // For now, we just sort them.
      filteredCustomers = filteredCustomers.map((c) {
        if (c.latitude != null && c.longitude != null) {
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            c.latitude!,
            c.longitude!,
          );
          return c.copyWith(distanceMeters: dist.toInt());
        }
        return c;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(RouteNames.dashboard),
        ),
        title: const Text('My Customers'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(businessPartnerProvider.notifier).loadCustomers(),
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
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            tooltip: 'Update GPS from Address',
            onPressed: _updateAllClientGps,
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () => _navigateToCustomerCreate(context),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<CustomerFilterMode>(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    tooltip: 'Filter Customers',
                    onSelected: (mode) {
                      if (mode == CustomerFilterMode.nearby) {
                        _fetchLocationAndSort();
                      } else {
                        setState(() {
                          _filterMode = mode;
                          _currentPosition =
                              null; // Reset location if switching away? Or keep it? keeping it is fine.
                        });
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        CheckedPopupMenuItem(
                          value: CustomerFilterMode.all,
                          checked: _filterMode == CustomerFilterMode.all,
                          child: const Text('All Customers'),
                        ),
                        CheckedPopupMenuItem(
                          value: CustomerFilterMode.myCustomers,
                          checked:
                              _filterMode == CustomerFilterMode.myCustomers,
                          child: const Text('My Customers'),
                        ),
                        PopupMenuItem(
                          value: CustomerFilterMode.nearby,
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: _filterMode == CustomerFilterMode.nearby
                                    ? Colors.indigo
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Nearby (Current Location)',
                                style: TextStyle(
                                  color:
                                      _filterMode == CustomerFilterMode.nearby
                                          ? Colors.indigo
                                          : Colors.black,
                                  fontWeight:
                                      _filterMode == CustomerFilterMode.nearby
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: bpState.isLoading && customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : bpState.error != null
                    ? Center(child: Text('Error: ${bpState.error}'))
                    : filteredCustomers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  customers.isEmpty
                                      ? 'No customers found.'
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
                            itemCount: filteredCustomers.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              return _buildCustomerItem(customer);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<bool> _deleteCustomerWithProgress(BusinessPartner customer) async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
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
              Text('Deleting customer...'),
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
          .deletePartner(customer.id, isCustomer: true);
      success = true;
    } catch (e) {
      if (mounted) {
        // Error feedback could go here
      }
    }

    // 4. Pop Loading
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    // 5. Result
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} deleted successfully')),
      );
    }

    return success;
  }

  void _showCustomerActionDialog(BusinessPartner customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer.name),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushNamed(
                RouteNames.invoiceCreate,
                extra: {
                  'customerId': customer.id,
                  'customerName': customer.name,
                },
              );
            },
            icon: const Icon(Icons.receipt),
            label: const Text('Create Invoice'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushNamed(
                RouteNames.orderCreate,
                extra: {
                  'customerId': customer.id,
                  'customerName': customer.name,
                },
              );
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Create Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(BusinessPartner customer) {
    return Dismissible(
      key: Key(customer.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _deleteCustomerWithProgress(customer),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade50,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.indigo.shade800),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showCustomerActionDialog(customer),
                onLongPress: () {
                  context.goNamed(RouteNames.customerEdit,
                      pathParameters: {'id': customer.id});
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap: Choose Action • Hold: Edit',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                customer.phone,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              if (customer.distanceMeters != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 4,
                          child:
                              Text('•', style: TextStyle(color: Colors.grey))),
                      const SizedBox(width: 4),
                      const Icon(Icons.near_me, size: 12, color: Colors.blue),
                      const SizedBox(width: 2),
                      Text(
                        customer.distanceKm,
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.home, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer.address,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        RouteNames.invoiceCreate,
                        extra: {
                          'customerId': customer.id,
                          'customerName': customer.name,
                        },
                      );
                    },
                    icon: const Icon(Icons.receipt, size: 18),
                    label: const Text('New Invoice'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        RouteNames.orderCreate,
                        extra: {
                          'customerId': customer.id,
                          'customerName': customer.name,
                        },
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('New Order'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.pushNamed(
                        RouteNames.customerInvoices,
                        extra: {
                          'customer': customer,
                        },
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.goNamed('customer-edit',
                        pathParameters: {'id': customer.id}),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: BorderSide(color: Colors.indigo.shade200),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _deleteCustomerWithProgress(customer),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
