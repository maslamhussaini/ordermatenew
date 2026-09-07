import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class OrganizationFormScreen extends ConsumerStatefulWidget {
  const OrganizationFormScreen({super.key, this.organizationId});
  final String? organizationId; // ID is int in entity, but router passes String

  @override
  ConsumerState<OrganizationFormScreen> createState() =>
      _OrganizationFormScreenState();
}

class _OrganizationFormScreenState
    extends ConsumerState<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Store Fields
  final _storeNameController =
      TextEditingController(); // Only for Multiple Branches
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');

  bool _isActive = true;
  bool _hasMultipleBranches = false;
  bool _isLoading = false;
  XFile? _pickedFile;
  Uint8List? _previewBytes;
  String? _existingLogoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.organizationId != null) {
      final id = int.tryParse(widget.organizationId!);
      if (id != null) {
        final org = ref
            .read(organizationProvider)
            .organizations
            .where((o) => o.id == id)
            .firstOrNull;
        if (org != null) {
          _nameController.text = org.name;
          _isActive = org.isActive;
          _existingLogoUrl = org.logoUrl;
          // Note: Editing existing org usually doesn't show "Create Initial Store" fields
          // So we might hide them if organizationId is not null.
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(organizationProvider.notifier);

      if (widget.organizationId == null) {
        // Create Organization
        final newOrg = await notifier.createOrganization(
          _nameController.text.trim(),
          null, // Tax ID
          _hasMultipleBranches,
          logoBytes: _previewBytes,
          logoName: _pickedFile?.name,
        );

        // Create Initial Store
        // Logic: If !multiple, store name is 'Main Store'. If multiple, use input.
        // Actually if !multiple, we might use the Org Name or 'Main Store'.
        // Let's use Org Name if not specified, or 'Main Store'.
        // User prompt: "create default store".

        String storeName = 'Main Store';
        if (_hasMultipleBranches) {
          storeName = _storeNameController.text.trim();
          if (storeName.isEmpty) storeName = 'Branch 1'; // Fallback
        } else {
          // Maybe use Org Name?
          storeName = '${_nameController.text.trim()} Store';
        }

        final store = Store(
          id: 0, // Placeholder
          organizationId: newOrg.id,
          name: storeName,
          location: _addressController.text.trim(),
          city: _cityController.text.trim(),
          country: _countryController.text.trim(),
          postalCode: _postalController.text.trim(),
          phone: _phoneController.text.trim(),
          storeDefaultCurrency: _currencyController.text.trim(),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await notifier.addStore(store);
      } else {
        // Update Existing Organization
        final id = int.parse(widget.organizationId!);
        final currentOrg = ref
            .read(organizationProvider)
            .organizations
            .firstWhere((o) => o.id == id);

        final updatedOrg = Organization(
          id: id,
          name: _nameController.text.trim(),
          code: currentOrg.code,
          isActive: _isActive,
          createdAt: currentOrg.createdAt,
          updatedAt: DateTime.now(),
          isGL: currentOrg.isGL,
          isSales: currentOrg.isSales,
          isInventory: currentOrg.isInventory,
          isHR: currentOrg.isHR,
          isSettings: currentOrg.isSettings,
          entitlementMode: currentOrg.entitlementMode,
          logoUrl: currentOrg.logoUrl,
          businessTypeId: currentOrg.businessTypeId,
          planType: currentOrg.planType,
          storeCount: currentOrg.storeCount,
        );

        await notifier.updateOrganization(updatedOrg,
            newLogoBytes: _previewBytes, newLogoName: _pickedFile?.name);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed('dashboard');
        }
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
    final isEditing = widget.organizationId != null;

    final orgState = ref.watch(organizationProvider);
    final isFirstOrg = !isEditing && orgState.organizations.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isFirstOrg,
        title: Text(isEditing ? 'Edit Organization' : 'Create Organization'),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: _pickLogo,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _previewBytes != null
                                    ? MemoryImage(_previewBytes!)
                                    : (_existingLogoUrl != null &&
                                            _existingLogoUrl!.isNotEmpty
                                        ? NetworkImage(_existingLogoUrl!)
                                            as ImageProvider
                                        : null),
                                child: (_previewBytes == null &&
                                        (_existingLogoUrl == null ||
                                            _existingLogoUrl!.isEmpty))
                                    ? const Icon(Icons.business,
                                        size: 50, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickLogo,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Organization Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Only show Branch/Store setup when CREATING
                      if (!isEditing) ...[
                        SwitchListTile(
                          title: const Text('Have Multiple Branches?'),
                          value: _hasMultipleBranches,
                          onChanged: (v) =>
                              setState(() => _hasMultipleBranches = v),
                        ),
                        const SizedBox(height: 16),
                        if (_hasMultipleBranches) ...[
                          TextFormField(
                            controller: _storeNameController,
                            decoration: const InputDecoration(
                              labelText: 'New Store Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                _hasMultipleBranches && (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text('Initial Store Details',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
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
                          ],
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
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Store Phone Number',
                            border: OutlineInputBorder(),
                            hintText: '+1234567890',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currencyController,
                          decoration: const InputDecoration(
                            labelText: 'Default Currency',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (isEditing)
                        SwitchListTile(
                          title: const Text('Active'),
                          subtitle: const Text(
                              'Is this organization currently active?'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedFile = image;
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
}
