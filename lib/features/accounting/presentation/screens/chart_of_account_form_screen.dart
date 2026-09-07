// lib/features/accounting/presentation/screens/chart_of_account_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class ChartOfAccountFormScreen extends ConsumerStatefulWidget {
  final String? accountId;
  const ChartOfAccountFormScreen({super.key, this.accountId});

  @override
  ConsumerState<ChartOfAccountFormScreen> createState() =>
      _ChartOfAccountFormScreenState();
}

class _ChartOfAccountFormScreenState
    extends ConsumerState<ChartOfAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();

  String? _selectedParentId;
  int? _selectedCategoryId;
  int _level = 2;
  bool _isActive = true;
  bool _isSystem = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) {
      final account = ref
          .read(accountingProvider)
          .accounts
          .where((a) => a.id == widget.accountId)
          .firstOrNull;
      if (account != null) {
        _titleController.text = account.accountTitle;
        _codeController.text = account.accountCode;
        _selectedParentId = account.parentId;
        _selectedCategoryId = account.accountCategoryId;
        _level = account.level;
        _isActive = account.isActive;
        _isSystem = account.isSystem;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final state = ref.read(accountingProvider);
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;

      // If editing, use the existing account's organizationId if the current one is null
      int? finalOrgId = orgId;
      if (finalOrgId == null && widget.accountId != null) {
        final existingAccount =
            state.accounts.where((a) => a.id == widget.accountId).firstOrNull;
        finalOrgId = existingAccount?.organizationId;
      }

      // Find the account type ID from the selected category
      int? typeId;
      if (_selectedCategoryId != null) {
        // FIX (H-10): unguarded firstWhere threw StateError mid-save, losing
        // the user's input, if the selected category had been removed from
        // the cached list.
        final category = state.categories
            .where((c) => c.id == _selectedCategoryId)
            .firstOrNull;
        if (category == null) {
          throw Exception(
              'The selected account category is no longer available. Please reselect it.');
        }
        typeId = category.accountTypeId;
      }

      final account = ChartOfAccount(
        id: widget.accountId ?? const Uuid().v4(),
        accountCode: _codeController.text.trim(),
        accountTitle: _titleController.text.trim(),
        parentId: _selectedParentId,
        level: _level,
        accountTypeId: typeId,
        accountCategoryId: _selectedCategoryId,
        organizationId: finalOrgId ?? 0,
        isActive: _isActive,
        isSystem: _isSystem,
        createdAt: widget.accountId == null
            ? DateTime.now()
            : (state.accounts
                    .where((a) => a.id == widget.accountId)
                    .firstOrNull
                    ?.createdAt ??
                DateTime.now()),
        updatedAt: DateTime.now(),
      );

      final notifier = ref.read(accountingProvider.notifier);
      if (widget.accountId == null) {
        await notifier.addAccount(account, organizationId: finalOrgId);
      } else {
        await notifier.updateAccount(account, organizationId: finalOrgId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account saved successfully')),
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

    // Filter parents based on level
    final possibleParents =
        state.accounts.where((a) => a.level == _level - 1).toList();

    // Safety check: ensure _selectedParentId is in the list
    if (_selectedParentId != null &&
        !possibleParents.any((p) => p.id == _selectedParentId)) {
      final actualParent =
          state.accounts.where((a) => a.id == _selectedParentId).firstOrNull;
      if (actualParent != null) {
        possibleParents.add(actualParent);
      }
    }

    // Sort by account code
    possibleParents.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountId == null ? 'Add Account' : 'Edit Account'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey(_level),
                      initialValue: _level,
                      decoration: const InputDecoration(
                        labelText: 'Account Level',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 2, child: Text('Level 2 (Group)')),
                        DropdownMenuItem(
                            value: 3, child: Text('Level 3 (Control)')),
                        DropdownMenuItem(
                            value: 4,
                            child: Text('Level 4 (Ledger - Postable)')),
                      ],
                      onChanged: (widget.accountId != null || _isSystem)
                          ? null
                          : (val) {
                              setState(() {
                                _level = val!;
                                _selectedParentId = null;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue:
                          possibleParents.any((p) => p.id == _selectedParentId)
                              ? _selectedParentId
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Parent Account',
                        border: OutlineInputBorder(),
                      ),
                      items: possibleParents.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.accountCode} - ${a.accountTitle}'),
                        );
                      }).toList(),
                      onChanged: _isSystem
                          ? null
                          : (val) {
                              setState(() {
                                _selectedParentId = val;
                                if (val != null) {
                                  // FIX (H-10): guard in case the dropdown
                                  // list changed between build and selection.
                                  final parent = possibleParents
                                      .where((a) => a.id == val)
                                      .firstOrNull;
                                  if (parent != null) {
                                    _selectedCategoryId =
                                        parent.accountCategoryId;
                                  }
                                }
                              });
                            },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Account Code',
                        hintText: 'e.g. 101001',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isSystem,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Account Title',
                        hintText: 'e.g. Cash in Hand, Sales Revenue...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Account Category',
                        border: OutlineInputBorder(),
                      ),
                      items: state.categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.categoryName),
                        );
                      }).toList(),
                      onChanged: _isSystem
                          ? null
                          : (val) => setState(() => _selectedCategoryId = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Is Active'),
                      value: _isActive,
                      onChanged: _isSystem
                          ? null
                          : (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('SAVE ACCOUNT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
