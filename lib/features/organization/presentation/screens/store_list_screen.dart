import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/router/route_names.dart';

class StoreListScreen extends ConsumerStatefulWidget {
  const StoreListScreen({super.key});

  @override
  ConsumerState<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends ConsumerState<StoreListScreen> {
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
    // Assuming stores are loaded with organizations or we need a specific loadStores call
    // For now, refreshing organizations usually loads related stores if structured that way,
    // but looking at provider, it likely filters stores by selected organization.
    // If this screen shows ALL stores, we might need a specific method.
    // Let's assume we show stores for the *selected* organization if any, or we might need to fetch all.
    Future.microtask(
      () => ref.read(organizationProvider.notifier).loadOrganizations(),
    );
  }

  Future<bool> _deleteStoreWithProgress(dynamic store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text('Are you sure you want to delete ${store.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    if (!mounted) return false;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref
          .read(organizationProvider.notifier)
          .deleteStore(store.id, store.organizationId);
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${store.name} deleted.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return false;
    }
  }

  Widget _buildStoreItem(dynamic store, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: Border.all(color: Colors.transparent),
        leading: CircleAvatar(
          backgroundColor:
              isSelected ? Colors.green.shade50 : Colors.teal.shade50,
          child: Icon(
            Icons.store,
            color: isSelected ? Colors.green : Colors.teal,
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
                store.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? Colors.green.shade800 : Colors.teal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          store.location ?? 'No address',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isSelected) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(organizationProvider.notifier)
                        .selectStore(store);
                    if (mounted) {
                      context.goNamed('dashboard');
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Selected ${store.name}')));
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Select'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  context.pushNamed(RouteNames.storeEdit,
                      pathParameters: {'id': store.id.toString()});
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
                onPressed:
                    !isSelected ? () => _deleteStoreWithProgress(store) : null,
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  disabledForegroundColor: Colors.grey,
                  side: BorderSide(
                    color: !isSelected
                        ? Colors.red.shade200
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationProvider);
    final stores =
        state.stores; // These are stores of the selected organization

    // Filter Logic
    final filteredStores = stores.where((store) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = store.name.toLowerCase().contains(query) ||
          (store.location != null &&
              store.location!.toLowerCase().contains(query));
      return matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('dashboard'),
        ),
        title: const Text('Branches (Stores)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                // Assuming we want to refresh for the selected org.
                // If we don't know the org ID here easily, we rely on provider state.
                state.selectedOrganization != null
                    ? ref
                        .read(organizationProvider.notifier)
                        .loadStores(state.selectedOrganization!.id)
                    : ref
                        .read(organizationProvider.notifier)
                        .loadOrganizations(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () => context.pushNamed(RouteNames.storeCreate),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search branches...',
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
            child: state.isLoading && stores.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredStores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            if (state.selectedOrganization != null) ...[
                              const Text('No branches found',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    context.pushNamed(RouteNames.storeCreate),
                                child: const Text('Create Branch'),
                              )
                            ] else
                              const Text('Select an Organization first',
                                  style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredStores.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final store = filteredStores[index];
                          final isSelected =
                              state.selectedStore?.id == store.id;
                          return _buildStoreItem(store, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
