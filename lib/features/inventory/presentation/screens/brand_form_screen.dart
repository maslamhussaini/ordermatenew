import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';

class BrandFormScreen extends ConsumerStatefulWidget {
  final String? brandId;

  const BrandFormScreen({super.key, this.brandId});

  @override
  ConsumerState<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends ConsumerState<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.brandId != null) {
      _loadBrand();
    }
  }

  void _loadBrand() {
    final id = int.tryParse(widget.brandId ?? '');
    if (id == null) return;

    final brand = ref.read(inventoryProvider).brands.firstWhere(
          (b) => b.id == id,
          orElse: () => Brand(
              id: 0, name: '', createdAt: DateTime.now(), organizationId: 0),
        );
    if (brand.id != 0) {
      _nameController.text = brand.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveBrand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.brandId == null) {
        await ref
            .read(inventoryProvider.notifier)
            .addBrand(_nameController.text.trim());
      } else {
        final id = int.tryParse(widget.brandId!);
        if (id != null) {
          final existing =
              ref.read(inventoryProvider).brands.firstWhere((b) => b.id == id);
          final updated = existing.copyWith(name: _nameController.text.trim());
          await ref.read(inventoryProvider.notifier).updateBrand(updated);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brand saved successfully')),
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
        title: Text(widget.brandId == null ? 'New Brand' : 'Edit Brand'),
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
                  labelText: 'Brand Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.branding_watermark),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a brand name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveBrand,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Brand'),
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
