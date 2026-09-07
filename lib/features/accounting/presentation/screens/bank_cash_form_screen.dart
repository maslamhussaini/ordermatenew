// lib/features/accounting/presentation/screens/bank_cash_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

import 'package:uuid/uuid.dart';

class BankCashFormScreen extends ConsumerStatefulWidget {
  final String? bankCashId;
  const BankCashFormScreen({super.key, this.bankCashId});

  @override
  ConsumerState<BankCashFormScreen> createState() => _BankCashFormScreenState();
}

class _BankCashFormScreenState extends ConsumerState<BankCashFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedCoaId;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Try to find in current state (fast path) to populate immediately
    if (widget.bankCashId != null) {
      final currentState = ref.read(accountingProvider);
      final account = currentState.bankCashAccounts
          .where((a) => a.id == widget.bankCashId)
          .firstOrNull;

      if (account != null) {
        _populateForm(account);
        // Ensure dropdown options are loaded if empty (e.g. direct deep link/refresh)
        if (currentState.accounts.isEmpty) {
          final org = ref.read(organizationProvider).selectedOrganization;
          await ref
              .read(accountingProvider.notifier)
              .loadAll(organizationId: org?.id);
          // After load, ensure we setState to refresh dropdown
          if (mounted) setState(() {});
        }
        return;
      }
    }

    // 2. Fallback: Load All and try again (slow path)
    final org = ref.read(organizationProvider).selectedOrganization;
    await ref
        .read(accountingProvider.notifier)
        .loadAll(organizationId: org?.id);

    if (widget.bankCashId != null) {
      final account = ref
          .read(accountingProvider)
          .bankCashAccounts
          .where((a) => a.id == widget.bankCashId)
          .firstOrNull;
      if (account != null) {
        _populateForm(account);
      }
    }
  }

  void _populateForm(BankCash account) {
    _nameController.text = account.name;
    _accountNumberController.text = account.accountNumber ?? '';
    _branchNameController.text = account.branchName ?? '';
    _selectedCoaId = account.chartOfAccountId;
    _isActive = account.status;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _branchNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCoaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a Chart of Account ledger')),
      );
      return;
    }

    final org = ref.read(organizationProvider).selectedOrganization;
    final store = ref.read(organizationProvider).selectedStore;

    setState(() => _isLoading = true);
    try {
      final account = BankCash(
        id: widget.bankCashId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        branchName: _branchNameController.text.trim(),
        chartOfAccountId: _selectedCoaId!,
        organizationId: org?.id ?? 0,
        storeId: store?.id ?? 0,
        status: _isActive,
      );

      final notifier = ref.read(accountingProvider.notifier);
      if (widget.bankCashId == null) {
        await notifier.createBankCashAccount(account, organizationId: org?.id);
      } else {
        await notifier.updateBankCashAccount(account, organizationId: org?.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank/Cash account saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);

    // Filter CoA: Level 4 and Category 'Bank & Cash'
    final bankCashCategoryId = state.categories
        .where((c) =>
            c.categoryName.toLowerCase().contains('bank') ||
            c.categoryName.toLowerCase().contains('cash'))
        .map((c) => c.id)
        .toList();

    final filteredCoa = state.accounts.where((a) {
      final title = a.accountTitle.toLowerCase();
      final hasBankCashTitle = title.contains('bank') || title.contains('cash');
      final matchesCategory = a.accountCategoryId != null &&
          bankCashCategoryId.contains(a.accountCategoryId!);

      // Allow Level 3 or 4 accounts that match by category OR title
      return (a.level == 3 || a.level == 4) &&
          (matchesCategory || hasBankCashTitle);
    }).toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bankCashId == null
            ? 'Add Bank/Cash Account'
            : 'Edit Bank/Cash Account'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Details',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.indigo
                                    : Colors.indigoAccent),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Account Name',
                          hintText: 'e.g. Main Cash, HBL Bank...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.account_balance),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade50
                                  : Colors.white.withValues(alpha: 0.1),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _accountNumberController,
                        decoration: InputDecoration(
                          labelText: 'Account Number',
                          hintText: 'e.g. 1234567890',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.numbers),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade50
                                  : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _branchNameController,
                        decoration: InputDecoration(
                          labelText: 'Branch Name',
                          hintText: 'e.g. Downtown Branch',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_on),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade50
                                  : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedCoaId),
                        initialValue: _selectedCoaId,
                        decoration: InputDecoration(
                          labelText: 'Linked Ledger (Chart of Account)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.account_tree),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade50
                                  : Colors.white.withValues(alpha: 0.1),
                        ),
                        items: filteredCoa.map((coa) {
                          return DropdownMenuItem(
                            value: coa.id,
                            child: Text(
                                '${coa.accountCode} - ${coa.accountTitle}'),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCoaId = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      if (filteredCoa.isEmpty && !state.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'No Level 4 Bank/Cash ledgers found in Chart of Accounts.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'This account must be linked to a specific ledger in your Chart of Accounts.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade50
                                  : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade200
                                    : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: SwitchListTile(
                          title: const Text('Is Active'),
                          subtitle: const Text(
                              'Inactive accounts won\'t appear in vouchers'),
                          value: _isActive,
                          activeThumbColor: Colors.indigo,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            widget.bankCashId == null
                                ? 'CREATE ACCOUNT'
                                : 'UPDATE ACCOUNT',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1),
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
