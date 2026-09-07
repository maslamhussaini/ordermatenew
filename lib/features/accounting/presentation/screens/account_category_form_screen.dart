// lib/features/accounting/presentation/screens/account_category_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class AccountCategoryFormScreen extends ConsumerStatefulWidget {
  final int? accountCategoryId;
  const AccountCategoryFormScreen({super.key, this.accountCategoryId});

  @override
  ConsumerState<AccountCategoryFormScreen> createState() =>
      _AccountCategoryFormScreenState();
}

class _AccountCategoryFormScreenState
    extends ConsumerState<AccountCategoryFormScreen> {
  /// FIX (H-10): true when the record being edited no longer exists.
  bool _recordMissing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  int? _selectedTypeId;
  bool _isActive = true;
  bool _isSystem = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _nameController = TextEditingController();

    if (widget.accountCategoryId != null) {
      // FIX (H-10): see account_type_form_screen.
      final cat = ref
          .read(accountingProvider)
          .categories
          .where((c) => c.id == widget.accountCategoryId)
          .firstOrNull;
      if (cat == null) {
        _recordMissing = true;
      } else {
        _idController.text = cat.id.toString();
        _nameController.text = cat.categoryName;
        _selectedTypeId = cat.accountTypeId;
        _isActive = cat.status;
        _isSystem = cat.isSystem;
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedTypeId == null) {
      if (_selectedTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an Account Type')));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;
      final category = AccountCategory(
        id: int.parse(_idController.text),
        categoryName: _nameController.text.trim(),
        accountTypeId: _selectedTypeId!,
        status: _isActive,
        isSystem: _isSystem,
        organizationId: orgId ?? 0,
      );
      final notifier = ref.read(accountingProvider.notifier);

      if (widget.accountCategoryId == null) {
        await notifier.addAccountCategory(category, organizationId: orgId);
      } else {
        await notifier.updateAccountCategory(category, organizationId: orgId);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account category saved successfully')),
        );
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
    if (_recordMissing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Category')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This account category could not be found. It may have been deleted or is not yet synced.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final types = ref.watch(accountingProvider).types;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountCategoryId == null
            ? 'Add Account Category'
            : 'Edit Account Category'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'Category ID (Integer)',
                        border: OutlineInputBorder(),
                        helperText: 'e.g. 101, 102, 201...',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: widget.accountCategoryId == null,
                      validator: (value) =>
                          (value == null || int.tryParse(value) == null)
                              ? 'Invalid ID'
                              : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                        hintText:
                            'e.g. Fixed Assets, Current Assets, Revenue...',
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                      ),
                      items: types.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: Text(t.typeName),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedTypeId = val),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Is Active'),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    if (widget.accountCategoryId == null)
                      SwitchListTile(
                        title: const Text('Is System'),
                        subtitle:
                            const Text('System categories cannot be deleted'),
                        value: _isSystem,
                        onChanged: (val) => setState(() => _isSystem = val),
                      ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Account Category'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
