import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/voucher_service.dart';
import 'package:uuid/uuid.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final Invoice invoice;

  const ReceiptScreen({super.key, required this.invoice});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  double _amount = 0.0;
  DateTime _date = DateTime.now();
  String? _selectedAccountId;
  String _reference = '';

  // New Fields
  String _paymentMode = 'Cash';
  final _refNoController = TextEditingController();
  final _refBankController = TextEditingController();
  DateTime _refDate = DateTime.now();

  BusinessPartner? _customer;

  final List<String> _bankPaymentModes = ['Cheque', 'PO', 'DD', 'Online'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() => _paymentMode = 'Cash');
      } else {
        setState(() => _paymentMode = _bankPaymentModes.first);
      }
    });
    _amount = widget.invoice.totalAmount -
        widget.invoice.paidAmount; // Default to balance
    _date = DateTime.now();
    _refDate = DateTime.now();

    // Load Customer
    Future.microtask(() async {
      final partners = ref.read(businessPartnerProvider).customers;
      final customer = partners
          .where((c) => c.id == widget.invoice.businessPartnerId)
          .firstOrNull;
      if (mounted) setState(() => _customer = customer);

      // Load Accounts
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await ref
          .read(accountingProvider.notifier)
          .loadAll(organizationId: orgId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refNoController.dispose();
    _refBankController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final notifier = ref.read(accountingProvider.notifier);
        final state = ref.read(accountingProvider);
        final orgId = ref.read(organizationProvider).selectedOrganizationId;
        final storeId = ref.read(organizationProvider).selectedStore?.id;

        if (orgId == null || storeId == null) {
          throw Exception('Organization or Store not selected');
        }

        // 1. Get Voucher Prefix for Receipt
        final prefix = state.voucherPrefixes.firstWhere(
          (p) =>
              p.voucherType.replaceAll(' ', '_') == 'RECEIPT' ||
              p.voucherType.replaceAll(' ', '_') == 'PAYMENT_VOUCHER' ||
              p.prefixCode == 'RV' ||
              p.prefixCode == 'CRV',
          orElse: () =>
              throw Exception('Receipt Voucher prefix not configured'),
        );

        // 2. Generate Voucher Number
        final voucherService = ref.read(voucherServiceProvider);
        final voucherNumber = await voucherService.generateVoucherNumber(
          prefixCode: prefix.prefixCode,
          storeId: storeId,
        );

        // 3. Get Sub-Ledger (Offset Account) - The Customer
        final customerCOAId = _customer?.chartOfAccountId;
        if (customerCOAId == null) {
          throw Exception('Customer has no linked Chart of Account');
        }

        // 4. Create Transaction
        // Dr Bank/Cash Account (accountId)
        // Cr Customer Account (offsetAccountId)
        final transaction = Transaction(
          id: const Uuid().v4(),
          voucherPrefixId: prefix.id,
          voucherNumber: voucherNumber,
          voucherDate: _date,
          accountId: _selectedAccountId!, // The Bank or Cash account selected
          offsetAccountId: customerCOAId, // The Customer's Receivable account
          offsetModuleAccount: widget.invoice.businessPartnerId,
          amount: _amount,
          description: _reference.isEmpty
              ? 'Receipt for Invoice #${widget.invoice.invoiceNumber}'
              : _reference,
          organizationId: orgId,
          storeId: storeId,
          paymentMode: _paymentMode,
          referenceNumber:
              _paymentMode == 'Cash' ? null : _refNoController.text,
          referenceDate: _paymentMode == 'Cash' ? null : _refDate,
          referenceBank:
              _paymentMode == 'Cash' ? null : _refBankController.text,
          invoiceId: widget.invoice.id,
        );

        await notifier.createTransaction(transaction);

        // 5. Update Invoice
        final newPaidAmount = widget.invoice.paidAmount + _amount;
        final newStatus = (newPaidAmount >= widget.invoice.totalAmount - 0.01)
            ? 'Paid'
            : 'Partial';

        final updatedInvoice = widget.invoice.copyWith(
          paidAmount: newPaidAmount,
          status: newStatus,
          updatedAt: DateTime.now(),
        );

        await notifier.updateInvoice(updatedInvoice);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Receipt saved successfully for Invoice #${widget.invoice.invoiceNumber}')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error saving receipt: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final store = ref.watch(organizationProvider).selectedStore;
    final currencySymbol = store?.storeDefaultCurrency ?? '\$';

    // Filter Bank/Cash accounts from the same source table (omtbl_bank_cash)
    // Heuristic: 'Cash' usually in name for Cash accounts.
    final cashAccounts = state.bankCashAccounts
        .where((b) => b.name.toLowerCase().contains('cash'))
        .toList();
    final bankAccounts = state.bankCashAccounts
        .where((b) => !b.name.toLowerCase().contains('cash'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt - ${widget.invoice.invoiceNumber}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Cash', icon: Icon(Icons.money)),
            Tab(text: 'Bank', icon: Icon(Icons.account_balance)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                        Text(_customer?.name ?? 'Loading...',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Invoice Amount',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                        Text(
                          NumberFormat.currency(symbol: currencySymbol)
                              .format(widget.invoice.totalAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // CASH TAB
                  _buildPaymentForm(
                    cashAccounts
                        .map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)))
                        .toList(),
                    'Cash Account',
                    currencySymbol,
                    isBank: false,
                  ),

                  // BANK TAB
                  _buildPaymentForm(
                    bankAccounts
                        .map((e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)))
                        .toList(),
                    'Bank Account',
                    currencySymbol,
                    isBank: true,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save Receipt'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(
      List<DropdownMenuItem<String>> items, String label, String currencySymbol,
      {required bool isBank}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                  label.contains('Bank') ? Icons.account_balance : Icons.money),
            ),
            items: items,
            onChanged: (val) => setState(() => _selectedAccountId = val),
            validator: (val) => val == null ? 'Please select an account' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _amount.toString(),
            decoration: InputDecoration(
              labelText: 'Received Amount',
              border: const OutlineInputBorder(),
              prefixText: '$currencySymbol ',
              prefixStyle: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              if (val.isNotEmpty && double.tryParse(val) != null) {
                _amount = double.parse(val);
              }
            },
            validator: (val) {
              if (val == null || val.isEmpty) return 'Required';
              if (double.tryParse(val) == null) return 'Invalid number';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: TextEditingController(
                text: DateFormat('yyyy-MM-dd').format(_date)),
            decoration: const InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (isBank) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode == 'Cash'
                  ? _bankPaymentModes.first
                  : _paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: _bankPaymentModes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _paymentMode = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refNoController,
              decoration: const InputDecoration(
                labelText: 'Reference / Cheque Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: TextEditingController(
                  text: DateFormat('yyyy-MM-dd').format(_refDate)),
              decoration: const InputDecoration(
                labelText: 'Reference Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month),
              ),
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _refDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _refDate = picked);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refBankController,
              decoration: const InputDecoration(
                labelText: 'Reference Bank',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: 'Cash',
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
              ),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash'))
              ],
              onChanged: null, // Disabled for Cash tab
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _reference,
            decoration: const InputDecoration(
              labelText: 'Narration / Notes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
            onChanged: (val) => _reference = val,
          ),
        ],
      ),
    );
  }
}
