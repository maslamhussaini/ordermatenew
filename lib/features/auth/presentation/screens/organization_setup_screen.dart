import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ordermate/core/router/app_router.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/services/email_service.dart';
import 'package:ordermate/features/organization/domain/entities/financial_year_option.dart';
import 'package:intl/intl.dart';

class OrganizationSetupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const OrganizationSetupScreen({super.key, required this.userData});

  @override
  ConsumerState<OrganizationSetupScreen> createState() =>
      _OrganizationSetupScreenState();
}

class _OrganizationSetupScreenState
    extends ConsumerState<OrganizationSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();

  // Single Branch Address Fields
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _currencyController = TextEditingController();
  final _contactPersonController = TextEditingController();

  bool _hasMultipleBranch = false;
  int? _selectedBusinessTypeId;

  // Financial Year selection (registration success criteria requires exactly
  // 1 active Financial Session, regardless of the Multiple Branches choice).
  FinancialYearMode _fyMode = FinancialYearMode.calendarYear;
  DateTime? _fyCustomStart;
  DateTime? _fyCustomEnd;
  // Signup-time module selection. Defaults reflect a typical small-business
  // starting point (Sales + Inventory), not "everything on" — the org owner
  // actively chooses which purchased modules to enable via the checkboxes
  // in the UI below. is_settings is not a purchasable module (every org
  // needs its own settings/profile), so it stays true unconditionally.
  bool _isGL = false;
  bool _isSales = true;
  bool _isInventory = true;
  bool _isHR = false;
  final bool _isSettings = true;

  bool _isLoading = false;
  XFile? _pickedFile;
  Uint8List? _previewBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _orgNameController.text = widget.userData['organization_name'] ?? '';
    // Editable default so registration isn't harder for the common case, but
    // the value that actually gets stored always comes from this field —
    // never a hardcoded literal (see _registerAndCreate).
    _storeNameController.text = 'Main Branch';
    // Load business types
    Future.microtask(() =>
        ref.read(businessPartnerProvider.notifier).loadBusinessTypes());
  }

  Future<void> _pickImage() async {
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

  @override
  void dispose() {
    _orgNameController.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _currencyController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  /// Resolves the selected Financial Year mode into concrete dates, or
  /// returns null (after showing a SnackBar) if the selection is incomplete.
  FinancialYearPeriod? _resolveFinancialYear() {
    try {
      return FinancialYearCalculator.resolve(
        mode: _fyMode,
        customStart: _fyCustomStart,
        customEnd: _fyCustomEnd,
      );
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_fyMode == FinancialYearMode.fiscalCustom
              ? 'Please select a valid Financial Year start and end date.'
              : 'Financial Year error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _pickFyDate({required bool isStart}) async {
    final initial = (isStart ? _fyCustomStart : _fyCustomEnd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _fyCustomStart = picked;
      } else {
        _fyCustomEnd = picked;
      }
    });
  }

  void _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    final fyPeriod = _resolveFinancialYear();
    if (fyPeriod == null) return;
 
    final orgName = _orgNameController.text.trim();
    final bpState = ref.read(businessPartnerProvider);
    final businessType = bpState.businessTypes.firstWhere(
        (t) => t['id'] == _selectedBusinessTypeId,
        orElse: () => {'business_type': 'Unknown'})['business_type'];
 
    final email = widget.userData['email'] ?? '';
 

 
    if (_hasMultipleBranch) {
      context.push('/onboarding/store', extra: {
        'userData': widget.userData,
        'orgData': {
          'name': orgName,
          'hasMultipleBranch': 'true',
          'logoBytes': _previewBytes,
          'logoName': _pickedFile?.name,
          'businessTypeId': _selectedBusinessTypeId,
          'isGL': _isGL,
          'isSales': _isSales,
          'isInventory': _isInventory,
          'isHR': _isHR,
          'isSettings': _isSettings,
          // Financial Year, resolved here so store_setup_screen (Multiple
          // Branches ON flow) doesn't need its own selection UI.
          'fySyear': fyPeriod.syear,
          'fyStartDate': fyPeriod.startDate.toIso8601String(),
          'fyEndDate': fyPeriod.endDate.toIso8601String(),
        }
      });
    } else {
      await _registerAndCreate(
        storeName: _storeNameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        postal: _postalCodeController.text.trim(),
        currency: _currencyController.text.trim(),
        contact: _contactPersonController.text.trim(),
        fyPeriod: fyPeriod,
      );
    }
  }

  Future<void> _registerAndCreate({
    required String storeName,
    required String address,
    required String city,
    required String country,
    required String postal,
    required String currency,
    required String contact,
    required FinancialYearPeriod fyPeriod,
  }) async {
    setState(() => _isLoading = true);

    // Captured BEFORE any await, not read again later: the instant
    // auth.signUp() below succeeds, Supabase fires AuthChangeEvent.signedIn,
    // authProvider flips isLoggedIn, and the router — which now sees a
    // logged-in user on what it treats as a guest-only route — redirects
    // and disposes this screen while _registerAndCreate() is still
    // mid-flight. Steps that call SupabaseConfig.client directly (org/user/
    // store inserts) don't care and complete fine; a `ref.read(...)` called
    // AFTER that point throws "Cannot use ref after the widget was
    // disposed." This is exactly why org+store could exist with zero
    // financial sessions: step 5 below is the first step that needs `ref`,
    // so it was the first to fail — silently, since the exception only
    // reached a SnackBar on an already-disposed screen. Grabbing the plain
    // (non-widget-bound) repository instance up front sidesteps the race
    // entirely.
    final repo = ref.read(organizationRepositoryProvider);
    final authNotifier = ref.read(authProvider.notifier);
    // Also captured up front, for the same reason: GoRouter.push() works
    // directly on the router instance and does not need a BuildContext, so
    // navigation below survives this screen being disposed post-signUp
    // (see the mounted=false diagnostic that proved this actually happens).
    final router = ref.read(routerProvider);

    try {
      final email = widget.userData['email']!;
      final password = widget.userData['password']!;
      final fullName = widget.userData['fullName']!;
      final phone = widget.userData['phone']!;
      final orgName = _orgNameController.text.trim();

      const redirectTo = 'ordermate://login-callback';

      if (SupabaseConfig.client.auth.currentSession != null) {
        await SupabaseConfig.client.auth.signOut();
      }

      // 1. Sign Up User
      final authResponse = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectTo,
        data: {
          'full_name': fullName,
          'phone': phone,
          'organization_name': orgName,
        },
      );

      if (authResponse.user == null) {
        throw 'Registration failed. Please try again.';
      }

      // Every write below is tenant-scoped by RLS and resolves auth.uid().
      // With "Confirm email" enabled, signUp returns a user but NO session, so
      // those writes execute as `anon`, auth.uid() is NULL, and the organization
      // insert is rejected by its WITH CHECK with no actionable error surfaced.
      // Fail loudly and specifically instead.
      if (authResponse.session == null) {
        throw 'Account created, but no active session was returned. '
            'Self-serve onboarding requires email confirmation to be disabled, '
            'or must resume after the user confirms their email.';
      }

      String? logoUrl;
      if (_pickedFile != null && _previewBytes != null) {
        try {
          logoUrl = await repo.uploadOrganizationLogo(
              _previewBytes!, _pickedFile!.name);
        } catch (e) {
          debugPrint('Logo upload failed: $e');
        }
      }

      // 2. Create Organization
      final orgResponse = await SupabaseConfig.client
          .from('omtbl_organizations')
          .insert({
            'name': orgName,
            'logo_url': logoUrl,
            'business_type_id': _selectedBusinessTypeId,
            'is_gl': _isGL,
            'is_sales': _isSales,
            'is_inventory': _isInventory,
            'is_hr': _isHR,
            'is_settings': _isSettings,
            'auth_user_id': authResponse.user!.id,
          })
          .select()
          .single();

      final orgId = orgResponse['id'];

      // 3. Link this user to the new organization — BEFORE any tenant-scoped
      //    insert.
      //
      //    omtbl_stores enforces WITH CHECK (organization_id = current_org_id()),
      //    and current_org_id() resolves organization_id from the caller's
      //    omtbl_users row. Until that row exists and carries the new org id,
      //    current_org_id() returns NULL, `organization_id = NULL` evaluates to
      //    NULL rather than true, and the store insert is rejected by RLS.
      //
      //    This was previously an UPDATE that ran AFTER the store insert. Where
      //    no omtbl_users row exists yet it matched zero rows, returned 200 OK,
      //    and left current_org_id() NULL permanently — so the owner could never
      //    read back their own organization either.
      //
      //    Read-then-write rather than upsert: omtbl_users has no unique
      //    constraint on auth_id, so an onConflict target would raise.
      final authUid = authResponse.user!.id;
      final existingUser = await SupabaseConfig.client
          .from('omtbl_users')
          .select('id')
          .eq('auth_id', authUid)
          .maybeSingle();

      if (existingUser == null) {
        await SupabaseConfig.client.from('omtbl_users').insert({
          'auth_id': authUid,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'organization_id': orgId,
          'role': 'owner',
        });
      } else {
        await SupabaseConfig.client.from('omtbl_users').update({
          'organization_id': orgId,
          'role': 'owner',
        }).eq('auth_id', authUid);
      }

      // 4. Create Store
      final locationString = '$address, $city, $country';
      final storeResponse = await SupabaseConfig.client.from('omtbl_stores').insert({
        'organization_id': orgId,
        'name': storeName,
        'location': locationString,
        'contact_person': contact,
        'store_city': city,
        'store_country': country,
        'store_postal_code': postal,
        'store_default_currency': currency,
      }).select('id').single();

      final storeId = storeResponse['id'];

      // 5. Create the Financial Session. Deliberately NOT wrapped in a
      //    try/catch that swallows the error: a registration that produces
      //    an org + store but no financial session is not a successful
      //    registration (see success criteria), so a failure here must
      //    surface via the outer catch and block navigation to the next step.
      //    Uses `repo` (captured before signUp) rather than a fresh
      //    `ref.read` — see the comment above `repo`'s declaration.
      await repo.createFinancialSession(
            organizationId: orgId as int,
            syear: fyPeriod.syear,
            startDate: fyPeriod.startDate,
            endDate: fyPeriod.endDate,
          );

      // 6. Force reload permissions to reflect the new role/org immediately.
      //    Best-effort: the registration itself already succeeded by this
      //    point (org + store + financial session all created), so a
      //    failure here must not be reported as a failed registration —
      //    the next screen/login reload will pick permissions up anyway.
      try {
        await authNotifier.loadDynamicPermissions();
      } catch (e) {
        debugPrint('loadDynamicPermissions after registration failed: $e');
      }

      // Send Module Configuration Email with Deep Link
      try {
        final link = 'https://ordermate-v619.vercel.app/module-access?orzid=$orgId';
        final businessTypeName = ref.read(businessPartnerProvider).businessTypes.firstWhere(
            (t) => t['id'] == _selectedBusinessTypeId,
            orElse: () => {'business_type': 'Unknown'})['business_type'];
            
        EmailService().sendModuleConfigurationEmail(
          recipientEmail: 'maslamhussaini@gmail.com',
          orgName: orgName,
          businessType: businessTypeName ?? 'Unknown',
          moduleConfigUrl: link,
        );
      } catch (e) {
        debugPrint('Email sending failed: $e');
      }

      debugPrint(
        '[DIAG][registerAndCreate] reached pre-navigation check, '
        'mounted=$mounted, orgId=$orgId',
      );

      router.push('/onboarding/team', extra: {
        'orgId': orgId,
        'storeId': storeId,
        'email': email,
        'fySyear': fyPeriod.syear,
      });

      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/team',
        orgId: orgId,
        storeId: storeId,
        email: email,
        fySyear: fyPeriod.syear,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Organization Setup',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.loginGradientStart, AppColors.loginGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const StepIndicator(
                currentStep: 1,
                totalSteps: 6,
                stepLabels: [
                  'Account',
                  'Organization',
                  'Branch',
                  'Team',
                  'Verify',
                  'Config'
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: _previewBytes != null
                                      ? ClipOval(
                                          child: Image.memory(_previewBytes!,
                                              fit: BoxFit.cover))
                                      : const Icon(Icons.add_a_photo,
                                          size: 30, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Organization Logo',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildLabel('Business Information'),
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller: _orgNameController,
                            hint: 'Organization Name',
                            icon: Icons.business),
                        const SizedBox(height: 12),
                        // Business Type Dropdown
                        Consumer(
                          builder: (context, ref, child) {
                            final bpState = ref.watch(businessPartnerProvider);
                            final businessTypes = bpState.businessTypes;
 
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1.5),
                              ),
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedBusinessTypeId,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.category,
                                      color: AppColors.loginGradientStart),
                                  border: InputBorder.none,
                                  hintText: 'Select Business Type',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                items: businessTypes.map((type) {
                                  return DropdownMenuItem<int>(
                                    value: type['id'] as int,
                                    child: Text(
                                        type['business_type']?.toString() ??
                                            'Unknown'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedBusinessTypeId = val;
                                  });
                                },
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        const SizedBox(height: 16),
                        Theme(
                          data: Theme.of(context).copyWith(
                            switchTheme: SwitchThemeData(
                              trackColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? Colors.white
                                          : Colors.white24),
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Multiple Branches / Stores',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Enable if you have more than one location',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            value: _hasMultipleBranch,
                            activeThumbColor: Colors.white,
                            onChanged: (v) =>
                                setState(() => _hasMultipleBranch = v),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 8),
                        _buildLabel('Financial Year'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.grey.shade300, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RadioListTile<FinancialYearMode>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: FinancialYearMode.calendarYear,
                                groupValue: _fyMode,
                                title: Text(
                                    'Calendar Year (Jan 1 - Dec 31, ${DateTime.now().year})'),
                                onChanged: (v) => setState(() => _fyMode = v!),
                              ),
                              RadioListTile<FinancialYearMode>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: FinancialYearMode.julyToJune,
                                groupValue: _fyMode,
                                title: const Text('July 1 - June 30'),
                                onChanged: (v) => setState(() => _fyMode = v!),
                              ),
                              RadioListTile<FinancialYearMode>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: FinancialYearMode.fiscalCustom,
                                groupValue: _fyMode,
                                title: const Text('Fiscal / Custom'),
                                onChanged: (v) => setState(() => _fyMode = v!),
                              ),
                              if (_fyMode == FinancialYearMode.fiscalCustom) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _pickFyDate(isStart: true),
                                        child: Text(_fyCustomStart == null
                                            ? 'Start Date'
                                            : DateFormat('dd MMM yyyy')
                                                .format(_fyCustomStart!)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _pickFyDate(isStart: false),
                                        child: Text(_fyCustomEnd == null
                                            ? 'End Date'
                                            : DateFormat('dd MMM yyyy')
                                                .format(_fyCustomEnd!)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        _buildLabel('Modules'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Sales'),
                                subtitle: const Text(
                                    'Orders, invoices, customers'),
                                value: _isSales,
                                onChanged: (v) =>
                                    setState(() => _isSales = v ?? false),
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Inventory'),
                                subtitle: const Text(
                                    'Products, stock, vendors'),
                                value: _isInventory,
                                onChanged: (v) =>
                                    setState(() => _isInventory = v ?? false),
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Accounting'),
                                subtitle: const Text(
                                    'Chart of accounts, ledger, GL'),
                                value: _isGL,
                                onChanged: (v) =>
                                    setState(() => _isGL = v ?? false),
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('HR / Employees'),
                                subtitle: const Text(
                                    'Employee & department records'),
                                value: _isHR,
                                onChanged: (v) =>
                                    setState(() => _isHR = v ?? false),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        if (!_hasMultipleBranch) ...[
                          _buildLabel('Store Details (Main Branch)'),
                          const SizedBox(height: 16),
                          _buildTextField(
                              controller: _storeNameController,
                              hint: 'Store Name (e.g. Main Branch)',
                              icon: Icons.store),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _addressController,
                              hint: 'Street Address',
                              icon: Icons.location_on),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                      controller: _cityController,
                                      hint: 'City',
                                      icon: Icons.location_city)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildTextField(
                                      controller: _postalCodeController,
                                      hint: 'Postal Code',
                                      icon: Icons.pin_drop)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                              controller: _countryController,
                              hint: 'Country',
                              icon: Icons.public),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                      controller: _currencyController,
                                      hint: 'Default Currency (e.g. PKR)',
                                      icon: Icons.money)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildTextField(
                                      controller: _contactPersonController,
                                      hint: 'Contact Person',
                                      icon: Icons.person_outline)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white))
                            : ElevatedButton(
                                onPressed: _onNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.loginGradientStart,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


 
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        validator:
            validator ?? (val) => val?.isEmpty ?? false ? 'Required' : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.loginGradientStart),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}
