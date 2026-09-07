import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';

class VendorFormScreen extends ConsumerStatefulWidget {
  const VendorFormScreen({super.key, this.vendorId});
  final String? vendorId;

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isActive = true;
  bool _isSupplier = false;
  bool _isLoading = false;
  String? _selectedChartOfAccountId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(businessPartnerProvider.notifier).loadBusinessTypes();
      await ref.read(businessPartnerProvider.notifier).loadStates();
      await ref.read(businessPartnerProvider.notifier).loadCities();
      await ref.read(businessPartnerProvider.notifier).loadCountries();
      await ref.read(accountingProvider.notifier).loadAll();
      if (widget.vendorId != null) {
        _loadVendorData();
      }
    });
  }

  void _loadVendorData() {
    final state = ref.read(vendorProvider);
    final vendor = [...state.vendors, ...state.suppliers]
        .where((v) => v.id == widget.vendorId)
        .firstOrNull;

    if (vendor != null) {
      _nameController.text = vendor.name;
      _contactPersonController.text = vendor.contactPerson ?? '';
      _phoneController.text = vendor.phone ?? '';
      _emailController.text = vendor.email ?? '';
      _addressController.text = vendor.address ?? '';
      _isActive = vendor.isActive;
      _isSupplier = vendor.isSupplier;
      _selectedChartOfAccountId = vendor.chartOfAccountId;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(vendorProvider.notifier);

      final orgState = ref.read(organizationProvider);
      final currentOrgId = orgState.selectedOrganization?.id;
      final currentStoreId = orgState.selectedStore?.id;

      if (currentOrgId == null || currentStoreId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Error: Organization or Store not selected. Please restart the app.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (widget.vendorId == null) {
        // Create -- created_by must be omtbl_users.id, never the Supabase
        // Auth UID (the FK omtbl_businesspartners.created_by targets).
        final authState = ref.read(authProvider);
        if (!authState.applicationIdentityResolved ||
            authState.userId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to determine the current user. Please sign in again and retry.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final newVendor = Vendor(
          id: widget.vendorId ?? const Uuid().v4(),
          name: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          isSupplier: _isSupplier,
          isActive: _isActive,
          organizationId: currentOrgId,
          storeId: currentStoreId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          chartOfAccountId: _selectedChartOfAccountId,
          createdBy: authState.userId,
        );
        await notifier.addVendor(newVendor);
      } else {
        // Update -- preserve the original creator, never re-stamp it.
        final state = ref.read(vendorProvider);
        final currentVendor = [...state.vendors, ...state.suppliers]
            .firstWhere((v) => v.id == widget.vendorId);

        final updatedVendor = Vendor(
          id: widget.vendorId!,
          name: _nameController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          isSupplier: _isSupplier,
          isActive: _isActive,
          organizationId: currentVendor.organizationId,
          storeId: currentVendor.storeId,
          createdAt: currentVendor.createdAt,
          updatedAt: DateTime.now(),
          chartOfAccountId: _selectedChartOfAccountId,
          createdBy: currentVendor.createdBy,
        );
        await notifier.updateVendor(updatedVendor);
      }

      if (mounted) {
        final entityType = _isSupplier ? 'Supplier' : 'Vendor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$entityType saved successfully')),
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
    // Determine if this is a supplier based on the current vendor data
    final state = ref.watch(vendorProvider);
    final currentVendor = widget.vendorId != null
        ? [...state.vendors, ...state.suppliers]
            .where((v) => v.id == widget.vendorId)
            .firstOrNull
        : null;
    final isSupplierContext = currentVendor?.isSupplier ?? _isSupplier;
    final entityType = isSupplierContext ? 'Supplier' : 'Vendor';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorId == null ? 'Create $entityType' : 'Edit $entityType'),
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
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '${_isSupplier ? "Supplier" : "Vendor"} Name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contactPersonController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      LookupField<ChartOfAccount, String>(
                        label: '${_isSupplier ? "Supplier" : "Vendor"} GL Account',
                        value: _selectedChartOfAccountId?.toString(),
                        items:
                            ref.watch(accountingProvider).accounts.where((a) {
                          final categories =
                              ref.read(accountingProvider).categories;
                          final cat = categories.firstWhere(
                              (c) => c.id == a.accountCategoryId,
                              orElse: () => const AccountCategory(
                                  id: 0,
                                  categoryName: '',
                                  accountTypeId: 0,
                                  organizationId: 0,
                                  status: true));
                          return cat.categoryName
                                  .toLowerCase()
                                  .contains('vendor') ||
                              cat.categoryName
                                  .toLowerCase()
                                  .contains('payable') ||
                              cat.categoryName
                                  .toLowerCase()
                                  .contains('supplier');
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedChartOfAccountId = v),
                        labelBuilder: (item) =>
                            '${item.accountCode} - ${item.accountTitle}',
                        valueBuilder: (item) => item.id,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Is Supplier'),
                        subtitle:
                            const Text('Check if this vendor is a supplier'),
                        value: _isSupplier,
                        onChanged: (v) => setState(() => _isSupplier = v),
                      ),
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle:
                            const Text('Is this vendor currently active?'),
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
