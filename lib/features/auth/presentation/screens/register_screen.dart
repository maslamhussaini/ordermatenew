import 'dart:async';

import 'package:ordermate/core/network/supabase_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _mobileNumberWithCode = '';

  final bool _isLoading = false;
  
  final ScrollController _registerScrollController = ScrollController();
  
  Timer? _emailDebounce;
  String? _emailExistsError;
  bool _isCheckingEmail = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    if (_emailDebounce?.isActive ?? false) _emailDebounce!.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 800), () {
      _checkEmailAvailability(_emailController.text.trim());
    });
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailExistsError = null);
      return; 
    }
    
    setState(() {
      _isCheckingEmail = true;
      _emailExistsError = null;
    });

    try {
      final exists = await SupabaseConfig.client
          .rpc('check_if_email_exists', params: {'email_check': email});
      
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          if (exists == true) {
            _emailExistsError = 'Email already registered';
          }
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isCheckingEmail = false);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await ConnectivityHelper.check();
    if (result.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Offline Mode: Registration requires an internet connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _scrollToFirstError() {
    // Basic implementation: scroll to top if form invalid
    _registerScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToEmailField() {
    // Approximate position of email field
    _registerScrollController.animateTo(
      350,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }


  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _registerScrollController.dispose();
    _emailDebounce?.cancel();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_emailDebounce?.isActive ?? false) {
      _emailDebounce!.cancel();
      await _checkEmailAvailability(_emailController.text.trim());
    }
    
    if (_isCheckingEmail) {
      if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking email availability...')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }
    
    if (_emailExistsError != null) {
      _scrollToEmailField();
      return;
    }

    if (!mounted) return;
    context.push('/onboarding/organization', extra: {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'phone': _mobileNumberWithCode,
    });
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
          'New Account',
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
                currentStep: 0,
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
                child: Scrollbar(
                  controller: _registerScrollController,
                  child: SingleChildScrollView(
                    controller: _registerScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create Account',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildLabel('Enter the Full Name'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _fullNameController,
                                  hint: 'Full Name',
                                  icon: Icons.person,
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Enter Mobile Number'),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                                        ),
                                        child: IntlPhoneField(
                                          controller: _mobileController,
                                          decoration: const InputDecoration(
                                            hintText: 'Mobile Number',
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                            counterText: '',
                                          ),
                                          initialCountryCode: 'PK',
                                          dropdownIconPosition: IconPosition.trailing,
                                          flagsButtonPadding: const EdgeInsets.only(left: 8),
                                          disableLengthCheck: true,
                                          onChanged: (phone) {
                                            _mobileNumberWithCode = phone.completeNumber;
                                          },
                                          style: const TextStyle(fontSize: 16, color: Colors.black),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Enter your Email'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _emailController,
                                  hint: 'example@email.com',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  isLoading: _isCheckingEmail,
                                  errorText: _emailExistsError,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Required';
                                    if (!val.contains('@')) return 'Invalid Email';
                                    if (_emailExistsError != null) return _emailExistsError;
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Create New Password'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 16),
                                _buildLabel('Confirm Password'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  hint: 'Confirm Password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  validator: (val) {
                                    if (val != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 40),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading || _isCheckingEmail ? null : _onNext,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.loginGradientStart,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 5,
                                    ),
                                    child: _isLoading 
                                        ? const SizedBox(
                                            height: 20, 
                                            width: 20, 
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.loginGradientStart)
                                          )
                                        : const Text(
                                            'Next',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Already have an account?",
                                      style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => context.go('/login'),
                                      child: const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
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
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isLoading = false,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator ?? (val) => val?.isEmpty ?? false ? 'Required' : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.loginGradientStart),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ) 
              : null,
          errorText: errorText,
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}
