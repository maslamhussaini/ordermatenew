import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class StoreSetupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> orgData;

  const StoreSetupScreen({
    super.key,
    required this.userData,
    required this.orgData,
  });

  @override
  ConsumerState<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends ConsumerState<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _currencyController = TextEditingController();
  final _contactPersonController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _currencyController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Captured BEFORE any await, not read again later: the instant
    // auth.signUp() below succeeds, the router sees a logged-in user on
    // what it treats as a guest-only route and disposes this screen while
    // _create() is still mid-flight. Steps that call SupabaseConfig.client
    // directly (org/user/store inserts) don't care and complete fine; a
    // `ref.read(...)` called AFTER that point throws "Cannot use ref after
    // the widget was disposed" — which is exactly why organizations could
    // end up with a store but zero financial sessions (see
    // organization_setup_screen.dart's identical fix for the full
    // explanation). Grabbing the plain (non-widget-bound) repository
    // instance up front sidesteps the race entirely.
    final repo = ref.read(organizationRepositoryProvider);

    try {
      final email = widget.userData['email']!;
      final password = widget.userData['password']!;
      final fullName = widget.userData['fullName']!;
      final phone = widget.userData['phone']!;
      final orgName = widget.orgData['name']!;

      const redirectTo = 'ordermate://login-callback';

      if (SupabaseConfig.client.auth.currentSession != null) {
        await SupabaseConfig.client.auth.signOut();
      }

      // 1. Sign Up
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
      if (authResponse.session == null) {
        throw 'Account created, but no active session was returned. '
            'Self-serve onboarding requires email confirmation to be disabled, '
            'or must resume after the user confirms their email.';
      }

      String? logoUrl;
      final logoBytes = widget.orgData['logoBytes'] as Uint8List?;
      final logoName = widget.orgData['logoName'] as String?;

      if (logoBytes != null && logoName != null) {
        try {
          logoUrl = await repo.uploadOrganizationLogo(logoBytes, logoName);
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
            'business_type_id': widget.orgData['businessTypeId'],
            'is_gl': widget.orgData['isGL'] ?? true,
            'is_sales': widget.orgData['isSales'] ?? true,
            'is_inventory': widget.orgData['isInventory'] ?? true,
            'is_hr': widget.orgData['isHR'] ?? true,
            'is_settings': widget.orgData['isSettings'] ?? true,
            // Required by omtbl_organizations WITH CHECK:
            //   (id = current_org_id()) OR (auth_user_id = auth.uid())
            // On a first organization current_org_id() is NULL, so auth_user_id
            // is the only clause that can be satisfied. Omitting it made this
            // insert fail even for an authenticated user — the single-branch
            // path in organization_setup_screen.dart already set it.
            'auth_user_id': authResponse.user!.id,
          })
          .select()
          .single();

      final orgId = orgResponse['id'];

      // 3. Link this user to the new organization — BEFORE any tenant-scoped
      //    insert. omtbl_stores enforces
      //    WITH CHECK (organization_id = current_org_id()), and current_org_id()
      //    resolves organization_id from the caller's omtbl_users row. Until
      //    that row exists and carries the new org id, current_org_id() returns
      //    NULL and the store insert is rejected by RLS.
      //
      //    This was previously an UPDATE that ran AFTER the store insert; where
      //    no omtbl_users row exists it matched zero rows and returned 200 OK.
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
      final locationString =
          '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_countryController.text.trim()}';

      final storeResponse = await SupabaseConfig.client
          .from('omtbl_stores')
          .insert({
            'organization_id': orgId,
            'name': _nameController.text.trim(),
            'location': locationString,
            'contact_person': _contactPersonController.text.trim(),
            'store_city': _cityController.text.trim(),
            'store_country': _countryController.text.trim(),
            'store_postal_code': _postalCodeController.text.trim(),
            'store_default_currency': _currencyController.text.trim(),
            'is_active': true,
          })
          .select()
          .single();

      final storeId = storeResponse['id'];

      // 5. Create the Financial Session using the Fiscal Year resolved on
      //    the previous (Organization) step. Not wrapped to swallow errors:
      //    a registration missing its financial session is not successful.
      final fySyear = widget.orgData['fySyear'] as int?;
      final fyStartDateStr = widget.orgData['fyStartDate'] as String?;
      final fyEndDateStr = widget.orgData['fyEndDate'] as String?;
      if (fySyear == null || fyStartDateStr == null || fyEndDateStr == null) {
        throw 'Missing Financial Year selection from the previous step. '
            'Please go back and select a Financial Year.';
      }
      await repo.createFinancialSession(
            organizationId: orgId as int,
            syear: fySyear,
            startDate: DateTime.parse(fyStartDateStr),
            endDate: DateTime.parse(fyEndDateStr),
          );

      if (mounted) {
        context.push('/onboarding/team', extra: {
          'orgId': orgId,
          'storeId': storeId,
          'email': email,
          'fySyear': fySyear,
        });

        await OnboardingStateService.save(
          inProgress: true,
          route: '/onboarding/team',
          orgId: orgId,
          storeId: storeId,
          email: email,
          fySyear: fySyear,
        );
      }
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
          'Branch Setup',
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
                currentStep: 2,
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
                        const Center(
                          child: Icon(Icons.store_mall_directory_outlined,
                              size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Branch Setup',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure your first location',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildLabel('Store Information'),
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller: _nameController,
                            hint: 'Store Name (e.g. Downtown Branch)',
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
                                    hint: 'Currency (e.g. PKR)',
                                    icon: Icons.money)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    controller: _contactPersonController,
                                    hint: 'Contact Person',
                                    icon: Icons.person_outline)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white))
                            : ElevatedButton(
                                onPressed: _create,
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
                        const SizedBox(height: 40),
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
