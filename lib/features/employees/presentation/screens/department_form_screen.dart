import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class DepartmentFormScreen extends ConsumerStatefulWidget {
  const DepartmentFormScreen({super.key, this.departmentId});
  final String? departmentId;

  @override
  ConsumerState<DepartmentFormScreen> createState() =>
      _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends ConsumerState<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.departmentId != null) {
      Future.microtask(_loadDepartmentData);
    }
  }

  void _loadDepartmentData() {
    final departments = ref.read(businessPartnerProvider).departments;
    final dept = departments
        .where((d) => d['id'].toString() == widget.departmentId)
        .firstOrNull;
    if (dept != null) {
      _nameController.text = dept['name'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final org = ref.read(organizationProvider).selectedOrganization;
    if (org == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Organization selected')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.departmentId != null) {
        await ref.read(businessPartnerProvider.notifier).updateDepartment(
              int.parse(widget.departmentId!),
              _nameController.text.trim(),
              org.id,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Department updated successfully')),
          );
        }
      } else {
        await ref.read(businessPartnerProvider.notifier).addDepartment(
              _nameController.text.trim(),
              org.id,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Department added successfully')),
          );
        }
      }

      if (mounted) {
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
            widget.departmentId != null ? 'Edit Department' : 'New Department'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
