// lib/features/accounting/presentation/screens/payment_term_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class PaymentTermFormScreen extends ConsumerStatefulWidget {
  final int? paymentTermId;
  const PaymentTermFormScreen({super.key, this.paymentTermId});

  @override
  ConsumerState<PaymentTermFormScreen> createState() =>
      _PaymentTermFormScreenState();
}

class _PaymentTermFormScreenState extends ConsumerState<PaymentTermFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _daysController = TextEditingController(text: '0');
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentTermId != null) {
      final term = ref
          .read(accountingProvider)
          .paymentTerms
          .where((t) => t.id == widget.paymentTermId)
          .firstOrNull;
      if (term != null) {
        _nameController.text = term.name;
        _descController.text = term.description ?? '';
        _daysController.text = term.days.toString();
        _isActive = term.isActive;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final days = int.tryParse(_daysController.text.trim()) ?? 0;
    final orgId = ref.read(organizationProvider).selectedOrganization?.id;

    // Check for duplicate name
    final existing = ref
        .read(accountingProvider)
        .paymentTerms
        .where((t) =>
            t.name.toLowerCase() == name.toLowerCase() &&
            t.id != widget.paymentTermId &&
            (t.organizationId == orgId))
        .firstOrNull;

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A payment term with this name already exists.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final term = PaymentTerm(
        id: widget.paymentTermId ?? 0,
        name: name,
        description: _descController.text.trim(),
        days: days,
        isActive: _isActive,
        organizationId: orgId ?? 0,
      );

      final notifier = ref.read(accountingProvider.notifier);
      if (widget.paymentTermId == null) {
        await notifier.addPaymentTerm(term, organizationId: orgId);
      } else {
        await notifier.updatePaymentTerm(term, organizationId: orgId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment term saved successfully')),
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
        title: Text(widget.paymentTermId == null
            ? 'Add Payment Term'
            : 'Edit Payment Term'),
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Term Name',
                        hintText: 'e.g. Cash, Net 30, Due on Receipt',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _daysController,
                      decoration: const InputDecoration(
                        labelText: 'Days (for Due Date calculation)',
                        hintText: 'e.g. 7 for a week',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descController,
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
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('SAVE PAYMENT TERM'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
