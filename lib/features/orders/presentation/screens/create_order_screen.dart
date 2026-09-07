import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/orders/data/models/order_model.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    this.customerId,
    this.customerName,
    this.initialOrderType = 'SO',
    this.orderId, // Add orderId for editing
    super.key,
  });
  final String? customerId;
  final String? customerName;
  final String initialOrderType;
  final String? orderId; // Null for create, Set for edit

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();
  final _discountController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _productFocusNode = FocusNode();
  final _unitController = TextEditingController();
  final _scrollController = ScrollController();

  // Partner Search
  final _partnerSearchController = TextEditingController();
  final _partnerFocusNode = FocusNode();
  BusinessPartner? _selectedPartner;

  late String _orderType;
  String _orderNumber = '';
  DateTime _orderDate = DateTime.now();
  int? _selectedPaymentTermId;
  bool _isLoading = false;

  // Item Entry State
  Product? _selectedProduct;

  // Cart/Items State
  List<Map<String, dynamic>> _orderItems = [];

  // UOM related
  int? _selectedUomId;
  String? _selectedUomSymbol;
  double _selectedUomFactor = 1.0;
  bool _isInvoiced = false;

  @override
  void initState() {
    super.initState();
    _orderType = widget.initialOrderType;
    _generateOrderNumber();

    // Load inventory data (UOMs, Conversions)
    Future.microtask(() => ref.read(inventoryProvider.notifier).loadAll());

    // Trigger data load in background ensuring suggestions are available
    Future.microtask(() {
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(businessPartnerProvider.notifier).loadVendors();
    });

    // Setup Partner Data
    if (widget.orderId != null) {
      Future.microtask(() => _loadExistingOrder());
    } else if (widget.customerId != null && widget.customerName != null) {
      _partnerSearchController.text = widget.customerName!;
      _selectedPartner = BusinessPartner(
        id: widget.customerId!,
        name: widget.customerName!,
        email: '',
        phone: '',
        address: '',
        isCustomer: widget.initialOrderType == 'SO',
        isVendor: widget.initialOrderType == 'PO',
        isSupplier: widget.initialOrderType == 'PO',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: 0,
        storeId: 0,
      );
    }

    // Load Products if not loaded
    if (ref.read(productProvider).products.isEmpty) {
      Future.microtask(() => ref.read(productProvider.notifier).loadProducts());
    }

    // Load Payment Terms
    Future.microtask(
        () => ref.read(accountingProvider.notifier).loadPaymentTerms());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _discountController.dispose();
    _productSearchController.dispose();
    _productFocusNode.dispose();
    _partnerSearchController.dispose();
    _partnerFocusNode.dispose();
    _unitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateOrderNumber() {
    // Prefix based on type
    final prefix = _orderType;
    ref.read(orderProvider.notifier).generateOrderNumber(prefix).then((val) {
      if (mounted) {
        setState(() {
          _orderNumber = val;
        });
      }
    });
  }

  Future<void> _loadExistingOrder() async {
    setState(() => _isLoading = true);
    try {
      // Use notifier to load orders, which handles offline fallback
      await ref.read(orderProvider.notifier).loadOrders();
      final orders = ref.read(orderProvider).orders;

      final order =
          orders.firstWhere((o) => o.id == widget.orderId, orElse: () {
        throw Exception('Order not found');
      });

      // Load items using notifier (update notifier to handle offline)
      final items =
          await ref.read(orderProvider.notifier).getOrderItems(widget.orderId!);

      if (mounted) {
        setState(() {
          _orderType = order.orderType;
          _orderNumber = order.orderNumber;
          _orderDate = order.orderDate;
          _notesController.text = order.notes ?? '';

          // Set Partner
          _selectedPartner = BusinessPartner(
            id: order.businessPartnerId,
            name: order.businessPartnerName ?? 'Unknown',
            email: '',
            phone: '',
            address: '',
            isCustomer: order.orderType == 'SO',
            isVendor: order.orderType == 'PO',
            isSupplier: order.orderType == 'PO',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            organizationId: order.organizationId,
            storeId: order.storeId,
          );
          _partnerSearchController.text = order.businessPartnerName ?? '';

          // Set Items
          _orderItems = items
              .map(
                (i) => {
                  'product_id': i['product_id'],
                  'product_name': i['product_name'] ?? 'Loaded Product',
                  'quantity': i['quantity'],
                  'rate': i['rate'],
                  'total': i['total'],
                  'discount_percent': i['discount_percent'] ?? 0.0,
                  'uom_id': i['uom_id'],
                  'uom_symbol': i['uom_symbol'],
                  'base_quantity': i['base_quantity'] ?? 1.0,
                },
              )
              .toList();

          _selectedPaymentTermId = order.paymentTermId;
          _isInvoiced = order.isInvoiced;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading order: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _orderDate = picked);
    }
  }

  double get _calculateTotalAmount {
    return _orderItems.fold(0, (sum, item) => sum + (item['total'] as double));
  }

  int? _editingItemIndex;

  void _editItemAt(int index) {
    final item = _orderItems[index]; // Map<String, dynamic>
    setState(() {
      _editingItemIndex = index;
      try {
        final productList = ref.read(productProvider).products;
        _selectedProduct =
            productList.firstWhere((p) => p.id == item['product_id']);
        _productSearchController.text = _selectedProduct!.name;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Warning: Product details not fully loaded.')));
      }
      _qtyController.text = item['quantity'].toString();
      _rateController.text = item['rate'].toString();
      _discountController.text = (item['discount_percent'] ?? 0.0).toString();
      _selectedUomId = item['uom_id'];
      _selectedUomSymbol = item['uom_symbol'];

      // Re-calculate factor for editing
      final invState = ref.read(inventoryProvider);
      final conversion = invState.unitConversions.firstWhere(
        (c) =>
            c.fromUnitId == item['uom_id'] &&
            c.toUnitId == _selectedProduct?.uomId,
        orElse: () => const UnitConversion(
            id: 0,
            fromUnitId: 0,
            toUnitId: 0,
            conversionFactor: 1.0,
            organizationId: 0),
      );
      _selectedUomFactor = conversion.conversionFactor;
    });
  }

  void _addItem() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a product')));
      return;
    }
    final qtyStr = _qtyController.text.trim();
    final qty = double.tryParse(qtyStr) ?? 0.0;
    final rateStr = _rateController.text.trim();
    final rate = double.tryParse(rateStr) ?? 0.0;
    final discountStr = _discountController.text.trim();
    final discount = double.tryParse(discountStr) ?? 0.0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quantity must be > 0')));
      return;
    }

    if (rate <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Price must be > 0')));
      return;
    }

    // Removed invalid check: if (rate < _selectedProduct!.limitPrice) ...
    // The check below handles UOM conversion correctly.

    final productBaseQty = _selectedProduct!.baseQuantity > 0
        ? _selectedProduct!.baseQuantity
        : 1.0;

    // Validation: rate (price per selected UOM) vs limitPrice (per productBaseQty)
    final minRate =
        _selectedProduct!.limitPrice * (_selectedUomFactor / productBaseQty);
    if (rate < minRate) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Price per $_selectedUomSymbol cannot be less than ${minRate.toStringAsFixed(2)}'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (discount > _selectedProduct!.defaultDiscountPercentLimit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Discount cannot exceed the limit of ${_selectedProduct!.defaultDiscountPercentLimit}%'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final total = (qty * rate) * (1 - (discount / 100));

    setState(() {
      if (_editingItemIndex != null) {
        // UPDATE MODE
        _orderItems[_editingItemIndex!] = {
          'product_id': _selectedProduct!.id,
          'product_name': _selectedProduct!.name,
          'quantity': qty,
          'rate': rate, // Storing price per selected UOM
          'total': total,
          'discount_percent': discount,
          'uom_id': _selectedUomId,
          'uom_symbol': _selectedUomSymbol,
          'base_quantity': productBaseQty,
        };

        _editingItemIndex = null; // Exit edit mode
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item Updated')));
      } else {
        // ADD MODE (Existing Logic)
        // Check duplicate (Same product AND same UOM?)
        final existingIndex = _orderItems.indexWhere((i) =>
            i['product_id'] == _selectedProduct!.id &&
            i['uom_id'] == _selectedUomId);

        if (existingIndex >= 0) {
          // Update existing (merge)
          final existing = _orderItems[existingIndex];
          final newQty = (existing['quantity'] as double) + qty;
          final newTotal = newQty * rate;

          _orderItems[existingIndex] = {
            ...existing,
            'quantity': newQty,
            'total': newTotal,
          };
        } else {
          // Add new
          _orderItems.add({
            'product_id': _selectedProduct!.id,
            'product_name': _selectedProduct!.name,
            'quantity': qty,
            'rate': rate,
            'total': total,
            'discount_percent': discount,
            'uom_id': _selectedUomId,
            'uom_symbol': _selectedUomSymbol,
            'base_quantity': productBaseQty,
          });
        }
      }

      // Clear inputs
      _selectedProduct = null;
      _qtyController.clear();
      _rateController.clear();
      _discountController.clear();
      _productSearchController.clear();
      _selectedUomId = null;
      _selectedUomSymbol = null;
      _selectedUomFactor = 1.0;
    });
  }

  void _removeItem(int index) {
    if (_editingItemIndex == index) {
      _editingItemIndex = null; // Cancel edit if item deleted
      _selectedProduct = null;
      _qtyController.clear();
      _productSearchController.clear();
    } else if (_editingItemIndex != null && index < _editingItemIndex!) {
      // Shift index if deleting above current edit
      _editingItemIndex = _editingItemIndex! - 1;
    }

    setState(() {
      _orderItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final partnerId = widget.customerId ?? _selectedPartner?.id;
      final partnerName = widget.customerName ?? _selectedPartner?.name;

      if (partnerId == null || partnerName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a Business Partner')));
        setState(() => _isLoading = false);
        return;
      }

      final isEdit = widget.orderId != null;
      final orderId = isEdit ? widget.orderId! : const Uuid().v4();

      // created_by must be omtbl_users.id -- the live database FK for
      // omtbl_orders.created_by (omtbl_orders_created_by_fkey) targets
      // omtbl_users.id, not the Supabase Auth UID. An edit preserves the
      // original order's creator; only a new order needs a fresh identity.
      String? orderCreatedBy;
      if (isEdit) {
        final existingOrder = ref
            .read(orderProvider)
            .orders
            .where((o) => o.id == widget.orderId)
            .firstOrNull;
        orderCreatedBy = existingOrder?.createdBy;
      }
      if (orderCreatedBy == null || orderCreatedBy.isEmpty) {
        final authState = ref.read(authProvider);
        if (!authState.applicationIdentityResolved ||
            authState.userId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Unable to determine the current user. Please sign in again and retry.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        orderCreatedBy = authState.userId;
      }

      final orgState = ref.read(organizationProvider);
      final currentOrgId = orgState.selectedOrganization?.id;
      final currentStoreId = orgState.selectedStore?.id;

      // Calculate Due Date based on Payment Term
      DateTime? dueDate;
      if (_selectedPaymentTermId != null) {
        final terms = ref.read(accountingProvider).paymentTerms;
        final term =
            terms.where((t) => t.id == _selectedPaymentTermId).firstOrNull;
        if (term != null) {
          dueDate = _orderDate.add(Duration(days: term.days));
        }
      }

      final orderModel = OrderModel(
        id: orderId,
        orderNumber: _orderNumber,
        businessPartnerId: partnerId,
        businessPartnerName: partnerName,
        orderType: _orderType,
        createdBy: orderCreatedBy,
        status: OrderStatus.booked,
        totalAmount: _calculateTotalAmount,
        orderDate: _orderDate,
        dueDate: dueDate,
        paymentTermId: _selectedPaymentTermId,
        notes: _notesController.text,
        organizationId: currentOrgId ?? 0,
        storeId: currentStoreId ?? 0,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      if (isEdit) {
        await ref
            .read(orderProvider.notifier)
            .updateOrderWithItems(orderModel, _orderItems);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order updated successfully')));
          context.pop();
        }
      } else {
        await ref
            .read(orderProvider.notifier)
            .createOrderWithItems(orderModel, _orderItems);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order created successfully')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerState =
        ref.watch(businessPartnerProvider); // Watch for updates
    final inventoryState = ref.watch(inventoryProvider);

    // DEBUG: Verify if state is actually arriving in the UI
    // print('DEBUG: UI BUILD -> Customers Count: ${partnerState.customers.length}');
    // print('DEBUG: UI BUILD -> Vendors Count: ${partnerState.vendors.length}');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderId != null
            ? 'Edit Order $_orderNumber'
            : (widget.customerName != null
                ? 'New ${_orderType == 'PO' ? 'Purchase Order' : 'Sales Order'} for ${widget.customerName}'
                : (_orderType == 'PO'
                    ? 'New Purchase Order'
                    : 'New Sales Order'))),
        actions: [
          IconButton(
            onPressed: _isLoading || _orderItems.isEmpty || _isInvoiced
                ? null
                : _submit,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isInvoiced)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'This order is INVOICED and cannot be modified.',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                // Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Details',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Business Partner Selection
                        if (widget.customerId != null) ...[
                          // Locked Mode
                          TextField(
                            controller: _partnerSearchController,
                            readOnly: true,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Business Partner',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ] else ...[
                          // Search Mode
                          Autocomplete<BusinessPartner>(
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(4)),
                                  ),
                                  child: Container(
                                    width:
                                        340, // Match typical field width or reasonable default
                                    constraints:
                                        const BoxConstraints(maxHeight: 250),
                                    color: Theme.of(context).cardColor,
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(option.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                          subtitle: option.address.isNotEmpty
                                              ? Text(option.address,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)
                                              : null,
                                          onTap: () {
                                            onSelected(option);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            displayStringForOption: (BusinessPartner option) =>
                                option.name,
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<BusinessPartner>.empty();
                              }

                              // Use watched state from build method
                              final options = _orderType == 'SO'
                                  ? partnerState.customers
                                  : partnerState.vendors
                                      .where((v) => v.isSupplier)
                                      .toList();

                              return options.where((BusinessPartner option) {
                                return option.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (BusinessPartner selection) {
                              setState(() {
                                _selectedPartner = selection;
                              });
                            },
                            textEditingController: _partnerSearchController,
                            focusNode: _partnerFocusNode,
                            fieldViewBuilder: (context, controller, focusNode,
                                onEditingComplete) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                onChanged: (text) {
                                  if (_selectedPartner != null) {
                                    setState(() => _selectedPartner = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: _orderType == 'SO'
                                      ? 'Search Customer'
                                      : 'Search Vendor (Supplier)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _selectedPartner != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clear();
                                            setState(
                                                () => _selectedPartner = null);
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Order Type Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _orderType,
                          decoration: const InputDecoration(
                            labelText: 'Order Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'SO', child: Text('Sales Order (SO)')),
                            DropdownMenuItem(
                                value: 'PO',
                                child: Text('Purchase Order (PO)')),
                          ],
                          onChanged: widget.orderId != null
                              ? null
                              : (val) {
                                  if (val != null && val != _orderType) {
                                    setState(() {
                                      _orderType = val;
                                      _selectedPartner = null;
                                      _partnerSearchController.clear();
                                      _generateOrderNumber();
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 16),

                        // Order Number (Read Only)
                        TextFormField(
                          initialValue: _orderNumber,
                          key: ValueKey(
                              _orderNumber), // Updates when state changes
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Order Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Term Dropdown
                        DropdownButtonFormField<int>(
                          initialValue: ref
                                  .watch(accountingProvider)
                                  .paymentTerms
                                  .any((t) => t.id == _selectedPaymentTermId)
                              ? _selectedPaymentTermId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Payment Term',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: ref
                              .watch(accountingProvider)
                              .paymentTerms
                              .map((t) {
                            return DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                            );
                          }).toList(),
                          onChanged: _isInvoiced
                              ? null
                              : (val) =>
                                  setState(() => _selectedPaymentTermId = val),
                        ),
                        const SizedBox(height: 16),

                        // Order Date
                        InkWell(
                          onTap: _isInvoiced ? null : _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Order Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('yyyy-MM-dd').format(_orderDate),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status (Fixed Display)
                        TextFormField(
                          initialValue: 'Booked',
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info_outline),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          readOnly: _isInvoiced,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Product Entry Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Products',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (inventoryState.isLoading)
                          const LinearProgressIndicator(),
                        if (!_isInvoiced) ...[
                          const SizedBox(height: 16),

                          // Product Autocomplete
                          Autocomplete<Product>(
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(4)),
                                  ),
                                  child: Container(
                                    width: 340, // Match typical width
                                    constraints:
                                        const BoxConstraints(maxHeight: 250),
                                    color: Theme.of(context).cardColor,
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(option.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                          subtitle: option.businessPartnerName !=
                                                      null &&
                                                  option.businessPartnerName!
                                                      .isNotEmpty
                                              ? Text(
                                                  'Supplier: ${option.businessPartnerName}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.indigo),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)
                                              : null,
                                          trailing: Text('${option.rate}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          onTap: () {
                                            onSelected(option);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            displayStringForOption: (Product option) =>
                                option.name,
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<Product>.empty();
                              }
                              final products =
                                  ref.read(productProvider).products;
                              return products.where((Product option) {
                                return option.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (Product selection) {
                              setState(() {
                                _selectedProduct = selection;
                                _qtyController.text = '1'; // Default qty
                                _rateController.text =
                                    selection.rate.toString();
                                _discountController.text =
                                    selection.defaultDiscountPercent.toString();
                                _selectedUomId = selection.uomId;
                                _selectedUomSymbol = selection.uomSymbol;
                                _selectedUomFactor =
                                    1.0; // Default when same as product
                              });
                            },
                            // Connect our controller to the Autocomplete
                            textEditingController: _productSearchController,
                            focusNode: _productFocusNode,
                            fieldViewBuilder: (context, controller, focusNode,
                                onEditingComplete) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                decoration: const InputDecoration(
                                  labelText: 'Search Product (Name)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          if (_selectedProduct != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.grey.shade100,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Selected: ${_selectedProduct!.name}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Price Basis: ${_selectedProduct!.formattedRate} / ${_selectedProduct!.baseQuantity} ${_selectedProduct!.uomSymbol ?? 'Unit'}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: inventoryState.unitsOfMeasure
                                      .any((u) => u.id == _selectedUomId)
                                  ? _selectedUomId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Order Unit',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.scale),
                              ),
                              items: inventoryState.unitsOfMeasure.map((u) {
                                return DropdownMenuItem(
                                  value: u.id,
                                  child: Text('${u.name} (${u.symbol})'),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                final uom = inventoryState.unitsOfMeasure
                                    .firstWhere((u) => u.id == v);
                                double factor = 1.0;

                                // Try to find conversion from Selected UOM back to Product's Base Unit
                                if (v != _selectedProduct!.uomId &&
                                    _selectedProduct!.uomId != null) {
                                  try {
                                    final conv = inventoryState.unitConversions
                                        .firstWhere((c) =>
                                            c.fromUnitId == v &&
                                            c.toUnitId ==
                                                _selectedProduct!.uomId);
                                    factor = conv.conversionFactor;
                                  } catch (_) {
                                    // No conversion found, assume 1.0 or show error
                                    debugPrint(
                                        'No conversion found from $v to ${_selectedProduct!.uomId}');
                                  }
                                }

                                setState(() {
                                  _selectedUomId = v;
                                  _selectedUomSymbol = uom.symbol;
                                  _selectedUomFactor = factor;

                                  // Auto-update rate based on new UOM
                                  if (_selectedProduct != null) {
                                    final baseQty =
                                        _selectedProduct!.baseQuantity > 0
                                            ? _selectedProduct!.baseQuantity
                                            : 1.0;
                                    final newRate = _selectedProduct!.rate *
                                        (factor / baseQty);
                                    _rateController.text =
                                        newRate.toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                          ],

LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;

                              final qtyField = TextField(
                                controller: _qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                ),
                              );

                              final rateField = TextField(
                                controller: _rateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                ),
                              );

                              final discField = TextField(
                                controller: _discountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Disc %',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                ),
                              );

                              final button = ElevatedButton.icon(
                                onPressed: _addItem,
                                icon: Icon(_editingItemIndex != null
                                    ? Icons.edit
                                    : Icons.add),
                                label: Text(_editingItemIndex != null
                                    ? 'Update'
                                    : 'Add'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 56),
                                ),
                              );

                              if (isMobile) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: qtyField),
                                        const SizedBox(width: 12),
                                        Expanded(child: rateField),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: discField),
                                        const SizedBox(width: 12),
                                        Expanded(child: button),
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: qtyField),
                                  const SizedBox(width: 12),
                                  Expanded(child: rateField),
                                  const SizedBox(width: 12),
                                  Expanded(child: discField),
                                  const SizedBox(width: 12),
                                  button,
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Items List/Table
                // Items Table
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Items',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                  'Total: ${_calculateTotalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (_orderItems.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No items added'))
                        else
LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 600) {
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _orderItems.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = _orderItems[index];
                                    final isEditing =
                                        _editingItemIndex == index;
                                    return ListTile(
                                      tileColor: isEditing
                                          ? Colors.indigo.withAlpha(26)
                                          : null,
                                      title: Text(
                                        (item['product_name'] as String?) ??
                                            'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                          '${item['quantity']} ${item['uom_symbol'] ?? ''}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            (item['total'] as double)
                                                .toStringAsFixed(2),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 20, color: Colors.blue),
                                            onPressed: () => _editItemAt(index),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            onPressed: () => _removeItem(index),
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8),
                                    );
                                  },
                                );
                              }
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Sr.')),
                                    DataColumn(label: Text('Item Name')),
                                    DataColumn(label: Text('Qty')),
                                    DataColumn(label: Text('Total')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: List.generate(_orderItems.length,
                                      (index) {
                                    final item = _orderItems[index];
                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith<
                                          Color?>((Set<WidgetState> states) {
                                        // Highlight row if currently being edited
                                        if (_editingItemIndex == index) {
                                          return Colors.indigo.withAlpha(26);
                                        }
                                        return null;
                                      }),
                                      cells: [
                                        DataCell(Text('${index + 1}')),
                                        DataCell(Text((item['product_name']
                                                as String?) ??
                                            'Unknown')),
                                        DataCell(Text(
                                            '${item['quantity']} ${item['uom_symbol'] ?? ''}')),
                                        DataCell(Text((item['total'] as double)
                                            .toStringAsFixed(2))),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue),
                                              tooltip: 'Edit Item',
                                              onPressed: () =>
                                                  _editItemAt(index),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              tooltip: 'Delete Item',
                                              onPressed: () =>
                                                  _removeItem(index),
                                            ),
                                          ],
                                        )),
                                      ],
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
