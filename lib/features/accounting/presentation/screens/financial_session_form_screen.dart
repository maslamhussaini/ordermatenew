// lib/features/accounting/presentation/screens/financial_session_form_screen.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class FinancialSessionFormScreen extends ConsumerStatefulWidget {
  final int? sYear;
  const FinancialSessionFormScreen({super.key, this.sYear});

  @override
  ConsumerState<FinancialSessionFormScreen> createState() =>
      _FinancialSessionFormScreenState();
}

class _FinancialSessionFormScreenState
    extends ConsumerState<FinancialSessionFormScreen> {
  /// FIX (H-10): true when the record being edited no longer exists.
  bool _recordMissing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _yearController;
  late TextEditingController _narrationController;
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime(DateTime.now().year, 12, 31);

  String _yearType =
      'Calendar Year'; // Calendar Year, Financial Year, Fiscal Year
  final List<String> _yearTypes = [
    'Calendar Year',
    'Financial Year',
    'Fiscal Year'
  ];

  bool _inUse = false;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController();
    _narrationController = TextEditingController();

    if (widget.sYear != null) {
      // FIX (H-10): see account_type_form_screen.
      final session = ref
          .read(accountingProvider)
          .financialSessions
          .where((s) => s.sYear == widget.sYear)
          .firstOrNull;
      if (session == null) {
        _recordMissing = true;
      } else {
      _yearController.text = session.sYear.toString();
      _narrationController.text = session.narration ?? '';
      _startDate = session.startDate;
      _endDate = session.endDate;
      _inUse = session.inUse;
      _isActive = session.isActive;
      // Heuristic to detect type if editing
      if (_startDate.month == 1 &&
          _startDate.day == 1 &&
          _endDate.month == 12 &&
          _endDate.day == 31) {
        _yearType = 'Calendar Year';
      } else if (_startDate.month == 7 &&
          _startDate.day == 1 &&
          _endDate.month == 6 &&
          _endDate.day == 30) {
        _yearType = 'Financial Year';
      } else {
        _yearType = 'Fiscal Year';
      }
      }
    } else {
      _yearController.text = DateTime.now().year.toString();
      _recalcDates(); // Init defaults
    }
  }

  void _recalcDates() {
    final year = int.tryParse(_yearController.text);
    if (year == null) return;

    if (_yearType == 'Calendar Year') {
      setState(() {
        _startDate = DateTime(year, 1, 1);
        _endDate = DateTime(year, 12, 31);
      });
    } else if (_yearType == 'Financial Year') {
      setState(() {
        _startDate = DateTime(year, 7, 1); // 1st July
        _endDate = DateTime(year + 1, 6, 30); // 30th June next year
      });
    } else if (_yearType == 'Fiscal Year') {
      // Default logic: Today to +12 months, user editable
      // Keep existing if manually set, otherwise set default span?
      // For new entry, let's default to current date -> +1 year
      if (widget.sYear == null) {
        setState(() {
          _startDate = DateTime.now();
          _endDate = DateTime.now().add(const Duration(days: 365));
        });
      }
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    // Only allow edit if Fiscal Year is selected
    if (_yearType != 'Fiscal Year') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Dates are auto-calculated for Calendar and Financial Year.')));
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 364));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Strict Validation: Ensure sYear exists (implicit in text field)
    if (_yearController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial Year ID cannot be empty')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(organizationProvider).selectedOrganization?.id;

      final account = FinancialSession(
        sYear: int.parse(_yearController.text),
        startDate: _startDate,
        endDate: _endDate,
        narration: _narrationController.text.trim(),
        inUse: _inUse,
        isActive: _isActive,
        organizationId: orgId ?? 0,
        // isClosed: false  // Default
      );

      final notifier = ref.read(accountingProvider.notifier);
      if (widget.sYear == null) {
        await notifier.addFinancialSession(account, organizationId: orgId);
      } else {
        await notifier.updateFinancialSession(account, organizationId: orgId);
      }

      // If marked in_use, we might want to unmark others? handled by repo typically or manual

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial session saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recordMissing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financial Year')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This financial year could not be found. It may have been deleted or is not yet synced.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sYear == null
            ? 'New Financial Session'
            : 'Edit Session ${widget.sYear}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SYear Field
                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Financial Year ID',
                        border: OutlineInputBorder(),
                        helperText: 'Unique Year Identifier (e.g. 2025)',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: widget.sYear == null,
                      onChanged: (_) => _recalcDates(),
                      validator: (value) =>
                          (value == null || int.tryParse(value) == null)
                              ? 'Invalid year'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Year Type Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _yearType,
                          isExpanded: true,
                          items: _yearTypes
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: widget.sYear == null
                              ? (val) {
                                  if (val != null) {
                                    setState(() => _yearType = val);
                                    _recalcDates();
                                  }
                                }
                              : null, // Disable changing type on edit for safety, or allow? Better minimal changes on edit.
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Type: Calendar (Jan-Dec), Financial (Jul-Jun), Fiscal (Custom)',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),

                    const Text('Session Duration',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(context, true),
                            icon: const Icon(Icons.date_range),
                            label:
                                Text('From: ${dateFormat.format(_startDate)}'),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: _yearType == 'Fiscal Year'
                                    ? null
                                    : Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDate(context, false),
                            icon: const Icon(Icons.date_range),
                            label: Text('To: ${dateFormat.format(_endDate)}'),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: _yearType == 'Fiscal Year'
                                    ? null
                                    : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _narrationController,
                      decoration: const InputDecoration(
                        labelText: 'Narration / Description',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. FY 2024-25',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mark as Current Session'),
                      subtitle: const Text(
                          'Currently active period for all transactions'),
                      value: _inUse,
                      onChanged: (val) => setState(() => _inUse = val),
                    ),
                    SwitchListTile(
                      title: const Text('Status Active'),
                      value: _isActive,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Save Financial Session'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
