import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/services/pdf_invoice_service.dart';
import 'package:ordermate/core/router/route_names.dart';

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/screens/pdf_preview_screen.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:ordermate/core/providers/auth_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  final String? initialFilterType;
  const InvoicesScreen({super.key, this.initialFilterType});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';
  late String? _filterType;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    Future.microtask(() {
      final orgState = ref.read(organizationProvider);
      final orgId = orgState.selectedOrganizationId;
      final storeId = orgState.selectedStore?.id;
      final sYear = orgState.selectedFinancialYear;

      ref.read(accountingProvider.notifier).loadInvoices(
            organizationId: orgId,
            storeId: storeId,
            sYear: sYear,
          );
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(businessPartnerProvider.notifier).loadVendors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (_filterType) {
      case 'SI':
        return 'Sales Invoices';
      case 'SR':
        return 'Sales Returns';
      case 'PI':
        return 'Purchase Invoices';
      case 'PR':
        return 'Purchase Returns';
      default:
        return 'All Invoices';
    }
  }

  Future<void> _handlePdfAction(Invoice invoice, String action) async {
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
      // 1. Fetch Data
      statusMessage.value = 'Fetching invoice items...';
      progressValue.value = 0.1;
      final itemsList = await ref
          .read(accountingProvider.notifier)
          .getInvoiceItems(invoice.id)
          .timeout(const Duration(seconds: 10));
      final items = itemsList.map((e) {
        final amount = e.rate * e.quantity;
        return {
          'product_name': e.productName,
          'quantity': e.quantity,
          'rate': e.rate,
          'total': e.total,
          'uom_symbol': e.uomSymbol,
          'discount_percent': e.discountPercent,
          'discount': amount - e.total, // Calculate discount amount
        };
      }).toList();

      statusMessage.value = 'Fetching partner details...';
      progressValue.value = 0.2;
      final bpState = ref.read(businessPartnerProvider);
      final partner = bpState.customers
              .where((c) => c.id == invoice.businessPartnerId)
              .firstOrNull ??
          bpState.vendors
              .where((v) => v.id == invoice.businessPartnerId)
              .firstOrNull;

      if (partner == null) throw Exception('Business Partner not found');

      final orgState = ref.read(organizationProvider);
      final org = orgState.selectedOrganization;
      final store = orgState.selectedStore ??
          (orgState.stores.isNotEmpty ? orgState.stores.first : null);

      // Fetch Logo
      statusMessage.value = 'Fetching organization logo...';
      progressValue.value = 0.25;

      Uint8List? logoBytes;
      if (org != null && org.logoUrl != null) {
        try {
          final response = await http
              .get(Uri.parse(org.logoUrl!))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) logoBytes = response.bodyBytes;
        } catch (_) {}
      }

      // Convert Invoice to Order-like structure for the PdfService (which currently expects Order)
      // Or we can update the PdfService. For now, let's mock the Order object
      final mockOrder = Order(
        id: invoice.id,
        orderNumber: invoice.invoiceNumber,
        businessPartnerId: invoice.businessPartnerId,
        orderType: invoice.idInvoiceType, // Pass internal code SI/SIR
        createdBy: '',
        createdByName:
            ref.read(authProvider).userFullName, // Get current user name
        status: OrderStatus.approved,
        totalAmount: invoice.totalAmount,
        orderDate: invoice.invoiceDate,
        createdAt: invoice.createdAt ?? DateTime.now(),
        updatedAt: invoice.updatedAt ?? DateTime.now(),
        sYear: invoice.sYear,
        organizationId: org?.id ?? 0,
        storeId: store?.id ?? 0,
      );

      statusMessage.value = 'Preparing PDF Engine...';
      progressValue.value = 0.3;

      final pdfBytes = await PdfInvoiceService()
          .generateInvoice(
              order: mockOrder,
              items: items,
              customer: partner,
              organizationName: org?.name,
              storeName: store?.name,
              storePhone: store?.phone,
              storeAddress: [
                store?.location ?? '',
                store?.city ?? '',
                store?.postalCode ?? '',
                store?.country ?? '',
              ].where((s) => s.isNotEmpty).join(', '),
              logoBytes: logoBytes,
              settings: ref.read(settingsProvider).pdfSettings,
              currencyCode: store?.storeDefaultCurrency ?? 'PKR',
              onProgress: (msg, val) {
                statusMessage.value = msg;
                progressValue.value = val;
              })
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pop(); // Close loading dialog correctly

      statusMessage.value = 'Opening PDF...';
      final filename = '${invoice.invoiceNumber}.pdf';
      switch (action) {
        case 'print':
          await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdfBytes,
              name: filename);
        case 'preview':
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) =>
                  PdfPreviewScreen(pdfBytes: pdfBytes, fileName: filename)));
        case 'share':
          await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateStatus(Invoice invoice, String newStatus) async {
    try {
      if (newStatus == 'Posted') {
        await ref.read(accountingProvider.notifier).postInvoice(invoice);
      } else {
        final updated = invoice.copyWith(status: newStatus);
        await ref.read(accountingProvider.notifier).updateInvoice(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invoice ${newStatus.toLowerCase()} successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content:
            Text('Are you sure you want to delete ${invoice.invoiceNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(accountingRepositoryProvider).deleteInvoice(invoice.id);
        final orgId = ref.read(organizationProvider).selectedOrganizationId;
        final storeId = ref.read(organizationProvider).selectedStore?.id;
        await ref
            .read(accountingProvider.notifier)
            .loadInvoices(organizationId: orgId, storeId: storeId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Invoice deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    ref.watch(organizationProvider);
    final invoices = state.invoices;
    final isLoading = state.isLoading;

    // Reload if organization or store changes
    ref.listen(organizationProvider, (previous, next) {
      if (previous?.selectedOrganizationId != next.selectedOrganizationId ||
          previous?.selectedStore?.id != next.selectedStore?.id ||
          previous?.selectedFinancialYear != next.selectedFinancialYear) {
        ref.read(accountingProvider.notifier).loadInvoices(
              organizationId: next.selectedOrganizationId,
              storeId: next.selectedStore?.id,
              sYear: next.selectedFinancialYear,
            );
      }
    });

    // Filter Logic
    final filteredInvoices = invoices.where((invoice) {
      final query = _searchQuery.toLowerCase();
      final partnerName = partnerState.customers
              .where((c) => c.id == invoice.businessPartnerId)
              .firstOrNull
              ?.name ??
          '';

      final matchesSearch =
          invoice.invoiceNumber.toLowerCase().contains(query) ||
              partnerName.toLowerCase().contains(query);

      // Type Filter
      if (_filterType != null && invoice.idInvoiceType != _filterType) {
        return false;
      }

      if (_filterStatus == 'All') return matchesSearch;
      return matchesSearch &&
          invoice.status.toLowerCase() == _filterStatus.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final orgState = ref.read(organizationProvider);
              final orgId = orgState.selectedOrganizationId;
              final storeId = orgState.selectedStore?.id;
              final sYear = orgState.selectedFinancialYear;
              ref.read(accountingProvider.notifier).loadInvoices(
                    organizationId: orgId,
                    storeId: storeId,
                    sYear: sYear,
                  );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/invoices/create',
              extra: {'idInvoiceType': _filterType ?? 'SI'});
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
                      hintText: 'Search Invoice # or Customer...',
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
                      items: ['All', 'Draft', 'Posted', 'Paid', 'Cancelled']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ))
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

          // Invoices List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${state.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                final orgState = ref.read(organizationProvider);
                                ref
                                    .read(accountingProvider.notifier)
                                    .loadInvoices(
                                      organizationId:
                                          orgState.selectedOrganizationId,
                                      storeId: orgState.selectedStore?.id,
                                      sYear: orgState.selectedFinancialYear,
                                    );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredInvoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                const Text('No invoices found',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              final orgState = ref.read(organizationProvider);
                              final orgId = orgState.selectedOrganizationId;
                              final storeId = orgState.selectedStore?.id;
                              final sYear = orgState.selectedFinancialYear;
                              await ref
                                  .read(accountingProvider.notifier)
                                  .loadInvoices(
                                    organizationId: orgId,
                                    storeId: storeId,
                                    sYear: sYear,
                                  );
                            },
                            child: ListView.builder(
                              itemCount: filteredInvoices.length,
                              padding: const EdgeInsets.only(bottom: 80),
                              itemBuilder: (context, index) {
                                final invoice = filteredInvoices[index];
                                final partnerName = partnerState.customers
                                        .where((c) =>
                                            c.id == invoice.businessPartnerId)
                                        .firstOrNull
                                        ?.name ??
                                    'Customer #${invoice.businessPartnerId.substring(0, 8)}...';

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      invoice.invoiceNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partnerName,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Date: ${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          NumberFormat.currency(symbol: '')
                                              .format(invoice.totalAmount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                _getStatusColor(invoice.status)
                                                    .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            invoice.status,
                                            style: TextStyle(
                                              color: _getStatusColor(
                                                  invoice.status),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            alignment: WrapAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => context.push(
                                                    '/invoices/${invoice.id}'),
                                                icon: const Icon(
                                                    Icons.visibility,
                                                    size: 16),
                                                label: const Text('View'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _handlePdfAction(
                                                        invoice, 'print'),
                                                icon: const Icon(Icons.print,
                                                    size: 16),
                                                label: const Text('Print'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _handlePdfAction(
                                                        invoice, 'share'),
                                                icon: const Icon(Icons.share,
                                                    size: 16),
                                                label: const Text('Share'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => context.push(
                                                    '/invoices/edit/${invoice.id}'),
                                                icon: const Icon(Icons.edit,
                                                    size: 16),
                                                label: const Text('Edit'),
                                              ),
                                              if (invoice.status
                                                          .toLowerCase() !=
                                                      'posted' &&
                                                  invoice.status
                                                          .toLowerCase() !=
                                                      'paid')
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _updateStatus(
                                                          invoice, 'Posted'),
                                                  icon: const Icon(
                                                      Icons.check_circle,
                                                      size: 16),
                                                  label: const Text('Post'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              Colors.green),
                                                ),
                                              if (invoice.status
                                                          .toLowerCase() ==
                                                      'posted' &&
                                                  invoice.status
                                                          .toLowerCase() !=
                                                      'paid')
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      context.pushNamed(
                                                          RouteNames.receipt,
                                                          extra: invoice),
                                                  icon: const Icon(
                                                      Icons.payments,
                                                      size: 16),
                                                  label: const Text('Receipt'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              Colors.green),
                                                ),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _deleteInvoice(invoice),
                                                icon: const Icon(Icons.delete,
                                                    size: 16),
                                                label: const Text('Delete'),
                                                style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'posted':
        return Colors.blue;
      case 'draft':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
