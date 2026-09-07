import 'dart:async';

// Product List Screen - Updated to remove dependency check dialog
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/services/csv_service.dart';
import 'package:ordermate/core/widgets/batch_import_dialog.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/router/route_names.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productProvider.notifier).loadProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _deleteProductWithProgress(Product product) async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}?'),
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
              Text('Deleting product...'),
            ],
          ),
        ),
      ),
    );

    // 3. Perform Delete
    var success = false;
    try {
      await ref.read(productProvider.notifier).deleteProduct(product.id);
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    // 4. Pop Loading
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }

    // 5. Result
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} deleted successfully')),
      );
    }

    return success;
  }

  Future<void> _removeDuplicates() async {
    final products = ref.read(productProvider).products;
    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No products to check.')));
      }
      return;
    }

    final seenKeys = <String>{};
    final duplicates = <Product>[];

    // Identify duplicates (Name + Brand)
    // Note: If Brand Id is null, it treats it as null string.
    for (final p in products) {
      final key = '${p.name.trim().toLowerCase()}|${p.brandId ?? ''}';
      if (seenKeys.contains(key)) {
        duplicates.add(p);
      } else {
        seenKeys.add(key);
      }
    }

    if (duplicates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No duplicate products found.')),
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
            'Found ${duplicates.length} duplicate entries based on Name and Brand.\n\nAre you sure you want to delete them?'),
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
            .read(productProvider.notifier)
            .deleteProduct(duplicates[i].id);
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
        ref.read(productProvider.notifier).loadProducts();
      }
    }
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Products'),
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
          'SKU',
          'Description',
          'Cost',
          'Rate',
          'Brand Name',
          'Category Name',
          'Supplier Name',
          'Type Name'
        ],
      ];
      final path =
          await CsvService().saveCsvFile('product_template.csv', headers);
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
          title: 'Importing Products',
          progressNotifier: progressNotifier,
          onStop: () {
            isCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );

      // Pre-fetch lists
      await ref.read(inventoryProvider.notifier).loadBrands();
      await ref.read(inventoryProvider.notifier).loadCategories();
      await ref.read(inventoryProvider.notifier).loadProductTypes();
      await ref.read(vendorProvider.notifier).loadVendors();
      await ref
          .read(productProvider.notifier)
          .loadProducts(); // Ensure latest products

      final brands = ref.read(inventoryProvider).brands;
      final categories = ref.read(inventoryProvider).categories;
      final types = ref.read(inventoryProvider).productTypes;
      final vendors = ref.read(vendorProvider).vendors;
      final existingProducts = ref.read(productProvider).products;

      // Duplicate Check Set: "name|brandId"
      // Note: Brand ID can be null or empty string.
      // We normalize name to lowercase trim.
      final existingKeys = existingProducts.map((p) {
        final n = p.name.trim().toLowerCase();
        final b = p.brandId ?? '';
        return '$n|$b';
      }).toSet();

      final importFuture = Future(() async {
        var success = 0;
        var failed = 0;
        var duplicates = 0;

        for (var i = startIndex; i < rows.length; i++) {
          if (isCancelled) break;

          final row = rows[i];
          if (row.isEmpty) {
            progressNotifier.value = ImportProgress(
              total: totalItems,
              processed: i - startIndex + 1,
              success: success,
              failed: failed +
                  duplicates, // Group duplicates into failed or separate? Standardize later.
            );
            continue;
          }

          try {
            final name = row.isNotEmpty ? row[0].toString().trim() : '';
            if (name.isEmpty) {
              failed++;
              continue;
            }

            final sku = row.length > 1 ? row[1].toString().trim() : '';
            final desc = row.length > 2 ? row[2].toString().trim() : '';
            final cost = row.length > 3
                ? double.tryParse(row[3].toString()) ?? 0.0
                : 0.0;
            final rate = row.length > 4
                ? double.tryParse(row[4].toString()) ?? 0.0
                : 0.0;

            // Normalize inputs
            final brandName = row.length > 5 ? row[5].toString().trim() : '';
            final categoryName = row.length > 6 ? row[6].toString().trim() : '';
            final vendorName = row.length > 7 ? row[7].toString().trim() : '';
            final typeName = row.length > 8 ? row[8].toString().trim() : '';

            // Helper
            T? findByName<T>(
                List<T> list, String nameObj, String Function(T) getName) {
              if (nameObj.isEmpty) return null;
              final normalizedInput = nameObj.trim().toLowerCase();
              try {
                return list.firstWhere((item) {
                  final itemContent = getName(item).trim().toLowerCase();
                  return itemContent == normalizedInput;
                });
              } catch (e) {
                return null;
              }
            }

            final brand = findByName(brands, brandName, (b) => b.name);
            final category =
                findByName(categories, categoryName, (c) => c.name);
            final vendor = findByName(vendors, vendorName, (v) => v.name);
            final productType = findByName(types, typeName, (t) => t.name);

            // Duplicate Check
            final currentKey = '${name.toLowerCase()}|${brand?.id ?? ''}';

            if (existingKeys.contains(currentKey)) {
              duplicates++;
            } else {
              await ref.read(productProvider.notifier).addProduct(
                    Product(
                      id: '',
                      name: name,
                      sku: sku,
                      description: desc,
                      cost: cost,
                      rate: rate,
                      brandId: brand?.id,
                      categoryId: category?.id,
                      businessPartnerId: vendor?.id,
                      productTypeId: productType?.id,
                      organizationId: ref
                              .read(organizationProvider)
                              .selectedOrganization
                              ?.id ??
                          0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

              existingKeys.add(currentKey); // Add to local set
              success++;
            }
          } catch (e) {
            debugPrint('Row $i failed: $e');
            failed++;
          }

          progressNotifier.value = ImportProgress(
            total: totalItems,
            processed: i - startIndex + 1,
            success: success,
            failed: failed,
            duplicate: duplicates,
          );

          await Future.delayed(const Duration(milliseconds: 10));
        }

        if (mounted) {
          if (!isCancelled) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // Close dialog
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isCancelled
                      ? 'Import Cancelled'
                      : 'Import Complete: $success added, $duplicates duplicates, $failed failed',
                ),
                backgroundColor: success > 0
                    ? Colors.green
                    : (duplicates > 0 ? Colors.orange : Colors.red),
              ),
            );
            ref.read(productProvider.notifier).loadProducts();
          }
        }
      });

      await importFuture;
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
    final state = ref.watch(productProvider);
    final products = state.products;

    final filteredProducts = products.where((p) {
      if (!p.isActive) return false;
      final query = _searchQuery.toLowerCase();
      final nameMatch = p.name.toLowerCase().contains(query);
      final skuMatch = p.sku.toLowerCase().contains(query);
      final categoryMatch =
          p.categoryName?.toLowerCase().contains(query) ?? false;
      return nameMatch || skuMatch || categoryMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(productProvider.notifier).loadProducts(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Remove Duplicates',
            onPressed: _removeDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Debug Data',
            onPressed: () => context.pushNamed(RouteNames.productDebug),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import CSV',
            onPressed: _showImportDialog,
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () {
              // Direct navigation - ProductFormScreen handles its own data loading now
              context.pushNamed(RouteNames.productCreate);
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
                hintText: 'Search by Name, SKU, Category...',
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
            child: state.isLoading && products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && products.isEmpty
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  products.isEmpty
                                      ? 'No products found.'
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
                            itemCount: filteredProducts.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductItem(product);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Product product) {
    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _deleteProductWithProgress(product),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(
              product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.blue.shade800),
            ),
          ),
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Row(
            children: [
              Text(
                'SKU: ${product.sku}',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${product.formattedRate}${product.uomSymbol != null ? ' / ${product.baseQuantity != 1.0 ? product.baseQuantity : ''} ${product.uomSymbol}' : ''}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(),
            // Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.category,
                        'Category',
                        product.categoryName ?? '-',
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        Icons.style,
                        'Type',
                        product.productTypeName ?? '-',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.branding_watermark,
                        'Brand',
                        product.brandName ?? '-',
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        Icons.store,
                        'Supplier',
                        product.businessPartnerName ?? '-',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (product.description != null &&
                product.description!.isNotEmpty) ...[
              Text(
                product.description!,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cost info (left side)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Cost: ${product.formattedCost}${product.uomSymbol != null ? ' / ${product.baseQuantity != 1.0 ? product.baseQuantity : ''} ${product.uomSymbol}' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        debugPrint(
                          'User tapped Edit for product ${product.id}',
                        );
                        context.pushNamed(
                          'product-edit',
                          pathParameters: {'id': product.id},
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo,
                        side: BorderSide(color: Colors.indigo.shade200),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _deleteProductWithProgress(product),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
