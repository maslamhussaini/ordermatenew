import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class OrganizationProfileScreen extends ConsumerStatefulWidget {
  const OrganizationProfileScreen({super.key});

  @override
  ConsumerState<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState
    extends ConsumerState<OrganizationProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Organization Form
  final _orgNameController = TextEditingController();
  final _orgTaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(
      () => ref.read(organizationProvider.notifier).loadOrganizations(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orgNameController.dispose();
    _orgTaxController.dispose();
    super.dispose();
  }

  void _populateOrgForm(Organization org) {
    _orgNameController.text = org.name;
    // _orgTaxController.text = org.taxRegistrationNum ?? '';
    // _orgHasMultipleBranch = org.haveMultipleBranch;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final orgState = ref.watch(organizationProvider);
    final authState = ref.watch(authProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null || authState.role != UserRole.admin) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Only administrators can view this page.'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Organization Profile'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Branches (Stores)'),
              ],
            ),
          ),
          body: orgState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : orgState.selectedOrganization == null
                  ? _buildCreateOrgView()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDetailsTab(orgState.selectedOrganization!),
                        _buildBranchesTab(
                          orgState.stores,
                          orgState.selectedOrganization!.id,
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildCreateOrgView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'No Organization Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Create an organization to get started.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showCreateOrgDialog,
              child: const Text('Create Organization'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(Organization org) {
    // Ensure controller is populated only once or when org changes
    if (_orgNameController.text.isEmpty && org.name.isNotEmpty) {
      _populateOrgForm(org);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _orgNameController,
            decoration: const InputDecoration(
              labelText: 'Organization Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _orgTaxController,
            decoration: const InputDecoration(
              labelText: 'Tax Registration Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // CheckboxListTile(
          //   title: const Text('Have Multiple Branches?'),
          //   value: _orgHasMultipleBranch,
          //   onChanged: (val) {
          //     setState(() {
          //       _orgHasMultipleBranch = val ?? false;
          //     });
          //   },
          // ),
          // const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final updated = Organization(
                  id: org.id,
                  name: _orgNameController.text,
                  code: org.code,
                  isActive: org.isActive,
                  createdAt: org.createdAt,
                  updatedAt: DateTime.now(),
                  isGL: org.isGL,
                  isSales: org.isSales,
                  isInventory: org.isInventory,
                  isHR: org.isHR,
                  isSettings: org.isSettings,
                  entitlementMode: org.entitlementMode,
                  logoUrl: org.logoUrl,
                  businessTypeId: org.businessTypeId,
                  planType: org.planType,
                  storeCount: org.storeCount,
                );
                await ref
                    .read(organizationProvider.notifier)
                    .updateOrganization(updated);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updated Successfully')),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesTab(List<Store> stores, int orgId) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStoreDialog(orgId: orgId),
        child: const Icon(Icons.add),
      ),
      body: stores.isEmpty
          ? const Center(child: Text('No branches found.'))
          : ListView.builder(
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(store.name),
                  subtitle: Text(store.location ?? 'No Address'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _showStoreDialog(store: store, orgId: orgId),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showCreateOrgDialog() async {
    final nameCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    var multiBranch = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Org Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: taxCtrl,
                decoration: const InputDecoration(labelText: 'Tax Reg #'),
              ),
              CheckboxListTile(
                title: const Text('Multiple Branches?'),
                value: multiBranch,
                onChanged: (v) => setState(() => multiBranch = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  Navigator.pop(context);
                  await ref
                      .read(organizationProvider.notifier)
                      .createOrganization(nameCtrl.text, null, false);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStoreDialog({required int orgId, Store? store}) async {
    final nameCtrl = TextEditingController(text: store?.name ?? '');
    final addressCtrl = TextEditingController(text: store?.location ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(store == null ? 'Add Branch' : 'Edit Branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Store Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                if (store == null) {
                  // Create
                  final newStore = Store(
                    id: 0, // ignored
                    name: nameCtrl.text,
                    location: addressCtrl.text,
                    organizationId: orgId,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await ref
                      .read(organizationProvider.notifier)
                      .addStore(newStore);
                } else {
                  // Update
                  final updated = Store(
                    id: store.id,
                    name: nameCtrl.text,
                    location: addressCtrl.text,
                    organizationId: orgId,
                    isActive: store.isActive,
                    createdAt: store.createdAt,
                    updatedAt: DateTime.now(),
                    // Preserve other fields if needed
                  );
                  await ref
                      .read(organizationProvider.notifier)
                      .updateStore(updated);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
