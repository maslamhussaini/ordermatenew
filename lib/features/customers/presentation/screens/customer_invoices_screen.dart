// lib/features/customers/presentation/screens/customer_invoices_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:uuid/uuid.dart';

class CustomerInvoicesScreen extends ConsumerStatefulWidget {
  final BusinessPartner customer;
  const CustomerInvoicesScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerInvoicesScreen> createState() =>
      _CustomerInvoicesScreenState();
}

class _CustomerInvoicesScreenState
    extends ConsumerState<CustomerInvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currency = 'AED'; // Default

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(accountingRepositoryProvider);
      final orgState = ref.read(organizationProvider);

      // Get currency from matching store or selected store
      String currency = 'AED';
      // Try to find the store from the current list in provider
      final matchingStore = orgState.stores
              .where((s) => s.id == widget.customer.storeId)
              .firstOrNull ??
          orgState.selectedStore;
      if (matchingStore != null) {
        currency = matchingStore.storeDefaultCurrency;
      }

      final results = await repo.getUnpaidInvoices(widget.customer.id,
          organizationId: widget.customer.organizationId);

      // Ensure accounting data like accounts and GL Setup are loaded for receipts
      ref
          .read(accountingProvider.notifier)
          .loadAll(organizationId: widget.customer.organizationId);

      if (mounted) {
        setState(() {
          _invoices = results;
          _currency = currency;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoices List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.customer.name,
                style: TextStyle(fontSize: 13, color: Colors.indigo.shade300)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching invoices...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading invoices',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: _loadInvoices,
                            child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : _invoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('No pending invoices found.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text(
                              'All invoices for this customer are paid or none exist.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInvoices,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'PENDING INVOICES (${_invoices.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                color: Colors.white,
                                child: DataTable(
                                  headingRowHeight: 48,
                                  dataRowMaxHeight: 64,
                                  horizontalMargin: 16,
                                  columnSpacing: 24,
                                  headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                      fontSize: 13),
                                  columns: const [
                                    DataColumn(label: Text('INV #')),
                                    DataColumn(label: Text('DATE')),
                                    DataColumn(label: Text('TOTAL')),
                                    DataColumn(label: Text('PAID')),
                                    DataColumn(label: Text('BALANCE')),
                                    DataColumn(label: Text('DAYS OVERDUE')),
                                    DataColumn(label: Text('ACTION')),
                                  ],
                                  rows: _invoices.map((inv) {
                                    final invoiceDate =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            inv['invoice_date']);
                                    final dueDate = inv['due_date'] != null
                                        ? DateTime.fromMillisecondsSinceEpoch(
                                            inv['due_date'])
                                        : null;

                                    final now = DateTime.now();
                                    int agingDays = 0;
                                    if (dueDate != null) {
                                      agingDays =
                                          now.difference(dueDate).inDays;
                                    }

                                    final totalAmount =
                                        (inv['total_amount'] as num).toDouble();
                                    final paidAmount =
                                        (inv['paid_amount'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                    final balance = totalAmount - paidAmount;

                                    return DataRow(cells: [
                                      DataCell(Text(inv['invoice_number'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500))),
                                      DataCell(Text(DateFormat('MMM dd, yyyy')
                                          .format(invoiceDate))),
                                      DataCell(Text(
                                          '$_currency ${totalAmount.toStringAsFixed(2)}')),
                                      DataCell(Text(
                                          '$_currency ${paidAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: Colors.grey))),
                                      DataCell(Text(
                                          '$_currency ${balance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: agingDays > 0
                                                ? Colors.red.shade50
                                                : Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            agingDays > 0
                                                ? "$agingDays d late"
                                                : agingDays == 0
                                                    ? "Due today"
                                                    : "${agingDays.abs()} d left",
                                            style: TextStyle(
                                              color: agingDays > 0
                                                  ? Colors.red
                                                  : Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ElevatedButton(
                                          onPressed: () => _showReceiptDialog(
                                              widget.customer, inv),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Receipt',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  void _showReceiptDialog(
      BusinessPartner customer, Map<String, dynamic> invoice) async {
    final accountingRepo = ref.read(accountingRepositoryProvider);
    final notifier = ref.read(accountingProvider.notifier);

    // Check GL Setup
    final glSetup =
        await accountingRepo.getGLSetup(customer.organizationId ?? 0);

    if (glSetup == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'GL Setup not found. Please configure accounting settings.')));
      }
      return;
    }

    final prefixes = await accountingRepo.getVoucherPrefixes(
        organizationId: customer.organizationId ?? 0);
    final activeSession = await accountingRepo.getActiveFinancialSession(
        organizationId: customer.organizationId ?? 0);
    final accounts = ref.read(accountingProvider).accounts;

    final cashAccountName = accounts
            .where((a) => a.id == glSetup.cashAccountId)
            .firstOrNull
            ?.accountTitle ??
        'Cash Account';
    final bankAccountName = accounts
            .where((a) => a.id == glSetup.bankAccountId)
            .firstOrNull
            ?.accountTitle ??
        'Bank Account';

    if (!mounted) return;

    String paymentType = 'Cash';
    final totalAmount = (invoice['total_amount'] as num).toDouble();
    final previousPaid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final balance = totalAmount - previousPaid;

    final amountController =
        TextEditingController(text: balance.toStringAsFixed(2));
    final narrationController = TextEditingController(
        text: 'Payment for Invoice ${invoice['invoice_number']}');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Receipt - ${customer.name}',
              style: const TextStyle(color: Colors.indigo)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice #: ${invoice['invoice_number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Payment Type',
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Cash')),
                        selected: paymentType == 'Cash',
                        onSelected: (val) =>
                            setDialogState(() => paymentType = 'Cash'),
                        selectedColor: Colors.indigo.shade100,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Bank')),
                        selected: paymentType == 'Bank',
                        onSelected: (val) =>
                            setDialogState(() => paymentType = 'Bank'),
                        selectedColor: Colors.indigo.shade100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Balance: $_currency ${balance.toStringAsFixed(2)}',
                    suffixText: _currency,
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: false,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: narrationController,
                  decoration: const InputDecoration(
                    labelText: 'Narration',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  'Account: ${paymentType == "Cash" ? cashAccountName : bankAccountName}',
                  style: const TextStyle(
                      color: Colors.indigo,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'Auto-populated from GL Setup',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final targetAccountId = paymentType == 'Cash'
                    ? glSetup.cashAccountId
                    : glSetup.bankAccountId;

                if (targetAccountId == null || targetAccountId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Error: No ${paymentType.toLowerCase()} account configured in GL Setup.')));
                  return;
                }

                if (customer.chartOfAccountId == null ||
                    customer.chartOfAccountId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Error: Customer does not have a linked Chart of Account.')));
                  return;
                }

                final targetPrefixCode = paymentType == 'Cash' ? 'CRV' : 'BRV';
                final prefix = prefixes
                    .where((p) => p.prefixCode == targetPrefixCode)
                    .firstOrNull;

                if (prefix == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Error: No voucher prefix found for $targetPrefixCode.')));
                  return;
                }

                final enteredAmount =
                    double.tryParse(amountController.text) ?? 0.0;

                if (enteredAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please enter a valid payment amount.')));
                  return;
                }

                if (enteredAmount > (balance + 0.01)) {
                  // Allow slight rounding diff
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Amount cannot exceed the balance criteria ($_currency ${balance.toStringAsFixed(2)}).')));
                  return;
                }

                final bankCashAccounts =
                    ref.read(accountingProvider).bankCashAccounts;
                final moduleId = bankCashAccounts
                    .where((bc) => bc.chartOfAccountId == targetAccountId)
                    .firstOrNull
                    ?.id;

                final transaction = Transaction(
                  id: const Uuid().v4(),
                  voucherPrefixId: prefix.id,
                  voucherNumber:
                      '$targetPrefixCode-${DateTime.now().millisecondsSinceEpoch}',
                  voucherDate: DateTime.now(),
                  accountId: targetAccountId,
                  moduleAccount: moduleId,
                  offsetAccountId: customer.chartOfAccountId,
                  offsetModuleAccount: customer.id,
                  amount: enteredAmount,
                  description: narrationController.text,
                  organizationId: customer.organizationId ?? 0,
                  storeId: customer.storeId ?? 0,
                  sYear: activeSession?.sYear,
                  status: 'posted',
                  paymentMode: paymentType,
                  invoiceId: invoice['id'],
                );

                try {
                  await notifier.createTransaction(transaction);

                  final newTotalPaid = previousPaid + enteredAmount;
                  final isFullyPaid = newTotalPaid >= (totalAmount - 0.01);
                  final status = isFullyPaid ? 'Paid' : 'Partial Payment';

                  final updatedInvoice = Invoice(
                    id: invoice['id'],
                    invoiceNumber: invoice['invoice_number'],
                    invoiceDate: DateTime.fromMillisecondsSinceEpoch(
                        invoice['invoice_date']),
                    dueDate: invoice['due_date'] != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            invoice['due_date'])
                        : null,
                    idInvoiceType: invoice['id_invoice_type'],
                    businessPartnerId: invoice['business_partner_id'],
                    orderId: invoice['order_id'],
                    totalAmount: totalAmount,
                    paidAmount: newTotalPaid,
                    status: status,
                    notes: invoice['notes'],
                    organizationId: invoice['organization_id'],
                    storeId: invoice['store_id'],
                  );

                  await notifier.updateInvoice(updatedInvoice);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Receipt saved. Invoice status: $status')));
                    _loadInvoices(); // Refresh list
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving receipt: $e')));
                  }
                }
              },
              child: const Text('Save Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}
