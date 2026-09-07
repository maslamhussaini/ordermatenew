import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class UnitOfMeasureFormScreen extends ConsumerStatefulWidget {
  final String? uomId;

  const UnitOfMeasureFormScreen({super.key, this.uomId});

  @override
  ConsumerState<UnitOfMeasureFormScreen> createState() =>
      _UnitOfMeasureFormScreenState();
}

class _UnitOfMeasureFormScreenState
    extends ConsumerState<UnitOfMeasureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  bool _isDecimalAllowed = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.uomId != null) {
      _loadUom();
    }
  }

  void _loadUom() {
    final id = int.tryParse(widget.uomId ?? '');
    if (id == null) return;

    final uom = ref.read(inventoryProvider).unitsOfMeasure.firstWhere(
          (u) => u.id == id,
          orElse: () => const UnitOfMeasure(
              id: 0, name: '', symbol: '', organizationId: 0),
        );
    if (uom.id != 0) {
      _nameController.text = uom.name;
      _symbolController.text = uom.symbol;
      setState(() {
        _isDecimalAllowed = uom.isDecimalAllowed;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _saveUom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uom = UnitOfMeasure(
        id: int.tryParse(widget.uomId ?? '') ?? 0,
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim(),
        isDecimalAllowed: _isDecimalAllowed,
        organizationId:
            ref.read(organizationProvider).selectedOrganizationId ?? 0,
      );

      if (widget.uomId == null) {
        await ref.read(inventoryProvider.notifier).addUnitOfMeasure(uom);
      } else {
        await ref.read(inventoryProvider.notifier).updateUnitOfMeasure(uom);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit saved successfully')),
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
        title: Text(widget.uomId == null
            ? 'New Unit of Measure'
            : 'Edit Unit of Measure'),
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
                  labelText: 'Unit Name',
                  hintText: 'e.g. Kilogram',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol',
                  hintText: 'e.g. kg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.short_text),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a symbol';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Allow Decimals'),
                subtitle: const Text('Can this unit be split? (e.g. 1.5 kg)'),
                value: _isDecimalAllowed,
                onChanged: (val) => setState(() => _isDecimalAllowed = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveUom,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Unit'),
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
