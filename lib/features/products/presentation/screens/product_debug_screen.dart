import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';

class ProductDebugScreen extends ConsumerStatefulWidget {
  const ProductDebugScreen({super.key});

  @override
  ConsumerState<ProductDebugScreen> createState() => _ProductDebugScreenState();
}

class _ProductDebugScreenState extends ConsumerState<ProductDebugScreen> {
  int? _selectedCategoryId;
  String _logString = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  void _addLog(String message) {
    setState(() {
      _logString += '${DateTime.now().toString().split(' ').last} - $message\n';
    });
    debugPrint('DEBUG_SCREEN: $message');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDiagnostics();
    });
  }

  Future<void> _runDiagnostics() async {
    _addLog('Starting Diagnostics...');

    final orgState = ref.read(organizationProvider);
    _addLog('Current Org ID: ${orgState.selectedOrganizationId}');
    _addLog('Current Org Name: ${orgState.selectedOrganization?.name}');
    _addLog('Current Store ID: ${orgState.selectedStoreId}');

    _addLog('Triggering Inventory Load...');
    try {
      await ref.read(inventoryProvider.notifier).loadAll();
      _addLog('Inventory Load Finished.');
    } catch (e) {
      _addLog('Inventory Load Error: $e');
    }

    _addLog('Triggering Accounting Load...');
    try {
      await ref
          .read(accountingProvider.notifier)
          .loadAll(organizationId: orgState.selectedOrganizationId);
      _addLog(
          'Accounting Load Finished. GL Setup: ${ref.read(accountingProvider).glSetup != null ? 'Found' : 'Not Found'}');
    } catch (e) {
      _addLog('Accounting Load Error: $e');
    }

    _addLog('Triggering Vendor/Supplier Load...');
    try {
      await ref.read(vendorProvider.notifier).loadAll();
      _addLog('Vendor/Supplier Load Finished.');
    } catch (e) {
      _addLog('Vendor/Supplier Load Error: $e');
    }

    _addLog('Diagnostics Complete.');
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final accountingState = ref.watch(accountingProvider);
    final vendorState = ref.watch(vendorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Debug Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.security_update_warning_outlined),
            tooltip: 'Load Ignoring Org (Debug Only)',
            onPressed: () async {
              _addLog('Triggering Global Load (No Org Filter)...');
              await ref.read(inventoryProvider.notifier).loadAllIgnoreOrg();
              _addLog('Global Load Finished.');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Diagnostic Logs', [
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _logString,
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Inventory Summary', [
              _buildCountRow('Categories', inventoryState.categories.length),
              _buildCountRow('Brands', inventoryState.brands.length),
              _buildCountRow(
                  'Product Types', inventoryState.productTypes.length),
              _buildCountRow('UOMs', inventoryState.unitsOfMeasure.length),
            ]),
            _buildSection('Vendors & Partners Summary', [
              _buildCountRow(
                  'Suppliers (is_supplier=1)', vendorState.suppliers.length),
              _buildCountRow(
                  'Vendors (is_vendor=1)', vendorState.vendors.length),
              _buildCountRow(
                  'Total Loaded (Union)',
                  (<dynamic>{...vendorState.vendors, ...vendorState.suppliers}
                      .length)),
            ]),
            _buildSection('Accounting Summary', [
              _buildCountRow('Accounts', accountingState.accounts.length),
              _buildCountRow('Financial Sessions',
                  accountingState.financialSessions.length),
              _buildCountRow('GLsetup Exists (1=Yes, 0=No)',
                  accountingState.glSetup != null ? 1 : 0),
            ]),
            const Divider(height: 40),
            _buildSection('Test Interactive Field', [
              const Text('These fields use the same logic as the Product Form:',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              LookupField<ProductCategory, int>(
                label: 'Category (Test)',
                items: inventoryState.categories,
                labelBuilder: (c) => c.name,
                valueBuilder: (c) => c.id,
                value: _selectedCategoryId,
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                prefixIcon: Icons.category,
              ),
              const SizedBox(height: 10),
              if (accountingState.accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'GL Account (Test)',
                      border: OutlineInputBorder()),
                  items: accountingState.accounts
                      .take(10)
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.accountCode} - ${a.accountTitle}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {},
                )
              else
                const Text('No GL Accounts found in provider.',
                    style: TextStyle(color: Colors.red)),
            ]),
            const Divider(height: 40),
            _buildSection('Test Create Product (Simplified)', [
              const Text(
                  'Use this to verify if you can save a product ignoring the main form UI.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Test Name (Required)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _skuController,
                decoration: const InputDecoration(
                    labelText: 'Test SKU (Required)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                    labelText: 'Test Price', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Try Login & Save'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  if (_nameController.text.isEmpty ||
                      _skuController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name and SKU required')));
                    return;
                  }

                  _addLog('Attempting to save test product...');
                  try {
                    final orgState = ref.read(organizationProvider);
                    // Create a minimal product
                    final p = Product(
                      id: '',
                      name: _nameController.text,
                      sku: _skuController.text,
                      rate: double.tryParse(_priceController.text) ?? 10.0,
                      cost: 5.0,
                      categoryId: _selectedCategoryId,
                      // Minimal required fields
                      organizationId: orgState.selectedOrganizationId ?? 0,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await ref.read(productProvider.notifier).addProduct(p);
                    _addLog('SUCCESS: Product saved!');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Saved successfully! Check Product List.')));
                    }
                  } catch (e) {
                    _addLog('FAILURE: Save failed: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
            ]),
            const SizedBox(height: 20),
            const Text('Detailed Categories:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (inventoryState.categories.isEmpty)
              const Text('No categories found.',
                  style: TextStyle(color: Colors.red)),
            ...inventoryState.categories.map((c) =>
                Text('• ${c.name} (ID: ${c.id}, OrgID: ${c.organizationId})')),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo)),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCountRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
