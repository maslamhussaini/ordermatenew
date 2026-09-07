import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:ordermate/core/widgets/processing_dialog.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

class InvoiceEntryScreen extends ConsumerStatefulWidget {
  const InvoiceEntryScreen({
    this.invoiceId,
    this.customerId,
    this.customerName,
    this.orderId,
    this.idInvoiceType,
    super.key,
  });

  final String? invoiceId;
  final String? customerId;
  final String? customerName;
  final String? orderId;
  final String? idInvoiceType;

  @override
  ConsumerState<InvoiceEntryScreen> createState() => _InvoiceEntryScreenState();
}

class _InvoiceEntryScreenState extends ConsumerState<InvoiceEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();
  final _discountController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _productFocusNode = FocusNode();
  final _scrollController = ScrollController();

  final _partnerSearchController = TextEditingController();
  final _partnerFocusNode = FocusNode();
  final _invoiceNumberController = TextEditingController();
  BusinessPartner? _selectedPartner;

  String _invoiceNumber = '';
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  int? _selectedPaymentTermId;
  bool _isLoading = false;

  Product? _selectedProduct;
  List<Map<String, dynamic>> _invoiceItems = [];

  int? _selectedUomId;
  String? _selectedUomSymbol;
  double _selectedUomFactor = 1.0;
  String _status = 'Draft';

  bool _isClosedYear = false;
  String? _readOnlyReason;

  bool get _isReadOnly => _status == 'Paid' || _isClosedYear;

  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _dueDate = _invoiceDate;

    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadAll();
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(accountingProvider.notifier).loadPaymentTerms().then((_) {
        _calculateDueDate();
      });
    });

    if (widget.invoiceId != null) {
      Future.microtask(() => _loadExistingInvoice());
    } else if (widget.orderId != null) {
      Future.microtask(() => _loadFromOrder());
    } else if (widget.customerId != null && widget.customerName != null) {
      _partnerSearchController.text = widget.customerName!;
      _selectedPartner = BusinessPartner(
        id: widget.customerId!,
        name: widget.customerName!,
        email: '',
        phone: '',
        address: '',
        isCustomer: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId:
            ref.read(organizationProvider).selectedOrganizationId ?? 0,
        storeId: ref.read(organizationProvider).selectedStore?.id ?? 0,
      );
    }

    if (ref.read(productProvider).products.isEmpty) {
      Future.microtask(() => ref.read(productProvider.notifier).loadProducts());
    }
  }

  void _calculateDueDate() {
    if (_selectedPaymentTermId == null) {
      setState(() => _dueDate = _invoiceDate);
      return;
    }

    final terms = ref.read(accountingProvider).paymentTerms;
    final term = terms.where((t) => t.id == _selectedPaymentTermId).firstOrNull;
    if (term != null) {
      setState(() {
        _dueDate = _invoiceDate.add(Duration(days: term.days));
      });
    }
  }

  Future<void> _loadFromOrder() async {
    setState(() => _isLoading = true);
    try {
      final orders = ref.read(orderProvider).orders;
      final order = orders.where((o) => o.id == widget.orderId).firstOrNull;

      if (order == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order not found')));
        setState(() => _isLoading = false);
        return;
      }

      final items =
          await ref.read(orderProvider.notifier).getOrderItems(widget.orderId!);

      if (mounted) {
        setState(() {
          _selectedPaymentTermId = order.paymentTermId;
          _partnerSearchController.text = order.businessPartnerName ?? '';
          _selectedPartner = BusinessPartner(
            id: order.businessPartnerId,
            name: order.businessPartnerName ?? 'Partner',
            email: '',
            phone: '',
            address: '',
            isCustomer: true,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            organizationId: order.organizationId,
            storeId: order.storeId,
          );

          _invoiceItems = items
              .map((i) => {
                    'product_id': i['product_id'],
                    'product_name': i['product_name'] ?? 'Product',
                    'quantity': i['quantity'] is int
                        ? (i['quantity'] as int).toDouble()
                        : i['quantity'] as double,
                    'uom_id': i['uom_id'],
                    'uom_symbol': i['uom_symbol'],
                    'base_quantity': i['base_quantity'] ?? 1.0,
                    'discount_percent': i['discount_percent'] ?? 0.0,
                  })
              .toList();

          _invoiceNumberController.text = _invoiceNumber;
          _status = 'Draft';
          _calculateDueDate();
          _isLoading = false;
        });

        // Auto approve order when loading into invoice as requested
        if (order.status != OrderStatus.approved) {
          final approvedOrder = order.copyWith(status: OrderStatus.approved);
          await ref.read(orderProvider.notifier).updateOrder(approvedOrder);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading from order: $e')));
        setState(() => _isLoading = false);
      }
    }
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
    _invoiceNumberController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateInvoiceNumber() {
    final timestamp = DateFormat('yyMMddHHmm').format(DateTime.now());
    setState(() {
      _invoiceNumber = 'INV-$timestamp';
      _invoiceNumberController.text = _invoiceNumber;
    });
  }

  Future<void> _loadExistingInvoice() async {
    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final storeId = ref.read(organizationProvider).selectedStore?.id;
      await ref
          .read(accountingProvider.notifier)
          .loadInvoices(organizationId: orgId, storeId: storeId);
      final invoices = ref.read(accountingProvider).invoices;

      final invoice =
          invoices.firstWhere((i) => i.id == widget.invoiceId, orElse: () {
        throw Exception('Invoice not found');
      });

      final items = await ref
          .read(accountingProvider.notifier)
          .getInvoiceItems(widget.invoiceId!);

      if (mounted) {
        setState(() {
          _invoiceNumber = invoice.invoiceNumber;
          _invoiceNumberController.text = _invoiceNumber;
          _invoiceDate = invoice.invoiceDate;
          _notesController.text = invoice.notes ?? '';

          final partner = ref
              .read(businessPartnerProvider)
              .customers
              .where((c) => c.id == invoice.businessPartnerId)
              .firstOrNull;

          if (partner != null) {
            _selectedPartner = partner;
            _partnerSearchController.text = partner.name;
          }

          _selectedPaymentTermId = invoice.dueDate != null ? null : null;

          _invoiceItems = items
              .map(
                (i) => {
                  'product_id': i.productId,
                  'product_name': i.productName ?? 'Product',
                  'quantity': i.quantity,
                  'total': i.total,
                  'discount_percent': i.discountPercent ?? 0.0,
                  'uom_id': i.uomId,
                  'uom_symbol': i.uomSymbol,
                },
              )
              .toList();

          _status = invoice.status ?? 'Draft';

          // Check for Closed Year
          if (invoice.sYear != null) {
            final state = ref.read(accountingProvider);
            final session = state.financialSessions
                .cast<FinancialSession?>()
                .firstWhere((s) => s?.sYear == invoice.sYear,
                    orElse: () => null);
            if (session != null && session.isClosed) {
              _isClosedYear = true;
              _readOnlyReason =
                  'This invoice belongs to a closed financial year (${session.sYear}).';
            }
          }

          _isLoading = false;
          _calculateDueDate();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading invoice: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
      _calculateDueDate();
    }
  }

  double get _calculateTotalAmount {
    return _invoiceItems.fold(
        0, (sum, item) => sum + (item['total'] as double));
  }

  int? _editingItemIndex;

  void _editItemAt(int index) {
    final item = _invoiceItems[index];
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

    // Removed invalid check: if (rate < (_selectedProduct?.limitPrice ?? 0)) ...
    // The check below handles UOM conversion correctly.

    final productBaseQty = _selectedProduct!.baseQuantity > 0
        ? _selectedProduct!.baseQuantity
        : 1.0;

    // Validation: rate (price per selected UOM) vs limitPrice (per productBaseQty)
    final minRate = (_selectedProduct?.limitPrice ?? 0) *
        (_selectedUomFactor / productBaseQty);
    if (rate < minRate) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Price per $_selectedUomSymbol cannot be less than ${minRate.toStringAsFixed(2)}'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validation: Check against discount limit
    // 1. If limit is 0, treat as "No Limit Defined" (allow any discount).
    // 2. If Default Discount > Limit, respect Default (avoid locking user out of configured default).
    final limit = _selectedProduct!.defaultDiscountPercentLimit;
    final defaultDiscount = _selectedProduct!.defaultDiscountPercent;

    if (limit > 0) {
      // If configuration has a contradiction (Default > Limit), we allow up to Default.
      final effectiveLimit = defaultDiscount > limit ? defaultDiscount : limit;

      if (discount > effectiveLimit) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Discount cannot exceed the limit of ${effectiveLimit.toStringAsFixed(2)}%'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    // NEW VALIDATION: Ensure final price after discount is >= limit price
    final priceAfterDiscount = rate * (1 - (discount / 100));
    if (priceAfterDiscount < minRate) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Final price after discount (${priceAfterDiscount.toStringAsFixed(2)}) cannot be less than limit price (${minRate.toStringAsFixed(2)})'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final total = (qty * rate) * (1 - (discount / 100));

    setState(() {
      if (_editingItemIndex != null) {
        _invoiceItems[_editingItemIndex!] = {
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
        _editingItemIndex = null;
      } else {
        // Disable merging for now to prevent calculation issues with different rates/discounts
        // final existingIndex = _invoiceItems.indexWhere((i) => i['product_id'] == _selectedProduct!.id && i['uom_id'] == _selectedUomId);
        const existingIndex = -1;

        if (existingIndex >= 0) {
          // Merging logic disabled
        } else {
          _invoiceItems.add({
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
    setState(() {
      if (_editingItemIndex == index) _editingItemIndex = null;
      _invoiceItems.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product')));
      return;
    }

    // Use ProcessingDialog for better UX
    final isEdit = widget.invoiceId != null;

    final progress = ValueNotifier<double>(0.0);
    final message = ValueNotifier<String>(
        isEdit ? 'Updating Invoice...' : 'Posting to Transactions...');

    // We defer the logic to the dialog's task
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProcessingDialog(
        initialMessage: message.value,
        successMessage:
            isEdit ? 'Updated Successfully!' : 'Posted Successfully!',
        progressNotifier: progress,
        messageNotifier: message,
        task: () async {
          progress.value = 0.1;
          message.value = 'Validating Customer...';
          await Future.delayed(
              const Duration(milliseconds: 300)); // Dramatic effect

          final partnerId = widget.customerId ?? _selectedPartner?.id;
          if (partnerId == null) throw Exception('Please select a Customer');

          progress.value = 0.3;
          message.value = 'Preparing Invoice Data...';

          final invoiceId = isEdit ? widget.invoiceId! : const Uuid().v4();

          final orgState = ref.read(organizationProvider);
          final currentOrgId = orgState.selectedOrganization?.id ?? 0;
          final currentStoreId = orgState.selectedStore?.id ?? 0;

          DateTime? dueDate;
          if (_selectedPaymentTermId != null) {
            final terms = ref.read(accountingProvider).paymentTerms;
            final term =
                terms.where((t) => t.id == _selectedPaymentTermId).firstOrNull;
            if (term != null) {
              dueDate = _invoiceDate.add(Duration(days: term.days));
            }
          }

          // Calculate total items cost for sanity check or analytics if needed
          // double totalItemsCost = _invoiceItems.fold(0, (sum, item) => sum + (item['total'] as double));

          final invoice = Invoice(
            id: invoiceId,
            invoiceNumber: _invoiceNumber,
            businessPartnerId: partnerId,
            totalAmount: _calculateTotalAmount,
            invoiceDate: _invoiceDate,
            dueDate: dueDate,
            status: 'Unpaid',
            notes: _notesController.text,
            organizationId: currentOrgId,
            storeId: currentStoreId,
            idInvoiceType: widget.idInvoiceType ?? 'SI',
            sYear: ref
                .read(accountingProvider)
                .financialSessions
                .cast<FinancialSession?>()
                .firstWhere(
                  (s) =>
                      s != null &&
                      (_invoiceDate.isAtSameMomentAs(s.startDate) ||
                          _invoiceDate.isAfter(s.startDate)) &&
                      (_invoiceDate.isAtSameMomentAs(s.endDate) ||
                          _invoiceDate.isBefore(
                              s.endDate.add(const Duration(days: 1)))),
                  orElse: () => null,
                )
                ?.sYear,
          );

          print(
              'DEBUG: Submitting Invoice. Date: $_invoiceDate, Resolved sYear: ${invoice.sYear}');

          progress.value = 0.5;
          message.value = isEdit
              ? 'Saving Changes...'
              : 'Saving Invoice & Posting to GL...';

          if (isEdit) {
            await ref
                .read(accountingProvider.notifier)
                .updateInvoiceWithItems(invoice, _invoiceItems);
          } else {
            await ref
                .read(accountingProvider.notifier)
                .createInvoiceWithItems(invoice, _invoiceItems);
          }

          progress.value = 0.8;
          message.value = 'Refreshing Dashboard...';

          // Refresh dashboard
          await ref.read(dashboardProvider.notifier).refresh();

          progress.value = 1.0;
          message.value = 'Finalizing...';
          await Future.delayed(const Duration(milliseconds: 200));
        },
      ),
    );

    if (success == true && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerState = ref.watch(businessPartnerProvider);
    final productState = ref.watch(productProvider);
    final orgState = ref.watch(organizationProvider);
    final inventoryState = ref.watch(inventoryProvider);
    final currencySymbol =
        orgState.selectedStore?.storeDefaultCurrency ?? 'AED';

    final currencyFormat = NumberFormat.currency(symbol: '$currencySymbol ');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceId != null ? 'Edit Invoice' : 'New Invoice'),
        actions: [
          if (!_isReadOnly)
            IconButton(
              onPressed: _isLoading || _invoiceItems.isEmpty ? null : _submit,
              icon: const Icon(Icons.save),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isReadOnly && _readOnlyReason != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, color: Colors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(_readOnlyReason!,
                                      style: const TextStyle(
                                          color: Colors.black87))),
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
                            children: [
                              const Text('Invoice Details',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const Divider(),
                              const SizedBox(height: 16),
                              Autocomplete<BusinessPartner>(
                                displayStringForOption:
                                    (BusinessPartner option) => option.name,
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<
                                        BusinessPartner>.empty();
                                  }
                                  return partnerState.customers
                                      .where((BusinessPartner option) {
                                    return option.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase());
                                  });
                                },
                                onSelected: (BusinessPartner selection) =>
                                    setState(
                                        () => _selectedPartner = selection),
                                textEditingController: _partnerSearchController,
                                focusNode: _partnerFocusNode,
                                fieldViewBuilder: (context, controller,
                                    focusNode, onEditingComplete) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: !_isReadOnly,
                                    decoration: const InputDecoration(
                                      labelText: 'Search Customer',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _invoiceNumberController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice Number',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.numbers),
                                  filled: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: _isReadOnly ? null : _pickDate,
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Invoice Date',
                                          border: OutlineInputBorder(),
                                          prefixIcon:
                                              Icon(Icons.calendar_today),
                                        ),
                                        child: Text(DateFormat('yyyy-MM-dd')
                                            .format(_invoiceDate)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Due Date',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.event_note),
                                        filled: true,
                                      ),
                                      child: Text(_dueDate != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(_dueDate!)
                                          : '-'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                initialValue: ref
                                        .watch(accountingProvider)
                                        .paymentTerms
                                        .any((t) =>
                                            t.id == _selectedPaymentTermId)
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
                                      value: t.id, child: Text(t.name));
                                }).toList(),
                                onChanged: _isReadOnly
                                    ? null
                                    : (val) {
                                        setState(
                                            () => _selectedPaymentTermId = val);
                                        _calculateDueDate();
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Product Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add Products',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Autocomplete<Product>(
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(4)),
                                      ),
                                      child: Container(
                                        width: 340,
                                        constraints: const BoxConstraints(
                                            maxHeight: 250),
                                        color: Theme.of(context).cardColor,
                                        child: ListView.separated(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(height: 1),
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            final option =
                                                options.elementAt(index);
                                            return ListTile(
                                              title: Text(option.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500)),
                                              trailing: Text('${option.rate}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              onTap: () => onSelected(option),
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
                                  return productState.products
                                      .where((Product option) {
                                    return option.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase());
                                  });
                                },
                                onSelected: (Product selection) {
                                  setState(() {
                                    _selectedProduct = selection;
                                    _qtyController.text = '1';
                                    _rateController.text =
                                        selection.rate.toString();
                                    _discountController.text = '0'; // Don't auto-fill discount
                                    _selectedUomId = selection.uomId;
                                    _selectedUomSymbol = selection.uomSymbol;
                                    _selectedUomFactor = 1.0;
                                  });
                                },
                                textEditingController: _productSearchController,
                                focusNode: _productFocusNode,
                                fieldViewBuilder: (context, controller,
                                    focusNode, onEditingComplete) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: !_isReadOnly,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Selected: ${_selectedProduct!.name}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Price: ${currencyFormat.format(_selectedProduct!.rate)} / ${_selectedProduct!.baseQuantity} ${_selectedProduct!.uomSymbol ?? 'Unit'}'),
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
                                    labelText: 'Invoice Unit',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.scale),
                                  ),
                                  items: inventoryState.unitsOfMeasure.map((u) {
                                    return DropdownMenuItem(
                                        value: u.id,
                                        child: Text('${u.name} (${u.symbol})'));
                                  }).toList(),
                                  onChanged: _isReadOnly
                                      ? null
                                      : (v) {
                                          if (v == null) return;
                                          final uom = inventoryState
                                              .unitsOfMeasure
                                              .firstWhere((u) => u.id == v);
                                          double factor = 1.0;
                                          if (v != _selectedProduct!.uomId &&
                                              _selectedProduct!.uomId != null) {
                                            try {
                                              final conv = inventoryState
                                                  .unitConversions
                                                  .firstWhere((c) =>
                                                      c.fromUnitId == v &&
                                                      c.toUnitId ==
                                                          _selectedProduct!
                                                              .uomId);
                                              factor = conv.conversionFactor;
                                            } catch (_) {}
                                          }
                                          setState(() {
                                            _selectedUomId = v;
                                            _selectedUomSymbol = uom.symbol;
                                            _selectedUomFactor = factor;

                                            // Auto-update rate based on new UOM
                                            if (_selectedProduct != null) {
                                              final baseQty = _selectedProduct!
                                                          .baseQuantity >
                                                      0
                                                  ? _selectedProduct!
                                                      .baseQuantity
                                                  : 1.0;
                                              final newRate =
                                                  _selectedProduct!.rate *
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

                                  final qtyField = TextFormField(
                                    controller: _qtyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    enabled: !_isReadOnly,
                                    decoration: const InputDecoration(
                                        labelText: 'Quantity',
                                        border: OutlineInputBorder()),
                                  );

                                  final rateField = TextFormField(
                                    controller: _rateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    enabled: !_isReadOnly,
                                    decoration: const InputDecoration(
                                        labelText: 'Unit Price',
                                        border: OutlineInputBorder()),
                                  );

                                  final discountField = TextFormField(
                                    controller: _discountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    enabled: !_isReadOnly,
                                    decoration: const InputDecoration(
                                        labelText: 'Disc %',
                                        border: OutlineInputBorder()),
                                  );

                                  final button = ElevatedButton.icon(
                                    onPressed: _isReadOnly ? null : _addItem,
                                    icon: Icon(_editingItemIndex != null
                                        ? Icons.edit
                                        : Icons.add),
                                    label: Text(_editingItemIndex != null
                                        ? 'Update'
                                        : 'Add'),
                                    style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(80, 56)),
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
                                            Expanded(child: discountField),
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
                                      Expanded(child: discountField),
                                      const SizedBox(width: 12),
                                      button,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items Table
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Invoice Items',
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
                              if (_invoiceItems.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No items added'))
                              else
LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 600) {
                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _invoiceItems.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final item = _invoiceItems[index];
                                          final isEditing =
                                              _editingItemIndex == index;
                                          return ListTile(
                                            tileColor: isEditing
                                                ? Colors.indigo.withAlpha(26)
                                                : null,
                                            title: Text(
                                              (item['product_name']
                                                      as String?) ??
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
                                                if (!_isReadOnly)
                                                  IconButton(
                                                    icon: const Icon(Icons.edit,
                                                        size: 20,
                                                        color: Colors.blue),
                                                    onPressed: () =>
                                                        _editItemAt(index),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                if (!_isReadOnly) ...[
                                                  const SizedBox(width: 12),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete,
                                                        size: 20,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _removeItem(index),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
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
                                        columnSpacing: 56,
                                        columns: const [
                                          DataColumn(label: Text('Sr.')),
                                          DataColumn(label: Text('Item Name')),
                                          DataColumn(label: Text('Qty')),
                                          DataColumn(label: Text('Total')),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: List.generate(_invoiceItems.length,
                                            (index) {
                                          final item = _invoiceItems[index];
                                          return DataRow(
                                            color: WidgetStateProperty.resolveWith<
                                                Color?>((states) {
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
                                              DataCell(Text(
                                                  (item['total'] as double)
                                                      .toStringAsFixed(2))),
                                              DataCell(Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit,
                                                        color: Colors.blue),
                                                    onPressed: _isReadOnly
                                                        ? null
                                                        : () => _editItemAt(index),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: _isReadOnly
                                                        ? null
                                                        : () => _removeItem(index),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Amount:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              currencyFormat.format(_calculateTotalAmount),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
