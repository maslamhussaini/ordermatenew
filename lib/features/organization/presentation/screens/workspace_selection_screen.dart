import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/domain/entities/financial_year_option.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';

class WorkspaceSelectionScreen extends ConsumerStatefulWidget {
  const WorkspaceSelectionScreen({super.key});

  @override
  ConsumerState<WorkspaceSelectionScreen> createState() =>
      _WorkspaceSelectionScreenState();
}

class _WorkspaceSelectionScreenState
    extends ConsumerState<WorkspaceSelectionScreen> {
  bool _isLoading = true;
  bool _isProcessing = false; // Added processing flag
  List<Organization> _organizations = [];
  Organization? _selectedOrganization;
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _storesLoading = false;
  String? _storesError;

  // Financial sessions are fetched directly here (not read off
  // accountingProvider.financialSessions) so a genuine fetch error can be
  // told apart from "the organization simply has none yet" — AccountingNotifier
  // .loadAll() deliberately swallows a per-metadata-type failure into an
  // empty list (so one broken table doesn't block loading the rest of the
  // app's accounting data), which made a real error indistinguishable from
  // "No sessions found" here.
  List<FinancialSession> _financialSessions = [];
  FinancialSession? _selectedSession;
  bool _sessionsLoading = false;
  String? _sessionsError;
  bool _creatingSession = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrganizationRepositoryImpl();
      final orgs = await repo.getOrganizations();

      if (!mounted) return;

      setState(() {
        _organizations = orgs;
        if (orgs.isNotEmpty) {
          // Check if an org is already selected in the provider
          final currentOrgId =
              ref.read(organizationProvider).selectedOrganizationId;
          _selectedOrganization =
              orgs.where((o) => o.id == currentOrgId).firstOrNull ?? orgs.first;
        }
      });

      if (_selectedOrganization != null) {
        await _fetchStores(_selectedOrganization!.id);
        await _fetchFinancialSessions(_selectedOrganization!.id);
      }
    } catch (e) {
      debugPrint('Error fetching initial workplace data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStores(int orgId) async {
    setState(() {
      _storesLoading = true;
      _storesError = null;
    });
    try {
      // Route through OrganizationNotifier.loadStores rather than calling
      // the repository directly: that's where store-wise internal-user
      // access is enforced (omtbl_user_store_access / omtbl_role_store_access
      // / the single omtbl_users.store_id), so calling the repository here
      // directly bypassed it and showed every store in the org to every
      // user, regardless of their assignment.
      final notifier = ref.read(organizationProvider.notifier);
      await notifier.loadStores(orgId);

      if (!mounted) return;

      final orgState = ref.read(organizationProvider);
      if (orgState.error != null) {
        // loadStores() resets `error` to null on its own success path (see
        // OrganizationState.copyWith), so a non-null error here is specific
        // to this call.
        throw orgState.error!;
      }

      final stores = orgState.stores;
      setState(() {
        _stores = stores;
        if (stores.isNotEmpty) {
          final currentStoreId = ref.read(organizationProvider).selectedStoreId;
          _selectedStore =
              stores.where((s) => s.id == currentStoreId).firstOrNull ??
                  orgState.selectedStore;
        } else {
          _selectedStore = null;
        }
      });
    } catch (e) {
      debugPrint('Error fetching stores: $e');
      if (!mounted) return;
      // Distinct error state: do not silently show an "empty" store list
      // when the fetch actually failed (e.g. network/RLS error) — those are
      // different states and need different UI/recovery (retry vs "add a store").
      setState(() {
        _stores = [];
        _selectedStore = null;
        _storesError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  Future<void> _fetchFinancialSessions(int orgId) async {
    setState(() {
      _sessionsLoading = true;
      _sessionsError = null;
    });
    try {
      debugPrint('🔍 [WorkspaceSelection] Fetching financial sessions for orgId: $orgId');

      final repo = ref.read(accountingRepositoryProvider);
      final sessions = await repo.getFinancialSessions(organizationId: orgId);

      // Also refresh the app-wide accounting state (GL setup, invoice types,
      // etc. that the rest of the app needs once a workspace is selected).
      // Best-effort: its own internal swallowing must not override the
      // authoritative result/error already determined above.
      unawaited(ref.read(accountingProvider.notifier).loadAll(organizationId: orgId));

      if (!mounted) return;

      debugPrint('📊 [WorkspaceSelection] Loaded ${sessions.length} financial sessions');
      for (var session in sessions) {
        debugPrint('   - sYear: ${session.sYear}, Active: ${session.isActive}, InUse: ${session.inUse}, OrgId: ${session.organizationId}');
      }

      final persistedYear = ref.read(organizationProvider).selectedFinancialYear;
      final resolved = FinancialSession.resolveDefault(
        sessions,
        persistedSyear: persistedYear,
      );

      debugPrint('✅ [WorkspaceSelection] Selected session: ${resolved?.sYear}');

      setState(() {
        _financialSessions = sessions;
        _selectedSession = resolved;
      });
    } catch (e) {
      debugPrint('❌ [WorkspaceSelection] Error fetching financial sessions: $e');
      if (!mounted) return;
      setState(() {
        _financialSessions = [];
        _selectedSession = null;
        _sessionsError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  /// Self-heal for an organization that (due to the now-fixed registration
  /// defect) ended up with zero financial sessions: lets an Owner/Admin
  /// create the missing session from here, through the normal authenticated
  /// app flow — never by inserting directly into the database.
  Future<void> _createFinancialSessionFlow() async {
    final org = _selectedOrganization;
    if (org == null || _creatingSession) return;

    final period = await showDialog<FinancialYearPeriod>(
      context: context,
      builder: (context) => const _CreateFinancialSessionDialog(),
    );
    if (period == null || !mounted) return;

    setState(() => _creatingSession = true);
    try {
      await ref.read(organizationRepositoryProvider).createFinancialSession(
            organizationId: org.id,
            syear: period.syear,
            startDate: period.startDate,
            endDate: period.endDate,
          );
      if (!mounted) return;
      await _fetchFinancialSessions(org.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to create financial year: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creatingSession = false);
    }
  }

  Future<void> _continueToDashboard() async {
    if (_isProcessing) return;

    final effectiveSession = _selectedSession;

    debugPrint('WorkspaceSelectionScreen: Continue to Dashboard clicked.');
    debugPrint(' - Selected Org: ${_selectedOrganization?.id}');
    debugPrint(' - Selected Store: ${_selectedStore?.id}');
    debugPrint(' - Selected Session: ${effectiveSession?.sYear}');

    if (_selectedOrganization == null ||
        _selectedStore == null ||
        effectiveSession == null) {
      String missing = '';
      if (_selectedOrganization == null) missing += 'Organization, ';
      if (_selectedStore == null) missing += 'Store, ';
      if (effectiveSession == null) missing += 'Financial Year';

      debugPrint('WorkspaceSelectionScreen: Blocked - Missing: $missing');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select missing: $missing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orgNotifier = ref.read(organizationProvider.notifier);

      await orgNotifier.setWorkspace(
        organization: _selectedOrganization!,
        store: _selectedStore,
        financialYear: effectiveSession.sYear,
      );

      // Also update accounting provider for consistency across app
      ref
          .read(accountingProvider.notifier)
          .selectFinancialSession(effectiveSession);

      if (!mounted) return;

      final landingPage = ref.read(settingsProvider).landingPage;
      debugPrint('WorkspaceSelectionScreen: Navigating to $landingPage');

      context.go(landingPage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Workspace selected: ${_selectedOrganization!.name} - ${_selectedStore!.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('WorkspaceSelectionScreen: Error continuing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authState = ref.watch(authProvider);
    final canManageFinancialSessions =
        authState.role == UserRole.admin || authState.role == UserRole.superUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.get('select_workspace') ??
            'Select Workspace'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.grey.shade900, Colors.black]
                : [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.business_center_rounded,
                          size: 80, color: AppColors.loginGradientStart),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)
                                ?.get('workspace_configuration') ??
                            'Configuration',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm your organization, store and financial period',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 32),

                      // Organization Dropdown
                      _buildDropdown(
                        label:
                            AppLocalizations.of(context)?.get('organization') ??
                                'Organization',
                        icon: Icons.domain,
                        value: _selectedOrganization,
                        items: _organizations
                            .map((org) => DropdownMenuItem(
                                  value: org,
                                  child: Text(org.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedOrganization = val;
                            _stores = [];
                            _selectedStore = null;
                            _financialSessions = [];
                            _selectedSession = null;
                            _storesError = null;
                            _sessionsError = null;
                          });
                          if (val != null) {
                            _fetchStores(val.id);
                            _fetchFinancialSessions(val.id);
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Store Dropdown
                      _buildDropdown<Store>(
                        label:
                            AppLocalizations.of(context)?.get('store_branch') ??
                                'Store / Branch',
                        icon: Icons.store,
                        value: _selectedStore,
                        items: _stores.map((store) => DropdownMenuItem(
                                value: store,
                                child: Text(store.name),
                              )).toList(),
                        onChanged: _storesLoading
                            ? null
                            : (Store? val) {
                                setState(() => _selectedStore = val);
                              },
                        hintText: _storesLoading
                            ? 'Loading stores...'
                            : (_storesError != null
                                ? 'Failed to load stores'
                                : (_stores.isEmpty
                                    ? 'No stores found'
                                    : 'Select Store')),
                      ),
                      if (_storesError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Error: $_storesError',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: _selectedOrganization == null
                                    ? null
                                    : () => _fetchStores(
                                        _selectedOrganization!.id),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (!_storesLoading &&
                          _stores.isEmpty &&
                          _selectedOrganization != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'No stores found for this organization.',
                            style:
                                TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Financial Year Dropdown
                      _buildDropdown<FinancialSession>(
                        label: AppLocalizations.of(context)
                                ?.get('financial_year') ??
                            'Financial Year',
                        icon: Icons.calendar_today,
                        value: _selectedSession,
                        items: _financialSessions
                            .map((session) => DropdownMenuItem(
                                  value: session,
                                  child: Text(
                                      '${session.sYear} (${DateFormat('MMM yy').format(session.startDate)} - ${DateFormat('MMM yy').format(session.endDate)})'),
                                ))
                            .toList(),
                        onChanged: _sessionsLoading
                            ? null
                            : (val) {
                                setState(() => _selectedSession = val);
                              },
                        hintText: _sessionsLoading
                            ? 'Loading sessions...'
                            : (_sessionsError != null
                                ? 'Failed to load sessions'
                                : (_financialSessions.isEmpty
                                    ? 'No sessions found'
                                    : 'Select Financial Year')),
                      ),

                      if (_sessionsError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Error: $_sessionsError',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: _selectedOrganization == null
                                    ? null
                                    : () => _fetchFinancialSessions(
                                        _selectedOrganization!.id),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (!_sessionsLoading &&
                          _financialSessions.isEmpty &&
                          _selectedOrganization != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'No financial year found for this organization.',
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ),
                              if (canManageFinancialSessions)
                                TextButton(
                                  onPressed: _creatingSession
                                      ? null
                                      : _createFinancialSessionFlow,
                                  child: _creatingSession
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text('Create Financial Year'),
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 48),

                      ElevatedButton(
                        onPressed: (_selectedOrganization != null &&
                                _selectedStore != null &&
                                _selectedSession != null &&
                                !_isProcessing)
                            ? _continueToDashboard
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loginGradientStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                            ?.get('continue_to_dashboard') ??
                                        'Continue to Dashboard',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.loginGradientStart),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: items,
          onChanged: onChanged,
          hint: Text(hintText ?? 'Select $label'),
        ),
      ],
    );
  }
}

/// Minimal "which Financial Year method does this company use" dialog,
/// reusing the same three modes and date math offered during registration
/// (see organization_setup_screen.dart / FinancialYearCalculator) so an
/// Owner/Admin can create the missing session for an already-registered
/// organization without going through the database directly.
class _CreateFinancialSessionDialog extends StatefulWidget {
  const _CreateFinancialSessionDialog();

  @override
  State<_CreateFinancialSessionDialog> createState() =>
      _CreateFinancialSessionDialogState();
}

class _CreateFinancialSessionDialogState
    extends State<_CreateFinancialSessionDialog> {
  FinancialYearMode _mode = FinancialYearMode.calendarYear;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _error;

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _customStart : _customEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = picked;
      }
    });
  }

  void _submit() {
    try {
      final period = FinancialYearCalculator.resolve(
        mode: _mode,
        customStart: _customStart,
        customEnd: _customEnd,
      );
      Navigator.of(context).pop(period);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Financial Year'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<FinancialYearMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: FinancialYearMode.calendarYear,
            groupValue: _mode,
            title: Text('Calendar Year (Jan 1 - Dec 31, ${DateTime.now().year})'),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          RadioListTile<FinancialYearMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: FinancialYearMode.julyToJune,
            groupValue: _mode,
            title: const Text('July 1 - June 30'),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          RadioListTile<FinancialYearMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: FinancialYearMode.fiscalCustom,
            groupValue: _mode,
            title: const Text('Fiscal / Custom'),
            onChanged: (v) => setState(() => _mode = v!),
          ),
          if (_mode == FinancialYearMode.fiscalCustom) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_customStart == null
                        ? 'Start Date'
                        : DateFormat('dd MMM yyyy').format(_customStart!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_customEnd == null
                        ? 'End Date'
                        : DateFormat('dd MMM yyyy').format(_customEnd!)),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
