// lib/features/employees/presentation/screens/user_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:intl/intl.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () {
        ref.read(businessPartnerProvider.notifier).loadAppUsers();
        ref
            .read(businessPartnerProvider.notifier)
            .loadEmployees(); // Load employees for import
      },
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> _selectedEmployeeIdsForImport = [];

  Future<void> _showImportDialog() async {
    final bpState = ref.read(businessPartnerProvider);
    final existingUserPartnerIds =
        bpState.appUsers.map((u) => u.businessPartnerId).toSet();

    // Filter employees:
    // 1. Must be Employee
    // 2. Must NOT already be an App User
    // 3. Must have Email and Password (implied "Grant Access")
    final eligibleEmployees = bpState.employees.where((e) {
      final isAlreadyUser = existingUserPartnerIds.contains(e.id);
      final hasEmail = e.email != null && e.email!.isNotEmpty;
      final hasRole = e.roleId != null && e.roleId != 0;
      return !isAlreadyUser && hasEmail && hasRole;
    }).toList();

    if (eligibleEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No eligible employees found for import (Must have Email and Role assigned)')),
      );
      return;
    }

    _selectedEmployeeIdsForImport.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Import Users from Employees'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: eligibleEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = eligibleEmployees[index];
                    final isSelected =
                        _selectedEmployeeIdsForImport.contains(emp.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(emp.name),
                      subtitle: Text(
                          '${emp.email ?? "No Email"} - ${emp.roleName ?? "No Role"}'),
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            _selectedEmployeeIdsForImport.add(emp.id);
                          } else {
                            _selectedEmployeeIdsForImport.remove(emp.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _selectedEmployeeIdsForImport.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _executeImport(eligibleEmployees
                              .where((e) =>
                                  _selectedEmployeeIdsForImport.contains(e.id))
                              .toList());
                        },
                  child:
                      Text('Import (${_selectedEmployeeIdsForImport.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeImport(List<BusinessPartner> employees) async {
    // Dynamic cast fix: List<BusinessPartner>
    final partnerList = employees;

    try {
      await ref
          .read(businessPartnerProvider.notifier)
          .importAppUsersFromEmployees(partnerList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Successfully imported ${partnerList.length} users')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bpState = ref.watch(businessPartnerProvider);
    final users = bpState.appUsers;

    final filteredUsers = users.where((u) {
      final query = _searchQuery.toLowerCase();
      return u.email.toLowerCase().contains(query) ||
          (u.fullName?.toLowerCase().contains(query) ?? false) ||
          (u.roleName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Users'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(businessPartnerProvider.notifier).loadAppUsers(),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import from Employees',
            onPressed: _showImportDialog,
          ),
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New', style: TextStyle(color: Colors.white)),
            onPressed: () {
              context.goNamed('user-create');
            },
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
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // User List
          Expanded(
            child: bpState.isLoading && users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : bpState.error != null
                    ? Center(child: Text('Error: ${bpState.error}'))
                    : filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  users.isEmpty
                                      ? 'No users found.'
                                      : 'No results found.',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return _buildUserItem(user);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(AppUser user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              user.isActive ? Colors.blue.shade50 : Colors.grey.shade100,
          child: Icon(
            Icons.person,
            color: user.isActive ? Colors.blue.shade800 : Colors.grey,
          ),
        ),
        title: Builder(builder: (context) {
          final bpState = ref.watch(businessPartnerProvider);
          final employee = bpState.employees.cast<BusinessPartner>().firstWhere(
                (e) => e.id == user.businessPartnerId,
                orElse: () => BusinessPartner(
                    id: '',
                    name: '',
                    phone: '',
                    email: null,
                    address: '',
                    organizationId: 0,
                    storeId: 0,
                    isActive: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now()),
              );
          final displayName = user.fullName ??
              (employee.name.isNotEmpty ? employee.name : user.email);

          return Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        }),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Builder(builder: (context) {
                    final bpState = ref.watch(businessPartnerProvider);
                    final role = bpState.roles.firstWhere(
                      (r) => r['id'] == user.roleId,
                      orElse: () => {},
                    );
                    final displayRole = role['role_name']?.toString() ??
                        user.roleName ??
                        'No Role';

                    return Text(
                      displayRole,
                      style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                if (!user.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (user.lastLogin != null)
              Text(
                'Last Login: ${DateFormat('MMM dd, yyyy HH:mm').format(user.lastLogin!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {
            // Navigator to user form with user data
            context.goNamed('user-edit', pathParameters: {'id': user.id});
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}
