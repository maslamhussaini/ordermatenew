import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/organization/presentation/screens/module_access_screen.dart';

class OrganizationListScreen extends ConsumerStatefulWidget {
  const OrganizationListScreen({super.key});

  @override
  ConsumerState<OrganizationListScreen> createState() =>
      _OrganizationListScreenState();
}

class _OrganizationListScreenState
    extends ConsumerState<OrganizationListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(organizationProvider.notifier).loadOrganizations(),
    );
  }

  Widget _buildOrganizationItem(dynamic org, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: Border.all(color: Colors.transparent),
        leading: CircleAvatar(
          backgroundColor:
              isSelected ? Colors.green.shade50 : Colors.indigo.shade50,
          child: Icon(
            Icons.business,
            color: isSelected ? Colors.green : Colors.indigo,
          ),
        ),
        title: Row(
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            Expanded(
              child: Text(
                org.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? Colors.green.shade800 : Colors.indigo,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Code: ${org.code ?? 'N/A'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Module Access Button (Restricted).
              // Phase 3B-4A-R: sourced from authProvider's role (itself
              // now backed by the is_platform_admin() DB check), not a
              // second independent hardcoded email comparison.
              if (ref.watch(authProvider).role == UserRole.superUser) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModuleAccessScreen(orgId: org.id.toString()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text('Modules'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              if (!isSelected) ...[
                OutlinedButton.icon(
                  onPressed: () => _handleOrgSelection(org),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Select'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (ref.watch(authProvider).role == UserRole.superUser) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(organizationProvider.notifier)
                        .selectOrganization(org);
                    context.pushNamed('organization-edit',
                        pathParameters: {'id': org.id.toString()});
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.shade200),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  // Only enable if storeCount is 0 (assuming storeCount is available on org)
                  onPressed: (org.storeCount == 0 && !isSelected)
                      ? () => _confirmDelete(org)
                      : null,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    disabledForegroundColor: Colors.grey,
                    side: BorderSide(
                        color: (org.storeCount == 0 && !isSelected)
                            ? Colors.red.shade200
                            : Colors.grey.shade300),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleOrgSelection(dynamic org) async {
    final notifier = ref.read(organizationProvider.notifier);

    // Select Org (this loads stores)
    await notifier.selectOrganization(org);

    if (!mounted) return;

    // Check stores
    final state = ref.read(organizationProvider);
    final stores = state.stores;
    final selectedStore = state.selectedStore;

    if (selectedStore != null) {
      // Auto-selected (1 store) or persisted
      _onSelectionComplete(org.name, selectedStore.name);
    } else if (stores.isNotEmpty) {
      // Multiple stores, force selection
      _showStoreSelectionDialog(stores);
    } else {
      // No stores
      _onSelectionComplete(org.name, null);
    }
  }

  void _onSelectionComplete(String orgName, String? storeName) {
    // PREVIOUSLY: context.goNamed('dashboard');
    // FIX: User requested "orzlist no route to list , wrongly route to dashboard".
    // We intrepret this as "Stay on the list after selection".

    // We force a rebuild or just snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Selected $orgName${storeName != null ? ' - $storeName' : ''}')),
    );

    // Optional: If we want to refresh the list UI to show the checkmark (it handles itself via Riverpod watch)
    setState(() {});
  }

  void _showStoreSelectionDialog(List<dynamic> stores) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Store',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    return ListTile(
                      leading: const Icon(Icons.store, color: Colors.indigo),
                      title: Text(store.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref
                            .read(organizationProvider.notifier)
                            .selectStore(store);
                        Navigator.pop(ctx); // Close sheet
                        _onSelectionComplete(
                            ref
                                    .read(organizationProvider)
                                    .selectedOrganization
                                    ?.name ??
                                '',
                            store.name);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(dynamic org) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Organization?'),
        content: Text('Are you sure you want to delete ${org.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        await ref
            .read(organizationProvider.notifier)
            .deleteOrganization(org.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${org.name} deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationProvider);
    final orgs = state.organizations;

    // Filter Logic
    final filteredOrgs = orgs.where((org) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = org.name.toLowerCase().contains(query) ||
          (org.code != null && org.code!.toLowerCase().contains(query));
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('dashboard'),
        ),
        title: const Text('Organizations'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(organizationProvider.notifier).loadOrganizations(),
          ),
          if (ref.watch(authProvider).role == UserRole.superUser)
            TextButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New', style: TextStyle(color: Colors.white)),
              onPressed: () => context.goNamed('organization-create'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          Expanded(
            child: state.isLoading && orgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error loading data: ${state.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                      ))
                    : filteredOrgs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('No organizations found',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      context.pushNamed('organization-create'),
                                  child: const Text('Create Organization'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredOrgs.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final org = filteredOrgs[index];
                              final isSelected =
                                  state.selectedOrganization?.id == org.id;
                              return _buildOrganizationItem(org, isSelected);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
