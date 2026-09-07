import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

/// Opens the reusable contextual "Create Salesman" dialog.
///
/// Returns the newly created Salesman's BusinessPartner id on success, or
/// `null` if the user cancelled. Intended to be called from both the
/// Customer List's "no Salesman" prompt and the Customer Form's SalesMan
/// "+" picker -- one implementation, two callers.
Future<String?> showCreateSalesmanDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CreateSalesmanDialog(),
  );
}

class CreateSalesmanDialog extends ConsumerStatefulWidget {
  const CreateSalesmanDialog({super.key});

  @override
  ConsumerState<CreateSalesmanDialog> createState() =>
      _CreateSalesmanDialogState();
}

class _CreateSalesmanDialogState extends ConsumerState<CreateSalesmanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hasAppAccess = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Finds an existing Department named "Sales" (case-insensitive) for the
  /// current organization, or creates it if none exists. Never creates a
  /// duplicate. Reuses the same existing department creation mechanism the
  /// full Employee form already uses (businessPartnerProvider.addDepartment).
  Future<int> _resolveSalesDepartmentId(
      BusinessPartnerNotifier notifier, int orgId) async {
    await notifier.loadDepartments(orgId);
    final departments = ref.read(businessPartnerProvider).departments;
    final existing = departments.firstWhere(
      (d) => (d['name'] as String?)?.toLowerCase() == 'sales',
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty) {
      return existing['id'] as int;
    }

    await notifier.addDepartment('Sales', orgId);
    final refreshed = ref.read(businessPartnerProvider).departments;
    final created = refreshed.firstWhere(
      (d) => (d['name'] as String?)?.toLowerCase() == 'sales',
      orElse: () => throw Exception('Failed to create "Sales" department.'),
    );
    return created['id'] as int;
  }

  /// Finds an existing Role named "Salesman" (case-insensitive) for the
  /// current organization, or creates it under the Sales department if none
  /// exists. Never creates a duplicate. Reuses the same existing role
  /// creation mechanism the full Employee form already uses
  /// (businessPartnerProvider.addRole).
  Future<int> _resolveSalesmanRoleId(
      BusinessPartnerNotifier notifier, int orgId, int departmentId) async {
    await notifier.loadRoles(organizationId: orgId);
    final roles = ref.read(businessPartnerProvider).roles;
    final existing = roles.firstWhere(
      (r) => (r['role_name'] as String?)?.toLowerCase() == 'salesman',
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty) {
      return existing['id'] as int;
    }

    await notifier.addRole('Salesman', departmentId);
    final refreshed = ref.read(businessPartnerProvider).roles;
    final created = refreshed.firstWhere(
      (r) => (r['role_name'] as String?)?.toLowerCase() == 'salesman',
      orElse: () => throw Exception('Failed to create "Salesman" role.'),
    );
    return created['id'] as int;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // created_by must be the current user's omtbl_users.id (what
    // omtbl_businesspartners.created_by's foreign key actually targets),
    // never the Supabase Auth UID -- those are different values for most
    // users. Fail fast with a clear message rather than attempting an
    // insert that is guaranteed to violate the FK constraint.
    final authState = ref.read(authProvider);
    // isEmpty alone is not sufficient: immediately after sign-in, userId
    // briefly holds the (non-empty) Auth UID before it's corrected to
    // omtbl_users.id once profile/permission loading resolves.
    if (!authState.applicationIdentityResolved || authState.userId.isEmpty) {
      setState(() => _error =
          'Unable to determine the current user. Please sign in again and retry.');
      return;
    }
    final currentUsersId = authState.userId;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final orgState = ref.read(organizationProvider);
      final orgId = orgState.selectedOrganization?.id;
      if (orgId == null) {
        throw Exception('No organization selected.');
      }
      final storeId = orgState.selectedStore?.id;
      final notifier = ref.read(businessPartnerProvider.notifier);

      // Department = Sales, Role = Salesman -- resolved/created
      // automatically, never shown to the user.
      final departmentId = await _resolveSalesDepartmentId(notifier, orgId);
      final roleId =
          await _resolveSalesmanRoleId(notifier, orgId, departmentId);

      final newId = const Uuid().v4();
      final partner = BusinessPartner(
        id: newId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim(),
        createdBy: currentUsersId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        departmentId: departmentId,
        roleId: roleId,
        isEmployee: true,
        isActive: true,
        organizationId: orgId,
        storeId: storeId,
      );

      // Only after this succeeds do we consider the Salesman created --
      // a failure here must not be treated as success and must not
      // proceed to application-access creation.
      await notifier.addPartner(partner);

      // Optional application access, mirroring the existing Employee
      // creation flow's behavior exactly (same fields, same call). Note:
      // createAppUser() does not throw on invite/user-write failure -- an
      // existing, pre-existing limitation of that mechanism, not something
      // this dialog changes or can improve on. The BusinessPartner/Salesman
      // itself is already created and usable regardless of this step.
      if (_hasAppAccess && _emailController.text.trim().isNotEmpty) {
        await notifier.repository.createAppUser(
          partnerId: newId,
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          roleId: roleId,
          organizationId: orgId,
          storeId: storeId,
          password: _passwordController.text.trim().isNotEmpty
              ? _passwordController.text.trim()
              : null,
        );
      }

      if (mounted) Navigator.of(context).pop(newId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create Salesman: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Salesman'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone *'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration:
                    const InputDecoration(labelText: 'Street Address *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Grant Application Access'),
                subtitle: const Text('Enable login for this employee.'),
                value: _hasAppAccess,
                onChanged: (v) => setState(() => _hasAppAccess = v),
              ),
              if (_hasAppAccess) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (!_hasAppAccess) return null;
                    return (v == null || v.trim().isEmpty)
                        ? 'Email is required for app access'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password *'),
                  obscureText: true,
                  validator: (v) {
                    if (!_hasAppAccess) return null;
                    if (v == null || v.isEmpty) {
                      return 'Password is required for new app access';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
