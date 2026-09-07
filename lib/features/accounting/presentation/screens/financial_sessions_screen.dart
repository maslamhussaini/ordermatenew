// lib/features/accounting/presentation/screens/financial_sessions_screen.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class FinancialSessionsScreen extends ConsumerStatefulWidget {
  const FinancialSessionsScreen({super.key});

  @override
  ConsumerState<FinancialSessionsScreen> createState() =>
      _FinancialSessionsScreenState();
}

class _FinancialSessionsScreenState
    extends ConsumerState<FinancialSessionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      ref.read(accountingProvider.notifier).loadAll(organizationId: org?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final sessions = state.financialSessions.where((s) {
      return s.sYear.toString().contains(_searchQuery) ||
          (s.narration?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(accountingProvider.notifier).loadAll(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : Column(
                  children: [
                    if (state.financialSessions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search sessions by year...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear())
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    Expanded(
                      child: sessions.isEmpty && _searchQuery.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text('No financial sessions found'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => context.push(
                                        '/accounting/financial-sessions/create'),
                                    child: const Text('Create First Session'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                final dateFormat = DateFormat('dd MMM yyyy');

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: session.inUse
                                          ? Colors.green
                                          : Colors.grey,
                                      child: Text(
                                        session.sYear.toString().substring(2),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      'Fiscal Year ${session.sYear}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${dateFormat.format(session.startDate)} - ${dateFormat.format(session.endDate)}'),
                                        if (session.narration != null &&
                                            session.narration!.isNotEmpty)
                                          Text(
                                            session.narration!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (session.inUse)
                                          const Chip(
                                            label: Text('ACTIVE',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white)),
                                            backgroundColor: Colors.green,
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                    onTap: () => context.push(
                                        '/accounting/financial-sessions/edit/${session.sYear}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounting/financial-sessions/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }
}
