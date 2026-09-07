// lib/features/accounting/presentation/screens/transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import 'transaction_form_screen.dart';
import '../utils/transaction_printer.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

import 'package:intl/intl.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/widgets/processing_dialog.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? accountId;
  final String? accountName;
  final bool onlyBankCash;
  final bool onlyCustomers;

  const TransactionsScreen({
    super.key,
    this.accountId,
    this.accountName,
    this.onlyBankCash = false,
    this.onlyCustomers = false,
  });

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final storeId = ref.read(organizationProvider).selectedStore?.id;
      // Load using current global selection
      final sYear =
          ref.read(accountingProvider).selectedFinancialSession?.sYear;
      ref.read(accountingProvider.notifier).loadTransactions(
          organizationId: orgId, storeId: storeId, sYear: sYear);
      ref.read(accountingProvider.notifier).loadAll(organizationId: orgId);
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(businessPartnerProvider.notifier).loadVendors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);

    final transactions = state.transactions.where((t) {
      if (widget.accountId != null) {
        final matchesAccount = t.accountId == widget.accountId ||
            t.offsetAccountId == widget.accountId;
        if (!matchesAccount) return false;
      }

      if (widget.onlyBankCash) {
        // A transaction is bank/cash related if either its account or offset account
        // corresponds to a registered Bank or Cash account.
        final bankAccountIds =
            state.bankCashAccounts.map((b) => b.chartOfAccountId).toSet();
        final isBankCash = bankAccountIds.contains(t.accountId) ||
            (t.offsetAccountId != null &&
                bankAccountIds.contains(t.offsetAccountId));
        if (!isBankCash) return false;
      }

      if (widget.onlyCustomers) {
        // Customer related if moduleAccount is a customer ID
        // OR accountId is Receivable (though moduleAccount check is safer for module links)
        // OR offsetModuleAccount is a customer ID
        final customerIds =
            partnerState.customers.map((c) => c.id).toSet();

        final relatedToCustomer =
            (t.moduleAccount != null && customerIds.contains(t.moduleAccount)) ||
            (t.offsetModuleAccount != null && customerIds.contains(t.offsetModuleAccount));

        if (!relatedToCustomer) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountName != null
            ? 'Account: ${widget.accountName}'
            : widget.onlyBankCash
                ? 'Bank & Cash Transactions'
                : widget.onlyCustomers
                    ? 'Customer Transactions'
                    : 'Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final orgId =
                  ref.read(organizationProvider).selectedOrganizationId;
              final storeId = ref.read(organizationProvider).selectedStore?.id;
              final sYear =
                  ref.read(accountingProvider).selectedFinancialSession?.sYear;
              ref.read(accountingProvider.notifier).loadTransactions(
                  organizationId: orgId, storeId: storeId, sYear: sYear);
            },
          ),
        ],
      ),
      floatingActionButton: (widget.accountId != null ||
              state.selectedFinancialSession?.isClosed == true)
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionFormScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
      body: state.isLoading && transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && transactions.isEmpty
              ? Center(child: Text('Error: ${state.error}'))
              : transactions.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];

                        // Helper to find account name
                        String getAccountName(String glId, {String? moduleId}) {
                          // 1. Resolve Module Account Name if available
                          if (moduleId != null && moduleId.isEmpty == false) {
                            final cust = partnerState.customers
                                .where((c) => c.id == moduleId)
                                .firstOrNull;
                            if (cust != null) return cust.name;

                            final vend = partnerState.vendors
                                .where((v) => v.id == moduleId)
                                .firstOrNull;
                            if (vend != null) return vend.name;

                            final bank = state.bankCashAccounts
                                .where((b) => b.id == moduleId)
                                .firstOrNull;
                            if (bank != null) return bank.name;
                          }

                          // 2. Fallback to General Ledger Account Title
                          final gl = state.accounts
                              .where((a) => a.id == glId)
                              .firstOrNull;
                          if (gl != null) return gl.accountTitle;

                          return 'Unknown Account';
                        }

                        final accountName = getAccountName(tx.accountId,
                            moduleId: tx.moduleAccount);
                        final offsetAccountName = tx.offsetAccountId != null
                            ? getAccountName(tx.offsetAccountId!,
                                moduleId: tx.offsetModuleAccount)
                            : null;

                        final voucherPrefix = state.voucherPrefixes
                            .where((p) => p.id == tx.voucherPrefixId)
                            .firstOrNull;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tx.amount < 0
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                color:
                                    tx.amount < 0 ? Colors.red : Colors.green,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              tx.voucherNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountName,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Date: ${_dateFormat.format(tx.voucherDate)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  NumberFormat.currency(symbol: '')
                                      .format(tx.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: tx.amount < 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Posted',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow('Account', accountName),
                                    if (tx.offsetAccountId != null)
                                      _buildDetailRow(
                                          'Offset Account', offsetAccountName!),
                                    if (tx.description != null &&
                                        tx.description!.isNotEmpty)
                                      _buildDetailRow(
                                          'Description', tx.description!),
                                    if (voucherPrefix != null)
                                      _buildDetailRow('Voucher Type',
                                          voucherPrefix.prefixCode),
                                    if (tx.paymentMode != null)
                                      _buildDetailRow(
                                          'Payment Mode', tx.paymentMode!),
                                    if (tx.invoiceId != null)
                                      _buildDetailRow('Linked Invoice',
                                          '${tx.invoiceId!.substring(0, 8)}...'),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          if (state.financialSessions.any((s) =>
                                              s.sYear == tx.sYear &&
                                              s.isClosed))
                                            const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                  'Read Only (Closed Year)',
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                            )
                                          else ...[
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.edit,
                                                  size: 16),
                                              label: const Text('Edit'),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          TransactionFormScreen(
                                                              transaction: tx)),
                                                );
                                              },
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.print,
                                                  size: 16),
                                              label: const Text('Print'),
                                              onPressed: () async {
                                                final org = ref
                                                    .read(organizationProvider)
                                                    .selectedOrganization;

                                                // Mock ChartOfAccount wrappers for Printer using resolved names
                                                final mockAccount =
                                                    ChartOfAccount(
                                                        id: tx.accountId,
                                                        accountCode: '',
                                                        accountTitle:
                                                            accountName,
                                                        level: 0,
                                                        createdAt:
                                                            DateTime.now(),
                                                        updatedAt:
                                                            DateTime.now(),
                                                        organizationId:
                                                            org?.id ?? 0);
                                                final mockOffset = tx
                                                            .offsetAccountId !=
                                                        null
                                                    ? ChartOfAccount(
                                                        id: tx.offsetAccountId!,
                                                        accountCode: '',
                                                        accountTitle:
                                                            offsetAccountName!,
                                                        level: 0,
                                                        createdAt:
                                                            DateTime.now(),
                                                        updatedAt:
                                                            DateTime.now(),
                                                        organizationId:
                                                            org?.id ?? 0)
                                                    : null;

                                                final voucherPrefix = state
                                                    .voucherPrefixes
                                                    .where((p) =>
                                                        p.id ==
                                                        tx.voucherPrefixId)
                                                    .firstOrNull;

                                                await TransactionPrinter
                                                    .printTransaction(
                                                  tx: tx,
                                                  account: mockAccount,
                                                  offsetAccount: mockOffset,
                                                  org: org,
                                                  voucherTypeName: voucherPrefix
                                                      ?.description,
                                                );
                                              },
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.share,
                                                  size: 16),
                                              label: const Text('Share'),
                                              onPressed: () async {
                                                final org = ref
                                                    .read(organizationProvider)
                                                    .selectedOrganization;
                                                // Mock for printer
                                                final mockAccount =
                                                    ChartOfAccount(
                                                        id: tx.accountId,
                                                        accountCode: '',
                                                        accountTitle:
                                                            accountName,
                                                        level: 0,
                                                        createdAt:
                                                            DateTime.now(),
                                                        updatedAt:
                                                            DateTime.now(),
                                                        organizationId:
                                                            org?.id ?? 0);
                                                final mockOffset = tx
                                                            .offsetAccountId !=
                                                        null
                                                    ? ChartOfAccount(
                                                        id: tx.offsetAccountId!,
                                                        accountCode: '',
                                                        accountTitle:
                                                            offsetAccountName!,
                                                        level: 0,
                                                        createdAt:
                                                            DateTime.now(),
                                                        updatedAt:
                                                            DateTime.now(),
                                                        organizationId:
                                                            org?.id ?? 0)
                                                    : null;

                                                final voucherPrefix = state
                                                    .voucherPrefixes
                                                    .where((p) =>
                                                        p.id ==
                                                        tx.voucherPrefixId)
                                                    .firstOrNull;

                                                await TransactionPrinter
                                                    .shareTransaction(
                                                  tx: tx,
                                                  account: mockAccount,
                                                  offsetAccount: mockOffset,
                                                  org: org,
                                                  voucherTypeName: voucherPrefix
                                                      ?.description,
                                                );
                                              },
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.delete,
                                                  size: 16, color: Colors.red),
                                              label: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                              onPressed: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Delete Transaction'),
                                                    content: const Text(
                                                        'Are you sure you want to delete this transaction?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        style: TextButton
                                                            .styleFrom(
                                                                foregroundColor:
                                                                    Colors.red),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  if (!context.mounted) return;
                                                  await showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) =>
                                                        ProcessingDialog(
                                                      initialMessage:
                                                          'Deleting Transaction...',
                                                      successMessage:
                                                          'Deleted Successfully!',
                                                      task: () async {
                                                        await ref
                                                            .read(
                                                                accountingProvider
                                                                    .notifier)
                                                            .deleteTransaction(
                                                                tx.id);
                                                      },
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SContentText('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class SContentText extends Text {
  const SContentText(super.data, {super.key, super.style});
}
