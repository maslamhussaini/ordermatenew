// lib/features/employees/presentation/screens/user_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:uuid/uuid.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UserFormScreen({super.key, this.userId});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();

  AppUser? _existingUser;
  BusinessPartner? _selectedPartner;
  int? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Ensure dependents are loaded
      await Future.wait([
        ref.read(businessPartnerProvider.notifier).loadEmployees(),
        ref.read(businessPartnerProvider.notifier).loadRoles(),
        ref.read(businessPartnerProvider.notifier).loadAppUsers(),
      ]);

      if (widget.userId != null) {
        final state = ref.read(businessPartnerProvider);
        _existingUser = state.appUsers.firstWhere((u) => u.id == widget.userId);

        _emailController.text = _existingUser!.email;
        _fullNameController.text = _existingUser!.fullName ?? '';
        _selectedRoleId = _existingUser!.roleId;
        _isActive = _existingUser!.isActive;
        _passwordController.text = _existingUser!.password ?? '';

        // Find associated partner if possible
        _selectedPartner = state.employees.cast<BusinessPartner?>().firstWhere(
              (p) => p?.id == _existingUser!.businessPartnerId,
              orElse: () => null,
            );
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final orgState = ref.read(organizationProvider);
      final repo = ref.read(businessPartnerProvider.notifier).repository;

      if (widget.userId == null) {
        // Create
        if (_selectedPartner == null) {
          throw Exception('Please select an employee');
        }

        await repo.createAppUser(
          partnerId: _selectedPartner!.id,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          roleId: _selectedRoleId!,
          password: _passwordController.text,
          organizationId: orgState.selectedOrganizationId ?? 0,
          storeId: orgState.selectedStoreId ?? 0,
        );
      } else {
        // Update
        final updatedUser = AppUser(
          id: _existingUser!.id,
          businessPartnerId: _existingUser!.businessPartnerId,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          roleId: _selectedRoleId!,
          organizationId: _existingUser!.organizationId,
          storeId: _existingUser!.storeId,
          isActive: _isActive,
          lastLogin: _existingUser!.lastLogin,
          updatedAt: DateTime.now(),
        );

        await repo.updateAppUser(updatedUser,
            password: _passwordController.text.isEmpty
                ? null
                : _passwordController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  widget.userId == null ? 'User created' : 'User updated')),
        );
        ref.read(businessPartnerProvider.notifier).loadAppUsers();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bpState = ref.watch(businessPartnerProvider);

    // For new users, only show employees who don't already have a user account
    final availableEmployees = widget.userId == null
        ? bpState.employees
            .where((e) =>
                !bpState.appUsers.any((u) => u.businessPartnerId == e.id))
            .toList()
        : bpState.employees;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.userId == null ? 'New Application User' : 'Edit User'),
        elevation: 0,
      ),
      body: _isLoading && widget.userId != null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Selection
                    if (widget.userId == null) ...[
                      const Text('Select Employee',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BusinessPartner>(
                        initialValue: _selectedPartner,
                        decoration: const InputDecoration(
                          hintText: 'Choose an employee',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: availableEmployees
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPartner = val;
                            if (val != null) {
                              _emailController.text = val.email ?? '';
                              _fullNameController.text = val.name;
                              if (val.roleId != null) {
                                _selectedRoleId = val.roleId;
                              }
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(_fullNameController.text),
                        subtitle: Text(_emailController.text),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],

                    // Email (Auto-filled from Employee if possible)
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Required' : null,
                      readOnly: widget.userId !=
                          null, // Typically email shouldn't change for identity
                    ),
                    const SizedBox(height: 16),

                    // Role Selection
                    const Text('Application Role',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue:
                          bpState.roles.any((r) => r['id'] == _selectedRoleId)
                              ? _selectedRoleId
                              : null,
                      decoration: const InputDecoration(
                        hintText: 'Select role',
                        prefixIcon: Icon(Icons.security),
                      ),
                      items: bpState.roles
                          .map((r) => DropdownMenuItem<int>(
                                value: r['id'] as int,
                                child: Text(
                                    r['role_name']?.toString() ?? 'Unnamed'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedRoleId = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: widget.userId == null
                            ? 'Password *'
                            : 'Change Password (optional)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Generate Random Password',
                              onPressed: () {
                                final randomPass =
                                    const Uuid().v4().substring(0, 8);
                                setState(() {
                                  _passwordController.text = randomPass;
                                  _obscurePassword = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      validator: (v) {
                        if (widget.userId == null && (v == null || v.isEmpty)) {
                          return 'Required';
                        }
                        if (v != null && v.isNotEmpty && v.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),

                    if (widget.userId != null) ...[
                      const SizedBox(height: 24),
                      SwitchListTile(
                        title: const Text('Account Active'),
                        subtitle: const Text('Allow user to log in'),
                        value: _isActive,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(widget.userId == null
                              ? 'Create User Account'
                              : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
