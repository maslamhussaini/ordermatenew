import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class StoreFormScreen extends ConsumerStatefulWidget {
  const StoreFormScreen({super.key, this.storeId});
  final String? storeId;

  @override
  ConsumerState<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends ConsumerState<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.storeId != null) {
      final id = int.tryParse(widget.storeId!);
      if (id != null) {
        final store = ref
            .read(organizationProvider)
            .stores
            .where((s) => s.id == id)
            .firstOrNull;
        if (store != null) {
          _nameController.text = store.name;
          _addressController.text = store.location ?? '';
          _cityController.text = store.city ?? '';
          _countryController.text = store.country ?? '';
          _postalController.text = store.postalCode ?? '';
          _phoneController.text = store.phone ?? '';
          _currencyController.text = store.storeDefaultCurrency;
          _isActive = store.isActive;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedOrg = ref.read(organizationProvider).selectedOrganization;
    if (selectedOrg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Organization selected. Cannot save store.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(organizationProvider.notifier);
      if (widget.storeId == null) {
        // Create
        final newStore = Store(
          id: 0,
          name: _nameController.text.trim(),
          location: _addressController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          postalCode: _postalController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          storeDefaultCurrency: _currencyController.text.trim().isEmpty
              ? 'USD'
              : _currencyController.text.trim(),
          organizationId: selectedOrg.id,
          isActive: _isActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await notifier.addStore(newStore);
      } else {
        // Update
        final id = int.parse(widget.storeId!);
        final currentStore =
            ref.read(organizationProvider).stores.firstWhere((s) => s.id == id);

        final updated = Store(
          id: id,
          name: _nameController.text.trim(),
          location: _addressController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          postalCode: _postalController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          storeDefaultCurrency: _currencyController.text.trim().isEmpty
              ? 'USD'
              : _currencyController.text.trim(),
          organizationId: selectedOrg.id,
          isActive: _isActive,
          createdAt: currentStore.createdAt,
          updatedAt: DateTime.now(),
        );
        await notifier.updateStore(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.storeId == null ? 'Create Branch' : 'Edit Branch'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Branch Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _postalController,
                            decoration: const InputDecoration(
                              labelText: 'Postal Code',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'Default Currency (e.g. USD, KRW, PKR)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle:
                            const Text('Is this branch currently active?'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
