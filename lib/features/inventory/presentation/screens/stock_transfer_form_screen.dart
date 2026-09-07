import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/inventory/data/services/inventory_posting_service.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class StockTransferFormScreen extends ConsumerStatefulWidget {
  final String? transferId;
  const StockTransferFormScreen({super.key, this.transferId});

  @override
  ConsumerState<StockTransferFormScreen> createState() =>
      _StockTransferFormScreenState();
}

class _StockTransferFormScreenState
    extends ConsumerState<StockTransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();

  String? _transferNumber;
  DateTime _transferDate = DateTime.now();
  int? _sourceStoreId;
  int? _destinationStoreId;
  List<StockTransferItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // Load Dependencies
    if (ref.read(productProvider).products.isEmpty) {
      await ref.read(productProvider.notifier).loadProducts();
    }
    await ref.read(businessPartnerProvider.notifier).loadEmployees();

    // Check Edit Mode
    if (widget.transferId != null) {
      final transferState = ref.read(stockTransferProvider);
      // Try finding in state first
      final existing = transferState.transfers
          .where((t) => t.id == widget.transferId)
          .firstOrNull;

      if (existing != null) {
        _populateForm(existing);
      } else {
        // Fetch specific if needed (future improvement: add getTransferById to provider)
        // For now, assume state is loaded or we might fail.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Error: Transfer not found locally. Please refresh list.')));
          context.pop();
        }
        return;
      }
    } else {
      // Create Mode
      final notifier = ref.read(stockTransferProvider.notifier);
      final number = await notifier.generateNumber();
      setState(() {
        _transferNumber = number;
      });
    }

    setState(() => _isLoading = false);
  }

  void _populateForm(StockTransfer transfer) {
    setState(() {
      _transferNumber = transfer.transferNumber;
      _transferDate = transfer.transferDate;
      _sourceStoreId = transfer.sourceStoreId;
      _destinationStoreId = transfer.destinationStoreId;
      _driverController.text = transfer.driverName ?? '';
      _vehicleController.text = transfer.vehicleNumber ?? '';
      _remarksController.text = transfer.remarks ?? '';
      _items = List.from(transfer.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(organizationProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    final isEditing = widget.transferId != null;

    final currentStoreId = orgState.selectedStore?.id ?? _sourceStoreId;
    final validDestinations =
        orgState.stores.where((s) => s.id != currentStoreId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Gate Pass' : 'New Gate Pass'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Info Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Transfer #: ${_transferNumber ?? 'Loading...'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(_transferDate),
                                    style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: orgState.selectedStore != null
                                      ? InputDecorator(
                                          decoration: const InputDecoration(
                                              labelText: 'Source Store',
                                              prefixIcon: Icon(Icons
                                                  .store_mall_directory_outlined)),
                                          child: Text(
                                              orgState.selectedStore!.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        )
                                      : DropdownButtonFormField<int>(
                                          initialValue: _sourceStoreId,
                                          decoration: const InputDecoration(
                                              labelText: 'Source Store',
                                              prefixIcon: Icon(Icons
                                                  .store_mall_directory_outlined)),
                                          items: orgState.stores
                                              .map((s) => DropdownMenuItem(
                                                  value: s.id,
                                                  child: Text(s.name)))
                                              .toList(),
                                          onChanged: (val) => setState(() {
                                            _sourceStoreId = val;
                                            if (_destinationStoreId == val) {
                                              _destinationStoreId =
                                                  null; // Reset dest if same
                                            }
                                          }),
                                          validator: (val) =>
                                              val == null ? 'Required' : null,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: DropdownButtonFormField<int>(
                                  initialValue: _destinationStoreId,
                                  decoration: const InputDecoration(
                                      labelText: 'Destination Store',
                                      prefixIcon: Icon(Icons.store)),
                                  items: validDestinations
                                      .map((s) => DropdownMenuItem(
                                          value: s.id, child: Text(s.name)))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _destinationStoreId = val),
                                  validator: (val) =>
                                      val == null ? 'Required' : null,
                                )),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _driverController.text.isNotEmpty &&
                                            partnerState.employees.any((e) =>
                                                e.name ==
                                                _driverController.text)
                                        ? _driverController.text
                                        : null,
                                    decoration: const InputDecoration(
                                        labelText: 'Driver Name',
                                        prefixIcon: Icon(Icons.person_outline)),
                                    items: partnerState.employees
                                        .map((e) => DropdownMenuItem(
                                            value: e.name, child: Text(e.name)))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        _driverController.text = val;
                                      }
                                    },
                                    validator: (val) => null, // Optional
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _vehicleController,
                                    decoration: const InputDecoration(
                                        labelText: 'Vehicle #',
                                        prefixIcon: Icon(
                                            Icons.local_shipping_outlined)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _remarksController,
                              decoration: const InputDecoration(
                                  labelText: 'Remarks',
                                  prefixIcon: Icon(Icons.note_alt_outlined)),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items (${_items.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.playlist_add,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No items added yet',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._items.map((item) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                child: Text(
                                  item.productName.isNotEmpty
                                      ? item.productName[0]
                                      : '?',
                                  style: TextStyle(
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${item.quantity.toStringAsFixed(2)} ${item.uomSymbol}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _items.remove(item);
                                  });
                                },
                              ),
                            ),
                          )),

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: Text(
                          isEditing ? 'Update Gate Pass' : 'Create Gate Pass'),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  void _showAddItemDialog() {
    final productState = ref.read(productProvider);
    String? selectedProductId;
    double quantity = 1;
    String uomSymbol = '';
    double availableStock = 0;
    bool isLoadingStock = false;
    String? stockError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        final selectedProduct = productState.products
            .where((p) => p.id == selectedProductId)
            .firstOrNull;
        if (selectedProduct != null) {
          uomSymbol = selectedProduct.uomSymbol ?? '';
        }

        Future<void> refreshStock(String? productId) async {
          if (productId == null || _sourceStoreId == null) {
            setDialogState(() {
              availableStock = 0;
              isLoadingStock = false;
              stockError = null;
            });
            return;
          }

          setDialogState(() {
            isLoadingStock = true;
            stockError = null;
          });

          try {
            final orgId = ref.read(organizationProvider).selectedOrganizationId;
            if (orgId == null) {
              setDialogState(() {
                availableStock = 0;
                isLoadingStock = false;
                stockError = 'No organization selected';
              });
              return;
            }

            final postingService = InventoryPostingService();
            final stock = await postingService.getAvailableStock(
              organizationId: orgId,
              productId: productId,
              storeId: _sourceStoreId!,
            );

            if (ctx.mounted) {
              setDialogState(() {
                availableStock = stock;
                isLoadingStock = false;
              });
            }
          } catch (e) {
            if (ctx.mounted) {
              setDialogState(() {
                availableStock = 0;
                isLoadingStock = false;
                stockError = 'Unable to load stock';
              });
            }
          }
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedProductId,
                isExpanded: true,
                hint: const Text('Select Product'),
                items: productState.products
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedProductId = val;
                    availableStock = 0;
                    stockError = null;
                  });
                  if (val != null) {
                    refreshStock(val);
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: isLoadingStock
                      ? const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Loading stock...',
                                style: TextStyle(fontSize: 12)),
                          ],
                        )
                      : stockError != null
                          ? Text(stockError ?? '',
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 12))
                          : Text(
                              'Available at source: ${availableStock.toStringAsFixed(2)} ${uomSymbol}',
                              style: TextStyle(
                                  color: availableStock > 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: '1',
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        errorText: selectedProductId != null && quantity > 0 && availableStock > 0 && quantity > availableStock
                            ? 'Exceeds available stock (${availableStock.toStringAsFixed(2)})'
                            : null,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => quantity = double.tryParse(val) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'UOM',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(uomSymbol.isNotEmpty ? uomSymbol : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedProductId != null && quantity > 0) {
                  final product = productState.products
                      .firstWhere((p) => p.id == selectedProductId);
                  setState(() {
                    _items.add(StockTransferItem(
                      id: const Uuid().v4(),
                      transferId: widget.transferId ?? '',
                      productId: product.id,
                      productName: product.name,
                      quantity: quantity,
                      uomId: product.uomId ?? 0,
                      uomSymbol: product.uomSymbol ?? '',
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item')));
      return;
    }

    final orgState = ref.read(organizationProvider);
    final currentStoreId = orgState.selectedStore?.id ?? _sourceStoreId;

    if (currentStoreId == null || currentStoreId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Source Store')));
      return;
    }

    final isEditing = widget.transferId != null;
    final transferId = widget.transferId ?? const Uuid().v4();

    // Update items with appropriate Transfer ID
    final List<StockTransferItem> updatedItems =
        _items.map((item) => item.copyWith(transferId: transferId)).toList();

    final authState = ref.read(authProvider);
    final accountingState = ref.read(accountingProvider);

    final transfer = StockTransfer(
      id: transferId,
      transferNumber: _transferNumber ?? 'DRAFT',
      sourceStoreId: currentStoreId,
      destinationStoreId: _destinationStoreId,
      status: isEditing ? 'Draft' : 'Draft', // Status logic might differ
      transferDate: _transferDate,
      createdBy: authState.userId,
      driverName: _driverController.text,
      vehicleNumber: _vehicleController.text,
      remarks: _remarksController.text,
      organizationId: orgState.selectedOrganizationId ?? 0,
      sYear: accountingState.selectedFinancialSession?.sYear ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: updatedItems,
      isSynced: false,
    );

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));

      if (isEditing) {
        await ref.read(stockTransferProvider.notifier).updateTransfer(transfer);
      } else {
        await ref.read(stockTransferProvider.notifier).createTransfer(transfer);
      }

      if (mounted) {
        Navigator.pop(context); // Pop loading
        context.pop(); // Pop screen
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Gate Pass updated' : 'Gate Pass created'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
