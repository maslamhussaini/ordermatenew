// lib/features/orders/presentation/screens/order_list_screen.dart

import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:ordermate/core/services/pdf_invoice_service.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/orders/presentation/screens/pdf_preview_screen.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart'; // import
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/voucher_service.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({
    this.initialFilterType,
    this.initialFilterStatus,
    super.key,
  });

  final String? initialFilterType; // 'SO' or 'PO'
  final String? initialFilterStatus;

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _filterStatus; // All, Booked, Approved, etc.

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilterStatus ?? 'All';
    Future.microtask(() => ref.read(orderProvider.notifier).loadOrders());
  }

  Future<void> _handlePdfAction(Order order, String action) async {
    // Show Loading
    if (!mounted) return;

    final ValueNotifier<String> statusMessage =
        ValueNotifier('Initializing...');
    final ValueNotifier<double> progressValue = ValueNotifier(0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ValueListenableBuilder<double>(
                valueListenable: progressValue,
                builder: (context, val, _) =>
                    LinearProgressIndicator(value: val, minHeight: 6),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: statusMessage,
                builder: (context, msg, _) => Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<double>(
                valueListenable: progressValue,
                builder: (context, val, _) => Text('${(val * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Fetch Order Items
      statusMessage.value = 'Fetching order items...';
      progressValue.value = 0.1;

      final items = await ref
          .read(orderProvider.notifier)
          .getOrderItems(order.id)
          .timeout(const Duration(seconds: 10));

      // 2. Fetch Partner
      statusMessage.value = 'Fetching partner details...';
      progressValue.value = 0.2;

      final bpState = ref.read(businessPartnerProvider);
      var partner = bpState.customers.cast<BusinessPartner?>().firstWhere(
                (c) => c?.id == order.businessPartnerId,
                orElse: () => null,
              ) ??
          bpState.vendors.cast<BusinessPartner?>().firstWhere(
                (v) => v?.id == order.businessPartnerId,
                orElse: () => null,
              );

      if (partner == null) {
        final connectivityResult = await ConnectivityHelper.check();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          try {
            final partners = await ref
                .read(businessPartnerLocalRepositoryProvider)
                .getLocalPartners(
                    isCustomer: true,
                    isVendor: true,
                    isEmployee: true,
                    // SECURITY (OFF-01): must scope to the current org.
                    organizationId: ref
                        .read(organizationProvider)
                        .selectedOrganizationId);
            partner = partners.firstWhere(
                (p) => p.id == order.businessPartnerId,
                orElse: () => throw Exception('Partner not found locally'));
          } catch (e) {
            throw Exception(
                'Offline: Business Partner not found in local cache.');
          }
        } else {
          partner = await ref
              .read(businessPartnerProvider.notifier)
              .repository
              .getPartnerById(order.businessPartnerId);
        }
      }

      if (partner == null) {
        throw Exception('Business Partner not found');
      }

      // 3. Address Formatting
      statusMessage.value = 'Formatting address...';

      // Ensure address metadata is loaded (lightweight check usually)
      if (bpState.cities.isEmpty) {
        await ref.read(businessPartnerProvider.notifier).loadCities();
      }
      if (bpState.states.isEmpty) {
        await ref.read(businessPartnerProvider.notifier).loadStates();
      }
      if (bpState.countries.isEmpty) {
        await ref.read(businessPartnerProvider.notifier).loadCountries();
      }

      String getCityName(int? id) =>
          ref.read(businessPartnerProvider).cities.firstWhere(
              (e) => e['id'] == id,
              orElse: () => {})['city_name'] as String? ??
          '';
      String getStateName(int? id) =>
          ref.read(businessPartnerProvider).states.firstWhere(
              (e) => e['id'] == id,
              orElse: () => {})['state_name'] as String? ??
          '';
      String getCountryName(int? id) =>
          ref.read(businessPartnerProvider).countries.firstWhere(
              (e) => e['id'] == id,
              orElse: () => {})['country_name'] as String? ??
          '';

      final customerAddressParts = <String>[
        partner.address.trim(),
        getCityName(partner.cityId),
        getStateName(partner.stateId),
        partner.postalCode ?? '',
        getCountryName(partner.countryId),
      ].where((s) => s.isNotEmpty).toList();
      final fullCustomerAddress = customerAddressParts.join(', ');

      // 4. Fetch Organization & Store Info
      statusMessage.value = 'Loading organization info...';
      progressValue.value = 0.25;

      var orgState = ref.read(organizationProvider);
      if (orgState.selectedOrganization == null || orgState.stores.isEmpty) {
        await ref.read(organizationProvider.notifier).loadOrganizations();
        orgState = ref.read(organizationProvider);
      }

      final org = orgState.selectedOrganization;
      final orgName = org?.name ?? 'Organization Name'; // Fallback
      final store = orgState.selectedStore ??
          (orgState.stores.isNotEmpty ? orgState.stores.first : null);
      final sName = store?.name ?? 'Store Name';
      final sPhone = store?.phone ?? '';
      final currency = store?.storeDefaultCurrency ?? 'AED';

      // 5. Fetch Logo
      statusMessage.value = 'Fetching logo...';
      Uint8List? logoBytes;
      if (org != null) {
        final connectivityResult = await ConnectivityHelper.check();
        final isOnline = !connectivityResult.contains(ConnectivityResult.none);

        if (isOnline && org.logoUrl != null) {
          try {
            final response = await http
                .get(Uri.parse(org.logoUrl!))
                .timeout(const Duration(seconds: 2));
            if (response.statusCode == 200) {
              logoBytes = response.bodyBytes;
              // Cache silent fire-and-forget not needed here strictly, handled by Repo usually
            }
          } catch (e) {
            // Fallback to cached
            try {
              logoBytes = await ref
                  .read(organizationRepositoryProvider)
                  .getCachedLogo(org.id);
            } catch (_) {}
          }
        } else {
          try {
            logoBytes = await ref
                .read(organizationRepositoryProvider)
                .getCachedLogo(org.id);
          } catch (_) {}
        }
      }

      // 6. Generate PDF
      statusMessage.value = 'Preparing PDF Engine...';
      progressValue.value = 0.3;

      final pdfBytes = await PdfInvoiceService()
          .generateInvoice(
              order: order,
              items: items,
              customer: partner,
              organizationName: orgName,
              storeName: sName,
              storeAddress: [
                store?.location ?? '',
                store?.city ?? '',
                store?.postalCode ?? '',
                store?.country ?? '',
              ].where((s) => s.isNotEmpty).join(', '),
              storePhone: sPhone,
              customerAddressOverride: fullCustomerAddress,
              logoBytes: logoBytes,
              settings: ref.read(settingsProvider).pdfSettings,
              currencyCode: currency,
              onProgress: (msg, val) {
                statusMessage.value = msg;
                progressValue.value = val;
              })
          .timeout(const Duration(seconds: 15));

      if (pdfBytes.isEmpty) throw Exception('Generated PDF is empty');

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pop(); // Close loading dialog correctly

      // 7. Perform Action
      statusMessage.value = 'Opening PDF...';
      final filename = '${order.orderNumber}.pdf';
      switch (action) {
        case 'print':
          await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdfBytes,
              name: filename);
        case 'preview':
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) =>
                  PdfPreviewScreen(pdfBytes: pdfBytes, fileName: filename),
            ),
          );
        case 'share':
          await Printing.sharePdf(bytes: pdfBytes, filename: filename);
        case 'convert':
          await _handleConvertOrder(order);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        debugPrint('PDF Error: $e');
      }
    }
  }

  bool get _isSoFilter => widget.initialFilterType == 'SO';
  bool get _isPoFilter => widget.initialFilterType == 'PO';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleConvertOrder(Order order) async {
    // 0. Check if already invoiced
    if (order.isInvoiced) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already Invoiced'),
          content: const Text('This order is already marked as invoiced.\n\n'
              'Regenerating will create new accounting transactions. '
              'If you deleted the previous transactions manually, you can proceed.\n\n'
              'Do you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // 1. Check if dispatch fields are filled
    if (order.dispatchStatus == 'pending' || order.dispatchDate == null) {
      final updatedOrder = await _showDispatchDialog(order);
      if (updatedOrder == null) return;
      order = updatedOrder;
    }

    if (!mounted) return;

    if (order.dispatchStatus != 'dispatched' || order.dispatchDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order must be status "dispatched" and have a date.')));
      return;
    }

    if (order.status != OrderStatus.approved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order must be approved before it can be converted to an invoice.')));
      return;
    }

    // 2. Perform Conversion
    try {
      showDialog(
          context: context,
          builder: (ctx) => const Center(child: CircularProgressIndicator()));

      final accountingState = ref.read(accountingProvider);
      
      if (accountingState.selectedFinancialSession == null) {
        throw Exception(
            'No Financial Session selected. Please select a Financial Session from the dashboard or settings.');
      }

      if (accountingState.accounts.isEmpty) {
        await ref.read(accountingProvider.notifier).loadAll();
      }

      await ref.read(voucherServiceProvider).convertOrderToInvoice(order,
          accounts: ref.read(accountingProvider).accounts);

      // Update order status in DB (Invoiced = true)
      await ref
          .read(orderProvider.notifier)
          .updateOrderInvoiced(order.id, true);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Order converted to Invoice and Transactions created.')));
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
      }
    }
  }

  Future<Order?> _showDispatchDialog(Order order) async {
    String status = order.dispatchStatus;
    DateTime? date = order.dispatchDate ?? DateTime.now();

    return showDialog<Order>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Dispatch Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status == 'pending' ? 'dispatched' : status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['dispatched', 'pending']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => status = v ?? status,
              ),
              ListTile(
                title:
                    Text('Date: ${date?.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  final updated = order.copyWith(
                      dispatchStatus: status, dispatchDate: date);
                  // Also trigger repo update
                  ref
                      .read(orderProvider.notifier)
                      .updateDispatchInfo(order.id, status, date!);
                  Navigator.pop(ctx, updated);
                },
                child: const Text('Save & Continue')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOrderWithProgress(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order?'),
        content: Text('Are you sure you want to delete ${order.orderNumber}?'),
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

    if (confirm != true) return;

    if (!mounted) return;
    // Show loading logic could be here, or just rely on global loading state
    // But local loading is better for UX

    try {
      await ref.read(orderProvider.notifier).deleteOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${order.orderNumber} deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting order: $e')),
        );
      }
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.booked:
        return Colors.blue;
      case OrderStatus.approved:
        return Colors.green;
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.rejected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final orders = orderState.orders;

    // Filter Logic
    final filteredOrders = orders.where((order) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = order.orderNumber.toLowerCase().contains(query) ||
          (order.businessPartnerName?.toLowerCase().contains(query) ?? false);

      // Filter by Type (SO/PO) if strictly required by initialFilterType
      // If we want to allow user to clear it, we'd use a local state variable initialized by widget.
      // But user requested "show only Sales Order" etc.

      var matchesType = true;
      if (_isSoFilter) matchesType = order.orderType == 'SO';
      if (_isPoFilter) matchesType = order.orderType == 'PO';

      if (_filterStatus == 'All') return matchesSearch && matchesType;
      return matchesSearch &&
          matchesType &&
          order.status.displayName == _filterStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSoFilter
            ? 'Sales Orders'
            : _isPoFilter
                ? 'Purchase Orders'
                : 'All Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(orderProvider.notifier).loadOrders(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Auto select type based on filter
          final initialType = _isSoFilter
              ? 'SO'
              : _isPoFilter
                  ? 'PO'
                  : 'SO';

          // Dependency Check
          try {
            // Show loading
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()));

            // Load Data
            await Future.wait([
              ref.read(productProvider.notifier).loadProducts(),
              ref.read(businessPartnerProvider.notifier).loadCustomers(),
              ref.read(businessPartnerProvider.notifier).loadVendors(),
            ]);

            if (!context.mounted) return;
            Navigator.pop(context);

            final products = ref.read(productProvider).products;
            final partnerState = ref.read(businessPartnerProvider);
            final customers = partnerState.customers;
            final vendors = partnerState.vendors;

            final missing = <String>[];
            if (products.isEmpty) missing.add('Product');

            if (initialType == 'SO') {
              if (customers.isEmpty) missing.add('Customer');
            } else {
              if (vendors.isEmpty) missing.add('Vendor');
            }

            if (missing.isNotEmpty) {
              showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text('Missing Requirements'),
                        content: Text(
                            'Please create the following before creating an Order:\n\n• ${missing.join('\n• ')}\n\nYou can create these in the Products or Partners sections.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'))
                        ],
                      ));
              return;
            }

            context.pushNamed(
              'order-create',
              extra: {'initialOrderType': initialType},
            );
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error checking dependencies: $e')));
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Order # or Partner...',
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      dropdownColor: Colors.indigo,
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      style: const TextStyle(color: Colors.white),
                      items:
                          ['All', 'Booked', 'Approved', 'Pending', 'Rejected']
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _filterStatus = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: orderState.isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orderState.error != null
                    ? Center(child: Text('Error: ${orderState.error}'))
                    : filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.list_alt,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  orders.isEmpty
                                      ? 'No orders found.'
                                      : 'No results found.',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredOrders.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        _getStatusColor(order.status)
                                            .withAlpha(26),
                                    child: Icon(
                                      order.orderType == 'PO'
                                          ? Icons.shopping_bag
                                          : Icons.shopping_cart,
                                      color: _getStatusColor(order.status),
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        order.orderNumber,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status)
                                              .withAlpha(26),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  _getStatusColor(order.status)
                                                      .withAlpha(77)),
                                        ),
                                        child: Text(
                                          order.status.displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _getStatusColor(order.status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        context.pushNamed(
                                          'order-edit',
                                          pathParameters: {'id': order.id},
                                        );
                                      } else if (val == 'print') {
                                        _handlePdfAction(order, 'print');
                                      } else if (val == 'preview') {
                                        _handlePdfAction(order, 'preview');
                                      } else if (val == 'share') {
                                        _handlePdfAction(order, 'share');
                                      } else if (val == 'approved') {
                                        ref
                                            .read(orderProvider.notifier)
                                            .updateStatus(
                                                order.id, OrderStatus.approved);
                                      } else if (val == 'rejected') {
                                        ref
                                            .read(orderProvider.notifier)
                                            .updateStatus(
                                                order.id, OrderStatus.rejected);
                                      } else if (val == 'review') {
                                        ref
                                            .read(orderProvider.notifier)
                                            .updateStatus(
                                                order.id, OrderStatus.pending);
                                      } else if (val == 'convert') {
                                        _handleConvertOrder(order);
                                      } else if (val == 'delete') {
                                        _deleteOrderWithProgress(order);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'preview',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility,
                                                color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Preview PDF'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'print',
                                        child: Row(
                                          children: [
                                            Icon(Icons.print,
                                                color: Theme.of(context)
                                                    .iconTheme
                                                    .color),
                                            const SizedBox(width: 8),
                                            const Text('Print'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share,
                                                color: Colors.teal),
                                            SizedBox(width: 8),
                                            Text('Share'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                color: Colors.indigo),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'approved',
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('Approved'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'rejected',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cancel,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Rejected'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'review',
                                        child: Row(
                                          children: [
                                            Icon(Icons.rate_review,
                                                color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Review'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'convert',
                                        child: Row(
                                          children: [
                                            Icon(Icons.receipt_long,
                                                color: Colors.amber),
                                            SizedBox(width: 8),
                                            Text('Convert to Invoice'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.business,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color),
                                          const SizedBox(width: 4),
                                          Text(
                                            order.businessPartnerName ??
                                                'Unknown Partner',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('yyyy-MM-dd')
                                                .format(order.orderDate),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                                fontSize: 13),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Total: ${order.formattedTotal}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    // Navigate to details if needed
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
