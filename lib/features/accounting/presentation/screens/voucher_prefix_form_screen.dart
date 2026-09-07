// lib/features/accounting/presentation/screens/voucher_prefix_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class VoucherPrefixFormScreen extends ConsumerStatefulWidget {
  final int? prefixId;
  const VoucherPrefixFormScreen({super.key, this.prefixId});

  @override
  ConsumerState<VoucherPrefixFormScreen> createState() =>
      _VoucherPrefixFormScreenState();
}

class _VoucherPrefixFormScreenState
    extends ConsumerState<VoucherPrefixFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prefixCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _voucherTypeController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefixId != null) {
      final prefix = ref
          .read(accountingProvider)
          .voucherPrefixes
          .where((p) => p.id == widget.prefixId)
          .firstOrNull;
      if (prefix != null) {
        _prefixCodeController.text = prefix.prefixCode;
        _descriptionController.text = prefix.description ?? '';
        _voucherTypeController.text = prefix.voucherType;
        _isActive = prefix.status;
      }
    }
  }

  @override
  void dispose() {
    _prefixCodeController.dispose();
    _descriptionController.dispose();
    _voucherTypeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;

      final prefix = VoucherPrefix(
        id: widget.prefixId ?? 0,
        prefixCode: _prefixCodeController.text.trim().toUpperCase(),
        description: _descriptionController.text.trim(),
        voucherType: _voucherTypeController.text.trim().toUpperCase(),
        organizationId: orgId ?? 0,
        status: _isActive,
      );

      final notifier = ref.read(accountingProvider.notifier);
      if (widget.prefixId == null) {
        await notifier.addVoucherPrefix(prefix, organizationId: orgId);
      } else {
        await notifier.updateVoucherPrefix(prefix, organizationId: orgId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher prefix saved successfully')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prefixId == null
            ? 'Add Voucher Prefix'
            : 'Edit Voucher Prefix'),
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
                      controller: _prefixCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Prefix Code',
                        hintText: 'e.g. INV, PV, RV, JV',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _voucherTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Voucher Type',
                        hintText: 'e.g. SALES INVOICE, PAYMENT VOUCHER',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Is Active'),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('SAVE VOUCHER PREFIX'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
