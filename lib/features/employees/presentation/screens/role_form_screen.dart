import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class RoleFormScreen extends ConsumerStatefulWidget {
  const RoleFormScreen({super.key, this.roleId});
  final String? roleId;

  @override
  ConsumerState<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends ConsumerState<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  int? _selectedDepartmentId;
  bool _isSystem = false;
  bool _canRead = false;
  bool _canWrite = false;
  bool _canEdit = false;
  bool _canPrint = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      if (org != null) {
        ref.read(businessPartnerProvider.notifier).loadDepartments(org.id);
      }

      if (widget.roleId != null) {
        _loadRoleData();
      }
    });
  }

  void _loadRoleData() {
    final roles = ref.read(businessPartnerProvider).roles;
    final roleData =
        roles.where((r) => r['id'].toString() == widget.roleId).firstOrNull;
    if (roleData != null) {
      _nameController.text = roleData['role_name'] ?? '';

      final dynamic deptId = roleData['department_id'];
      if (deptId != null) {
        _selectedDepartmentId =
            deptId is int ? deptId : int.tryParse(deptId.toString());
      }

      setState(() {
        _canRead = roleData['can_read'] == 1 || roleData['can_read'] == true;
        _canWrite = roleData['can_write'] == 1 || roleData['can_write'] == true;
        _canEdit = roleData['can_edit'] == 1 || roleData['can_edit'] == true;
        _canPrint = roleData['can_print'] == 1 || roleData['can_print'] == true;
        _isSystem = roleData['is_system'] == 1 || roleData['is_system'] == true;
        
        // Fallback for legacy "Super" roles if is_system not set yet
        if (!_isSystem) {
             final name = (roleData['role_name'] ?? '').toString().toUpperCase();
             if (name.contains('SUPER') || name == 'OWNER') {
               _isSystem = true;
             }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // We still check for org for Departments, but Role itself doesn't need it.
    // However, the screen prompts for Department which IS org specific currently.
    // We allow saving without org if dept is null?
    // Let's keep existing checks but remove orgId from addRole call.

    // Default dept if not selected manually
    final departments = ref.read(businessPartnerProvider).departments;
    final deptId = _selectedDepartmentId ??
        (departments.isNotEmpty ? departments.first['id'] as int? : null);

    // Get Store and Financial Year
    final orgState = ref.read(organizationProvider);
    final storeId = orgState.selectedStore?.id;
    final syear = orgState.selectedFinancialYear;

    setState(() => _isLoading = true);
    try {
      if (widget.roleId != null) {
        await ref.read(businessPartnerProvider.notifier).updateRole(
              int.parse(widget.roleId!),
              _nameController.text.trim(),
              deptId,
              canRead: _canRead,
              canWrite: _canWrite,
              canEdit: _canEdit,
              canPrint: _canPrint,
              storeId: storeId,
              syear: syear,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role updated successfully')),
          );
        }
      } else {
        await ref.read(businessPartnerProvider.notifier).addRole(
              _nameController.text.trim(),
              deptId,
              canRead: _canRead,
              canWrite: _canWrite,
              canEdit: _canEdit,
              canPrint: _canPrint,
              storeId: storeId,
              syear: syear,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role added successfully')),
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
    final businessPartnerState = ref.watch(businessPartnerProvider);
    // Use _isSystem state
    final isLocked = _isSystem;
    final departments = businessPartnerState.departments;

    // Auto-fill logic: If not set and departments exist, pick first
    if (_selectedDepartmentId == null && departments.isNotEmpty) {
      // We use a microtask or local logic to prevent build cycle if we were setting state,
      // but here we can just default the value in Dropdown or set it.
      // However, setting it in build is bad practice if it triggers rebuilds.
      // Better to just let the Dropdown show it as value if we want strict auto-fill,
      // Or set it ONLY ONCE.
      // For "Auto fill", selecting the first valid option as default value of Dropdown is enough.
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roleId != null ? 'Edit Role' : 'New Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !isLocked,
                decoration: InputDecoration(
                  labelText: 'Role Name',
                  border: const OutlineInputBorder(),
                  helperText: isLocked
                      ? 'System core role. Cannot be renamed.'
                      : null,
                  helperStyle: const TextStyle(color: Colors.orange),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedDepartmentId,
                // initialValue handled via _selectedDepartmentId state
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
                items: departments.map((dept) {
                  return DropdownMenuItem<int>(
                    value: dept['id'] as int,
                    child: Text(dept['name'] as String),
                  );
                }).toList(),
                onChanged: isLocked ? null : (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                  });
                },
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Privileges',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(),
              CheckboxListTile(
                title: const Text('Can Read'),
                subtitle: const Text('Allows viewing records'),
                value: _canRead,
                onChanged: isLocked
                    ? null
                    : (v) => setState(() => _canRead = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Can Write'),
                subtitle: const Text('Allows creating new records'),
                value: _canWrite,
                onChanged: isLocked
                    ? null
                    : (v) => setState(() => _canWrite = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Can Edit'),
                subtitle: const Text('Allows modifying existing records'),
                value: _canEdit,
                onChanged: isLocked
                    ? null
                    : (v) => setState(() => _canEdit = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('Can Print'),
                subtitle: const Text('Allows printing/exporting reports'),
                value: _canPrint,
                onChanged: isLocked
                    ? null
                    : (v) => setState(() => _canPrint = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_isLoading || isLocked) ? null : _save,
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
