import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';

class ProductTypeFormScreen extends ConsumerStatefulWidget {
  final String? typeId;

  const ProductTypeFormScreen({super.key, this.typeId});

  @override
  ConsumerState<ProductTypeFormScreen> createState() =>
      _ProductTypeFormScreenState();
}

class _ProductTypeFormScreenState extends ConsumerState<ProductTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.typeId != null) {
      _loadType();
    }
  }

  void _loadType() {
    final id = int.tryParse(widget.typeId ?? '');
    if (id == null) return;

    final type = ref.read(inventoryProvider).productTypes.firstWhere(
          (t) => t.id == id,
          orElse: () => ProductType(
              id: 0, name: '', createdAt: DateTime.now(), organizationId: 0),
        );
    if (type.id != 0) {
      _nameController.text = type.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveType() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.typeId == null) {
        await ref
            .read(inventoryProvider.notifier)
            .addProductType(_nameController.text.trim());
      } else {
        final id = int.tryParse(widget.typeId!);
        if (id != null) {
          final existing = ref
              .read(inventoryProvider)
              .productTypes
              .firstWhere((t) => t.id == id);
          final updated = existing.copyWith(name: _nameController.text.trim());
          await ref.read(inventoryProvider.notifier).updateProductType(updated);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product Type saved successfully')),
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
        title: Text(
            widget.typeId == null ? 'New Product Type' : 'Edit Product Type'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Type Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveType,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Product Type'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
