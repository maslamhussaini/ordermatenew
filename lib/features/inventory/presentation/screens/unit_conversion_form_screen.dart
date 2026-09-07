import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class UnitConversionFormScreen extends ConsumerStatefulWidget {
  final String? conversionId;

  const UnitConversionFormScreen({super.key, this.conversionId});

  @override
  ConsumerState<UnitConversionFormScreen> createState() =>
      _UnitConversionFormScreenState();
}

class _UnitConversionFormScreenState
    extends ConsumerState<UnitConversionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _factorController = TextEditingController();
  int? _fromUnitId;
  int? _toUnitId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(inventoryProvider.notifier).loadUnitsOfMeasure());
    if (widget.conversionId != null) {
      _loadConversion();
    }
  }

  void _loadConversion() {
    final id = int.tryParse(widget.conversionId ?? '');
    if (id == null) return;

    final conversion = ref.read(inventoryProvider).unitConversions.firstWhere(
          (c) => c.id == id,
          orElse: () => const UnitConversion(
              id: 0,
              fromUnitId: 0,
              toUnitId: 0,
              conversionFactor: 1,
              organizationId: 0),
        );
    if (conversion.id != 0) {
      _factorController.text = conversion.conversionFactor.toString();
      _fromUnitId = conversion.fromUnitId;
      _toUnitId = conversion.toUnitId;
    }
  }

  @override
  void dispose() {
    _factorController.dispose();
    super.dispose();
  }

  Future<void> _saveConversion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromUnitId == null || _toUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select units')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final conversion = UnitConversion(
        id: int.tryParse(widget.conversionId ?? '') ?? 0,
        fromUnitId: _fromUnitId!,
        toUnitId: _toUnitId!,
        conversionFactor: double.parse(_factorController.text),
        organizationId:
            ref.read(organizationProvider).selectedOrganizationId ?? 0,
      );

      if (widget.conversionId == null) {
        await ref
            .read(inventoryProvider.notifier)
            .addUnitConversion(conversion);
      } else {
        await ref
            .read(inventoryProvider.notifier)
            .updateUnitConversion(conversion);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversion saved successfully')),
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
    final units = ref.watch(inventoryProvider).unitsOfMeasure;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.conversionId == null ? 'New Conversion' : 'Edit Conversion'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _fromUnitId,
                decoration: const InputDecoration(
                  labelText: 'From Unit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_forward),
                ),
                items: units.map((u) {
                  return DropdownMenuItem(
                    value: u.id,
                    child: Text('${u.name} (${u.symbol})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _fromUnitId = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _toUnitId,
                decoration: const InputDecoration(
                  labelText: 'To Unit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_back),
                ),
                items: units.map((u) {
                  return DropdownMenuItem(
                    value: u.id,
                    child: Text('${u.name} (${u.symbol})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _toUnitId = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _factorController,
                decoration: const InputDecoration(
                  labelText: 'Conversion Factor',
                  hintText: 'e.g. 1000 for kg to g',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a factor';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveConversion,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Conversion'),
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
