import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = SupabaseConfig.client.auth.currentUser;
    _emailController.text = user?.email ?? '';
  }

  Future<bool> _verifyOldPassword() async {
    try {
      // Supabase doesn't have a "verify password" without logging in or updating.
      // But since we are likely already logged in (via recovery or session),
      // we can try to re-authenticate or just rely on the user knowing it.
      // However, if the user requested it, they might want us to check it.

      // OPTION A: Try to sign in with email and old password to verify.
      final email = _emailController.text.trim();
      final oldPassword = _oldPasswordController.text.trim();

      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: oldPassword,
      );

      return response.user != null;
    } catch (e) {
      debugPrint('Old password verification failed: $e');
      return false;
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verify Old Password if provided (Manual check)
      if (_oldPasswordController.text.isNotEmpty) {
        final isValid = await _verifyOldPassword();
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Current password is incorrect'),
                  backgroundColor: Colors.red),
            );
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      // 2. Update Password in Supabase
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (context.mounted) {
        // 3. Clear recovery status and logout to force fresh login with new password
        ref.read(authProvider.notifier).clearRecoveryStatus();
        await SupabaseConfig.client.auth.signOut();
        ref.read(authProvider.notifier).logout();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Password updated successfully! Please log in with your new password.'),
            backgroundColor: Colors.green,
          ),
        );

        // 4. Redirect to Login Screen
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
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

  final _resetScrollController = ScrollController();

  @override
  void dispose() {
    _emailController.dispose();
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resetScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Setup')),
      body: Scrollbar(
        controller: _resetScrollController,
        child: Center(
          child: SingleChildScrollView(
            controller: _resetScrollController,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Credential Setup',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please update the default password to secure your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // Email Field (Disabled)
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Old Password (Default)',
                        prefixIcon: Icon(Icons.lock_clock),
                        border: OutlineInputBorder(),
                        hintText: 'Welcome@123',
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        if (val == _oldPasswordController.text) {
                          return 'New password must be different';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _updatePassword,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update & Continue'),
                      ),
                  ],
                ),
              ),
            ),
          ), // SingleChildScrollView
        ), // Center
      ), // Scrollbar
    ); // Scaffold
  }
}
