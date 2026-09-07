import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/router/route_names.dart';

class RoleListScreen extends ConsumerStatefulWidget {
  const RoleListScreen({super.key});

  @override
  ConsumerState<RoleListScreen> createState() => _RoleListScreenState();
}

class _RoleListScreenState extends ConsumerState<RoleListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(businessPartnerProvider.notifier).loadRoles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessPartnerProvider);
    final roles = state.roles;

    final filteredRoles = roles.where((role) {
      final name = (role['role_name'] ?? '').toString().toLowerCase();
      final desc = (role['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(businessPartnerProvider.notifier).loadRoles(),
            tooltip: 'Refresh',
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () => context.push('/employees/roles/create'),
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
                hintText: 'Search roles...',
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
            child: state.isLoading && roles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && roles.isEmpty
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredRoles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.security_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  roles.isEmpty
                                      ? 'No roles found.'
                                      : 'No results found.',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRoles.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                                    final role = filteredRoles[index];
                                    final isSystem = role['is_system'] == 1 ||
                                        role['is_system'] == true ||
                                        (role['role_name'] ?? '')
                                            .toString()
                                            .toUpperCase()
                                            .contains('SUPER') ||
                                        (role['role_name'] ?? '')
                                                .toString()
                                                .toUpperCase() ==
                                            'OWNER';

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: ExpansionTile(
                                        shape: Border.all(
                                            color: Colors.transparent),
                                        leading: CircleAvatar(
                                          backgroundColor: isSystem
                                              ? Colors.orange.shade50
                                              : Colors.blue.shade50,
                                          child: Icon(
                                              isSystem
                                                  ? Icons.lock
                                                  : Icons.verified_user,
                                              color: isSystem
                                                  ? Colors.orange.shade800
                                                  : Colors.blue.shade800),
                                        ),
                                        title: Text(
                                          role['role_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        trailing: isSystem
                                            ? const Chip(
                                                label: Text('System',
                                                    style: TextStyle(
                                                        fontSize: 10)),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              )
                                            : null,
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              role['description'] ??
                                                  'No description provided',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              children: [
                                                if (role['can_read'] == 1 ||
                                                    role['can_read'] == true)
                                                  _buildPrivilegeChip(
                                                      'Read', Colors.green),
                                                if (role['can_write'] == 1 ||
                                                    role['can_write'] == true)
                                                  _buildPrivilegeChip(
                                                      'Write', Colors.blue),
                                                if (role['can_edit'] == 1 ||
                                                    role['can_edit'] == true)
                                                  _buildPrivilegeChip(
                                                      'Edit', Colors.orange),
                                                if (role['can_print'] == 1 ||
                                                    role['can_print'] == true)
                                                  _buildPrivilegeChip(
                                                      'Print', Colors.purple),
                                              ],
                                            ),
                                          ],
                                        ),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(
                                                16, 0, 16, 16),
                                        children: [
                                          const Divider(),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () => context
                                                    .pushNamed(
                                                        RouteNames.roleEdit,
                                                        pathParameters: {
                                                      'id': role['id']
                                                          .toString()
                                                    }),
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                label: const Text('View/Edit'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.blue,
                                                  side: BorderSide(
                                                      color: Colors
                                                          .blue.shade200),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (!isSystem)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showDeleteConfirmation(
                                                          role),
                                                  icon: const Icon(
                                                      Icons.delete,
                                                      size: 18),
                                                  label: const Text('Delete'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: BorderSide(
                                                        color: Colors
                                                            .red.shade200),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
            'Are you sure you want to delete the role "${role['role_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await ref
                    .read(businessPartnerProvider.notifier)
                    .deleteRole(role['id']);
                navigator.pop();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
