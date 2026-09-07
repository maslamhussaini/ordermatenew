import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/email_service.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:pinput/pinput.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> onboardingData;

  const EmailVerificationScreen({super.key, required this.onboardingData});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isSending = false;
  String? _generatedOtp;
  final TextEditingController _otpController = TextEditingController();
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.onboardingData);
    _sendOtp();
  }

  Future<void> _hydrateOnboardingData() async {
    final resumeData = await OnboardingStateService.resumeData();
    if (resumeData != null) {
      _data.putIfAbsent('email', () => resumeData['email']);
      _data.putIfAbsent('orgId', () => resumeData['orgId']);
      _data.putIfAbsent('storeId', () => resumeData['storeId']);
      _data.putIfAbsent('fySyear', () => resumeData['fySyear']);
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _isSending = true);
    await _hydrateOnboardingData();

    // Get email from onboarding data.
    // It might be in 'userData' which was passed from RegisterScreen
    final email = _data['email'] ?? _data['userData']?['email'];

    if (email == null) {
      debugPrint(
          'Error: Email not found in onboarding data: $_data');
      setState(() => _isSending = false);
      return;
    }

    _generatedOtp = (1000 + Random().nextInt(9000)).toString();

    try {
      bool sent = await EmailService().sendOtpEmail(email, _generatedOtp!);
      if (mounted) {
        if (sent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Verification code sent to your email'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to send verification email'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyAndFinish() async {
    if (_otpController.text != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid verification code'),
            backgroundColor: Colors.red),
      );
      return;
    }

    await _hydrateOnboardingData();

    setState(() => _isLoading = true);

    try {
      final orgId = _data['orgId'];
      final storeId = _data['storeId'];
      final teamMembers = _data['teamMembers'] as List<dynamic>?;
      final fySyear = _data['fySyear'] as int?;

      // 1. Save team members if any
      if (teamMembers != null) {
        for (var member in teamMembers) {
          await SupabaseConfig.client.from('omtbl_businesspartners').insert({
            'name': member['name'],
            'email': member['email']!.isEmpty ? null : member['email'],
            'phone': member['phone']!,
            'is_employee': 1,
            'organization_id': orgId,
            'store_id': storeId,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 2. Persist workspace selection so post-onboarding refreshes do not
      //    fall back to /workspace-selection.
      if (orgId != null && storeId != null && fySyear != null && mounted) {
        final repo = ref.read(organizationRepositoryProvider);
        final org = await repo.getOrganization(orgId);
        final stores = await repo.getStores(orgId);
        Store? matchedStore;
        for (final s in stores) {
          if (s.id == storeId) {
            matchedStore = s;
            break;
          }
        }

        if (org != null && matchedStore != null) {
          await ref.read(organizationProvider.notifier).setWorkspace(
                organization: org,
                store: matchedStore,
                financialYear: fySyear,
              );
        }
      }

      // 3. Clear onboarding state or whatever is needed
      // (Optional: perform any final verification flags in DB)

      if (mounted) {
        await OnboardingStateService.clear();
        context.go('/onboarding/configure/$orgId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
          fontSize: 22,
          color: AppColors.loginGradientStart,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
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
                currentStep: 4,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.mark_email_read_outlined,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Verify Email',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 4-digit code sent to\n${widget.onboardingData['email'] ?? widget.onboardingData['userData']?['email'] ?? 'your email'}',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      Center(
                        child: Pinput(
                          controller: _otpController,
                          length: 4,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: defaultPinTheme.copyWith(
                            decoration: defaultPinTheme.decoration!.copyWith(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          onCompleted: (pin) => _verifyAndFinish(),
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_isLoading)
                        const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white))
                      else
                        ElevatedButton(
                          onPressed: _verifyAndFinish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.loginGradientStart,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Verify & Complete',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _isSending ? null : _sendOtp,
                        child: Text(
                          _isSending ? 'Sending...' : 'Resend Code',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
