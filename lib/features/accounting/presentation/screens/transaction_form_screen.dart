import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/widgets/loading_overlay.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/voucher_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/widgets/processing_dialog.dart';
import 'package:uuid/uuid.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final bool _isLoading = false;

  // Maps to help reverse-lookup for Editing
  // We need to know if a Transaction GL ID belongs to a Partner or Bank to set the Dropdown ID correctly
  String? _initialAccountId;
  String? _initialOffsetAccountId;
  bool _isReadOnly = false;
  String? _readOnlyReason;

  @override
  void initState() {
    super.initState();
    // Ensure data is loaded
    Future.microtask(() async {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      await ref
          .read(accountingProvider.notifier)
          .loadAll(organizationId: orgId);
      await ref.read(businessPartnerProvider.notifier).loadCustomers();
      await ref.read(businessPartnerProvider.notifier).loadVendors();

      if (widget.transaction != null) {
        _resolveInitialValues();
      }
    });
  }

  void _resolveInitialValues() {
    if (widget.transaction == null) return;
    final tx = widget.transaction!;
    final accountingState = ref.read(accountingProvider);
    final partnerState = ref.read(businessPartnerProvider);

    // Resolve Account ID
    String? resolvedAccount = tx.accountId;
    // Check Banks
    final bank = accountingState.bankCashAccounts
        .where((b) => b.chartOfAccountId == tx.accountId)
        .firstOrNull;
    if (bank != null) {
      resolvedAccount = bank.id;
    } else {
      // Check Partners
      final cust = partnerState.customers
          .where((c) => c.chartOfAccountId == tx.accountId)
          .firstOrNull;
      if (cust != null) {
        resolvedAccount = cust.id;
      } else {
        final vend = partnerState.vendors
            .where((v) => v.chartOfAccountId == tx.accountId)
            .firstOrNull;
        if (vend != null) resolvedAccount = vend.id;
      }
    }

    // Resolve Offset Account ID
    String? resolvedOffset = tx.offsetAccountId;
    if (resolvedOffset != null) {
      final bankOffset = accountingState.bankCashAccounts
          .where((b) => b.chartOfAccountId == resolvedOffset)
          .firstOrNull;
      if (bankOffset != null) {
        resolvedOffset = bankOffset.id;
      } else {
        final custOffset = partnerState.customers
            .where((c) => c.chartOfAccountId == resolvedOffset)
            .firstOrNull;
        if (custOffset != null) {
          resolvedOffset = custOffset.id;
        } else {
          final vendOffset = partnerState.vendors
              .where((v) => v.chartOfAccountId == resolvedOffset)
              .firstOrNull;
          if (vendOffset != null) resolvedOffset = vendOffset.id;
        }
      }
    }

    // Check Read Only
    if (tx.sYear != null) {
      final session = accountingState.financialSessions
          .cast<FinancialSession?>()
          .firstWhere((s) => s?.sYear == tx.sYear, orElse: () => null);
      if (session != null && session.isClosed) {
        _isReadOnly = true;
        _readOnlyReason =
            'This transaction belongs to a closed financial year (${session.sYear}).';
      }
    }

    if (mounted) {
      setState(() {
        _initialAccountId = resolvedAccount;
        _initialOffsetAccountId = resolvedOffset;
      });
      // Force update form values if needed
      _formKey.currentState?.fields['account_id']?.didChange(resolvedAccount);
      _formKey.currentState?.fields['offset_account_id']
          ?.didChange(resolvedOffset);
    }
  }

  Future<void> _saveTransaction() async {
    // Check for selected financial session first
    final accountingState = ref.read(accountingProvider);
    if (accountingState.selectedFinancialSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No Financial Session selected. Please select one from the Dashboard.')));
      return;
    }

    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProcessingDialog(
          initialMessage: widget.transaction != null
              ? 'Updating Transaction...'
              : 'Posting Transaction...',
          successMessage: widget.transaction != null
              ? 'Updated Successfully!'
              : 'Posted Successfully!',
          task: () async {
            final values = _formKey.currentState!.value;
            final org = ref.read(organizationProvider).selectedOrganization;
            final store = ref.read(organizationProvider).selectedStore;
            // sYear will be validated and set by the provider logic
            const int sYear = 0;

            String voucherNumber = widget.transaction?.voucherNumber ?? '';

            if (widget.transaction == null) {
              final prefixId = values['voucher_prefix_id'] as int;
              final prefixes = ref.read(accountingProvider).voucherPrefixes;
              final prefix = prefixes.firstWhere((p) => p.id == prefixId);

              voucherNumber = await ref
                  .read(voucherServiceProvider)
                  .generateVoucherNumber(
                      prefixCode: prefix.prefixCode, storeId: store?.id ?? 0);
            }

            final accountingState = ref.read(accountingProvider);
            final partnerState = ref.read(businessPartnerProvider);

            String resolveGlId(String selectedId) {
              final bank = accountingState.bankCashAccounts
                  .where((b) => b.id == selectedId)
                  .firstOrNull;
              if (bank != null) return bank.chartOfAccountId;

              final cust = partnerState.customers
                  .where((c) => c.id == selectedId)
                  .firstOrNull;
              if (cust != null) return cust.chartOfAccountId ?? '';

              final vend = partnerState.vendors
                  .where((v) => v.id == selectedId)
                  .firstOrNull;
              if (vend != null) return vend.chartOfAccountId ?? '';

              return selectedId;
            }

            String? resolveModuleId(String selectedId) {
              final bank = accountingState.bankCashAccounts
                  .where((b) => b.id == selectedId)
                  .firstOrNull;
              if (bank != null) return bank.id;

              final cust = partnerState.customers
                  .where((c) => c.id == selectedId)
                  .firstOrNull;
              if (cust != null) return cust.id;

              final vend = partnerState.vendors
                  .where((v) => v.id == selectedId)
                  .firstOrNull;
              if (vend != null) return vend.id;

              return null;
            }

            final accountId = resolveGlId(values['account_id']);
            final moduleAccount = resolveModuleId(values['account_id']);

            String? offsetAccountId;
            String? offsetModuleAccount;
            if (values['offset_account_id'] != null) {
              offsetAccountId = resolveGlId(values['offset_account_id']);
              offsetModuleAccount =
                  resolveModuleId(values['offset_account_id']);
            }

            if (accountId.isEmpty) {
              throw Exception(
                  "Selected entity does not have a linked GL Account");
            }

            final transaction = Transaction(
              id: widget.transaction?.id ?? const Uuid().v4(),
              voucherPrefixId: values['voucher_prefix_id'] as int,
              voucherNumber: voucherNumber,
              voucherDate: values['voucher_date'] as DateTime,
              accountId: accountId,
              offsetAccountId: offsetAccountId,
              amount: double.parse(values['amount'].toString()),
              description: values['description'] as String?,
              status: 'posted',
              organizationId: org?.id ?? 0,
              storeId: store?.id ?? 0,
              sYear: sYear,
              moduleAccount: moduleAccount,
              offsetModuleAccount: offsetModuleAccount,
            );

            if (widget.transaction != null) {
              await ref
                  .read(accountingProvider.notifier)
                  .updateTransaction(transaction);
            } else {
              await ref
                  .read(accountingProvider.notifier)
                  .createTransaction(transaction);
            }
          },
        ),
      );

      if (success == true && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);

    final prefixes = state.voucherPrefixes;

    final glAccounts = state.accounts.where((a) => a.isActive).toList();
    glAccounts.sort((a, b) => a.accountTitle.compareTo(b.accountTitle));

    final customers = partnerState.customers;
    final vendors = partnerState.vendors;
    final banks = state.bankCashAccounts.where((b) => b.status).toList();

    final allAccountItems = <DropdownMenuItem<String>>[];

    // GL Accounts
    for (var a in glAccounts) {
      allAccountItems.add(DropdownMenuItem(
        value: a.id,
        child: Text('${a.accountCode} - ${a.accountTitle}'),
      ));
    }

    // Banks
    for (var b in banks) {
      allAccountItems.add(DropdownMenuItem(
        value: b.id,
        child: Text('[BANK] ${b.name}'),
      ));
    }

    // Customers
    for (var c in customers) {
      allAccountItems.add(DropdownMenuItem(
        value: c.id,
        child: Text('[CUST] ${c.name}'),
      ));
    }

    // Vendors
    for (var v in vendors) {
      allAccountItems.add(DropdownMenuItem(
        value: v.id,
        child: Text('[VEND] ${v.name}'),
      ));
    }

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.transaction != null
              ? 'Edit Transaction'
              : 'New Transaction'),
        ),
        body: state.isLoading && state.accounts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: FormBuilder(
                  key: _formKey,
                  initialValue: widget.transaction != null
                      ? {
                          'voucher_prefix_id': prefixes.any((p) =>
                                  p.id == widget.transaction!.voucherPrefixId)
                              ? widget.transaction!.voucherPrefixId
                              : null,
                          'voucher_date': widget.transaction!.voucherDate,
                          'account_id': _initialAccountId ??
                              widget.transaction!.accountId,
                          'offset_account_id': _initialOffsetAccountId ??
                              widget.transaction!.offsetAccountId,
                          'amount': widget.transaction!.amount.toString(),
                          'description': widget.transaction!.description,
                        }
                      : {
                          'voucher_date': DateTime.now(),
                        },
                  child: Column(
                    children: [
                      if (_isReadOnly)
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
                                  child: Text(_readOnlyReason ?? 'Read Only',
                                      style: const TextStyle(
                                          color: Colors.black87))),
                            ],
                          ),
                        ),

                      // Voucher Prefix
                      FormBuilderDropdown<int>(
                        name: 'voucher_prefix_id',
                        decoration: const InputDecoration(
                            labelText: 'Voucher Type',
                            border: OutlineInputBorder()),
                        validator: FormBuilderValidators.required(),
                        enabled: !_isReadOnly && widget.transaction == null,
                        items: prefixes
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                      '${p.voucherType} (${p.prefixCode})'),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      // Voucher Number
                      if (widget.transaction != null) ...[
                        FormBuilderTextField(
                          name: 'voucher_number',
                          initialValue: widget.transaction!.voucherNumber,
                          decoration: const InputDecoration(
                              labelText: 'Voucher Number',
                              border: OutlineInputBorder()),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Date
                      FormBuilderDateTimePicker(
                        name: 'voucher_date',
                        inputType: InputType.date,
                        format: DateFormat('dd MMM yyyy'),
                        decoration: const InputDecoration(
                            labelText: 'Date', border: OutlineInputBorder()),
                        validator: FormBuilderValidators.required(),
                        enabled: !_isReadOnly,
                      ),
                      const SizedBox(height: 16),

                      // Account
                      FormBuilderDropdown<String>(
                        name: 'account_id',
                        decoration: const InputDecoration(
                            labelText: 'Account', border: OutlineInputBorder()),
                        validator: FormBuilderValidators.required(),
                        items: allAccountItems,
                        enabled: !_isReadOnly,
                      ),
                      const SizedBox(height: 16),

                      // Offset Account
                      FormBuilderDropdown<String>(
                        name: 'offset_account_id',
                        decoration: const InputDecoration(
                            labelText: 'Offset Account (Optional)',
                            border: OutlineInputBorder()),
                        items: allAccountItems,
                        enabled: !_isReadOnly,
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      FormBuilderTextField(
                        name: 'amount',
                        decoration: const InputDecoration(
                            labelText: 'Amount', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.numeric(),
                          FormBuilderValidators.min(0),
                        ]),
                        enabled: !_isReadOnly,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      FormBuilderTextField(
                        name: 'description',
                        decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder()),
                        maxLines: 3,
                        enabled: !_isReadOnly,
                      ),
                      const SizedBox(height: 24),

                      if (!_isReadOnly)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveTransaction,
                            child: const Text('Save Transaction'),
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
