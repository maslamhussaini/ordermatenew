// lib/features/auth/presentation/screens/login_screen.dart

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/utils/password_hasher.dart';
import 'package:ordermate/core/services/auth_service_biometrics.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ordermate/core/providers/session_provider.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/accounting/data/models/accounting_models.dart';
import 'package:intl/intl.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _checkBiometric();
  }

  Future<void> _checkBiometricAvailability() async {
    final auth = ref.read(authServiceProvider);
    final enabled = await auth.isBiometricEnabled();
    final available = await auth.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = enabled && available;
      });
    }
  }

  void _showBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.loginGradientStart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset('assets/icons/app_icon.png'),
              ),
              const SizedBox(height: 16),
              // Title
              const Text(
                'ORDER MATE',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
              const SizedBox(height: 30),

              // Fingerprint Button
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _checkBiometric(manualTrigger: true);
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.loginGradientStart, width: 2),
                  ),
                  child: const Icon(Icons.fingerprint,
                      size: 64, color: AppColors.loginGradientStart),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)?.get('tap_to_authenticate') ??
                  'Tap to Authenticate'),

              const SizedBox(height: 30),

              // Cancel Button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    AppLocalizations.of(context)?.get('cancel') ?? 'Cancel',
                    style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkBiometric({bool manualTrigger = false}) async {
    // Small delay to ensure UI is ready
    if (!manualTrigger) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final authService = ref.read(authServiceProvider);

    // If auto-trigger (init state), check if enabled first
    if (!manualTrigger) {
      final isEnabled = await authService.isBiometricEnabled();
      if (!isEnabled) return;
    }

    // Authenticate
    final isAuthenticated = await authService.authenticateWithBiometrics();

    if (isAuthenticated && mounted) {
      // Find last user credentials
      try {
        final db = await DatabaseHelper.instance.database;
        final result = await db.query('local_users',
            limit: 1); // Get any user for now or last one

        if (!mounted) return;

        if (result.isNotEmpty) {
          final user = result.first;
          _emailController.text = user['email'] as String;

          // SECURITY (C-3): we no longer store the plaintext password, so the
          // old "replay the saved password through _signIn" flow is gone.
          // Biometric verification has already proven identity, so restore the
          // cached session directly.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric verified. Logging in...')),
          );

          SupabaseConfig.isOfflineLoggedIn = true;
          SupabaseConfig.offlineUserId = user['id'] as String?;

          // Preserve login-location capture on the biometric path.
          _captureLoginLocationInBackground();

          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          _fetchOrganizations();
        } else {
          if (manualTrigger) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No saved user found. Please login closely first to enable.')),
            );
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  /// Captures the rep's login coordinates into [sessionProvider] without
  /// blocking the UI. These become `login_latitude` / `login_longitude` on
  /// every order booked in this session.
  ///
  /// Extracted so the biometric path captures location too. Before the C-3
  /// change, biometric unlock replayed the stored password through [_signIn]
  /// and picked this up via the online-login branch; it no longer does.
  /// (DashboardScreen._checkSessionLocation is a second safety net.)
  void _captureLoginLocationInBackground() {
    unawaited((() async {
      try {
        final sessionNotifier = ref.read(sessionProvider.notifier);
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          sessionNotifier.setLoginLocation(
              position.latitude, position.longitude);
          debugPrint(
              'Login Location captured in background: ${position.latitude}, ${position.longitude}');
        }
      } catch (e) {
        debugPrint('Background location capture failed: $e');
      }
    })());
  }

  Future<void> _signIn({bool fromBiometric = false}) async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // SECURITY (C-0): a hardcoded credential bypass used to sit here. It
    // authenticated without contacting Supabase, injected a fake user,
    // organization and store into local SQLite, and shipped in release
    // builds. Removed. Do not reintroduce a bypass here or anywhere else.

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter email and password')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Check Connectivity
      final connectivityResult = await ConnectivityHelper.check();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        await _attemptOfflineLogin(email, password);
      } else {
        await _attemptOnlineLogin(email, password);
      }

      // If we got here, login was successful (offline or online)
      if (mounted && !fromBiometric) {
        // Ask to enable biometric if applicable
        await _suggestBiometric();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '');
        final isNotCached = message.toLowerCase().contains('not cached');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: isNotCached
                ? SnackBarAction(
                    label: 'Force Online',
                    textColor: Colors.white,
                    onPressed: () {
                      _attemptOnlineLogin(email, password);
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _suggestBiometric() async {
    final authService = ref.read(authServiceProvider);
    final isAvailable = await authService.isBiometricAvailable();
    final isEnabled = await authService.isBiometricEnabled();

    debugPrint(
        'Biometric Suggestion Check: Available=$isAvailable, Enabled=$isEnabled');

    if (isAvailable && !isEnabled) {
      if (!mounted) return;

      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Biometric Login?'),
          content: const Text(
              'Do you want to use your fingerprint/face to login next time?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes')),
          ],
        ),
      );

      if (shouldEnable == true) {
        await authService.setBiometricEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric login enabled!')),
          );
        }
      }
    }
  }

  Future<void> _attemptOfflineLogin(String email, String password) async {
    final db = await DatabaseHelper.instance.database;

    // Check if user exists at all (to differentiate errors)
    final userCheck = await db.query(
      'local_users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (userCheck.isEmpty) {
      throw Exception('User not cached locally. Please login online first.');
    }

    // SECURITY (C-3): verify against the stored PBKDF2 hash. The previous
    // implementation compared the plaintext value directly in the SQL
    // WHERE clause.
    final row = userCheck.first;
    final storedHash = row['password_hash'] as String?;

    if (!PasswordHasher.verify(password, storedHash)) {
      throw Exception('Invalid offline credentials.');
    }

    // Real cached Supabase user id — never a fabricated one (C-0b).
    final cachedUserId = row['id'] as String?;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline Login Successful'),
          backgroundColor: Colors.orange,
        ),
      );
      SupabaseConfig.isOfflineLoggedIn = true;
      SupabaseConfig.offlineUserId = cachedUserId;

      _captureLoginLocationInBackground();

      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
      _fetchOrganizations();
    }
  }

  Future<void> _attemptOnlineLogin(String email, String password) async {
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Cache credentials for offline use
      if (response.user != null) {
        final userId = response.user!.id;
        final userEmail = response.user!.email ?? '';

        // ---------------------------------------------------------
        // ASYNC TASKS (Non-Blocking) - Run these in background to speed up login button
        // ---------------------------------------------------------

        // 1. User Self-Healing & Local Cache
        unawaited((() async {
          try {
            final userCheck = await SupabaseConfig.client
                .from('omtbl_users')
                .select('id, auth_id, full_name, role')
                .or('id.eq.$userId,auth_id.eq.$userId,email.eq.$userEmail')
                .maybeSingle();

            String fullName =
                response.user!.userMetadata?['full_name'] ?? 'Unknown User';
            String role = 'admin';

            if (userCheck != null) {
              fullName = userCheck['full_name'] ?? fullName;
              role = userCheck['role'] ?? role;

              if (userCheck['id'] != userId || userCheck['auth_id'] != userId) {
                debugPrint(
                    'LoginScreen: Linking existing user $userEmail to Auth ID $userId');
                await SupabaseConfig.client.from('omtbl_users').update({
                  'auth_id': userId,
                  'is_active': true,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('email', userEmail);
              }
            } else {
              debugPrint(
                  'LoginScreen: Creating new profile record for $userEmail');
              await SupabaseConfig.client.from('omtbl_users').insert({
                'id': userId,
                'auth_id': userId,
                'email': userEmail,
                'full_name': fullName,
                'role': role,
                'is_active': true,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
            }

            final db = await DatabaseHelper.instance.database;
            // SECURITY (C-3): cache a salted PBKDF2 hash for offline unlock,
            // never the plaintext password.
            await db.insert(
              'local_users',
              {
                'email': email,
                'password_hash': PasswordHasher.hash(password),
                'id': userId,
                'full_name': fullName,
                'table_prefix':
                    response.user!.userMetadata?['table_prefix'] ?? 'omtbl_',
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            debugPrint('Background user sync failed: $e');
          }
        })());

        // 2. BACKGROUND LOCATION CAPTURE
        _captureLoginLocationInBackground();

        // ---------------------------------------------------------
        // CRITICAL UI PATH (Blocking)
        // ---------------------------------------------------------
        if (mounted) {
          await _fetchOrganizations();

          if (!mounted) return;

          if (_selectedOrganization != null) {
            try {
              ref.read(syncServiceProvider).syncAll();
            } catch (e) {
              debugPrint('Initial Sync failed: $e');
            }
          }

          if (_organizations.isEmpty) {
            context.goNamed('organization-create');
          } else {
            setState(() {
              _isAuthenticated = true;
              _isLoading = false;
            });
          }
        }
      }
    } on AuthException catch (e) {
      if (e.message.contains('SocketException') ||
          e.message.contains('host lookup')) {
        debugPrint(
            'AuthException indicates network issue, falling back to offline login');
        await _attemptOfflineLogin(email, password);
        return;
      }
      throw Exception(e.message);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('SocketException') ||
          errorString.contains('ClientException') ||
          errorString.contains('Failed host lookup') ||
          errorString.contains('Network request failed')) {
        debugPrint(
            'Network error detected during online login: $e. Falling back to offline login.');
        await _attemptOfflineLogin(email, password);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your email to reset password'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final redirectTo = SupabaseConfig.frontendUrl;

      debugPrint(
          'SENDING PASSWORD RESET TO: $email with REDIRECT: "$redirectTo"');

      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email'),
          ),
        );
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
    }
  }

  // State for Context Selection
  bool _isAuthenticated = false;
  List<Organization> _organizations = [];
  Organization? _selectedOrganization;
  List<Store> _stores = [];
  Store? _selectedStore;
  List<FinancialSession> _financialSessions = [];
  FinancialSession? _selectedSession;

  Future<void> _fetchOrganizations() async {
    try {
      // Using generic client or repository? We have OrganizationRepositoryImpl but strictly need an instance.
      // Easiest is to use the provider if we were in a ConsumerWidget, but we are in State.
      // We can create an instance of Repositories here or use the newly authenticated client.
      final repo = OrganizationRepositoryImpl();
      final orgs = await repo.getOrganizations();

      if (!mounted) return;
      setState(() {
        _organizations = orgs;
        if (orgs.isNotEmpty) {
          _selectedOrganization = orgs.first;
          _fetchStores(orgs.first.id);
          _fetchFinancialSessions(orgs.first.id);
        }
      });
    } catch (e) {
      debugPrint('Error fetching orgs: $e');
    }
  }

  Future<void> _fetchStores(int orgId) async {
    try {
      final repo = OrganizationRepositoryImpl();
      final stores = await repo.getStores(orgId);

      if (!mounted) return;
      setState(() {
        _stores = stores;
        if (stores.isNotEmpty) {
          _selectedStore = stores.first;
        } else {
          _selectedStore = null;
        }
      });
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchFinancialSessions(int orgId) async {
    try {
      final localRepo = LocalAccountingRepository();
      final repo = AccountingRepositoryImpl(localRepo);
      var sessions = await repo.getFinancialSessions(organizationId: orgId);

      if (sessions.isEmpty) {
        final currentYear = DateTime.now().year;
        final session = FinancialSession(
          sYear: currentYear,
          startDate: DateTime(currentYear, 1, 1),
          endDate: DateTime(currentYear, 12, 31),
          narration: 'Default Year',
          inUse: true,
          isActive: true,
          isClosed: false,
          organizationId: orgId,
        );
        await localRepo.saveFinancialSession(FinancialSessionModel(
          sYear: session.sYear,
          startDate: session.startDate,
          endDate: session.endDate,
          narration: session.narration,
          inUse: session.inUse,
          isActive: session.isActive,
          isClosed: false,
          organizationId: session.organizationId,
        ));
        sessions = [session];
      }

      if (!mounted) return;
      setState(() {
        _financialSessions = sessions;
        if (sessions.isNotEmpty) {
          _selectedSession =
              sessions.firstWhere((s) => s.inUse, orElse: () => sessions.first);
        } else {
          _selectedSession = null;
        }
      });
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
    }
  }

  Future<void> _continueToDashboard() async {
    if (_selectedOrganization != null) {
      ref
          .read(organizationProvider.notifier)
          .selectOrganization(_selectedOrganization!);
      if (_selectedStore != null) {
        ref.read(organizationProvider.notifier).selectStore(_selectedStore!);
      }
      if (_selectedSession != null) {
        ref
            .read(organizationProvider.notifier)
            .selectFinancialYear(_selectedSession!.sYear);
      }
    }

    // Sync Auth Provider (Triggers Router Redirect to /dashboard)
    final fullName =
        SupabaseConfig.client.auth.currentUser?.userMetadata?['full_name'] ??
            'User';
    ref.read(authProvider.notifier).login(UserRole.admin, fullName: fullName);
  }

  final _loginScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // If authenticated, show Context Selection instead of Login Form
    if (_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Scrollbar(
                controller: _loginScrollController,
                child: SingleChildScrollView(
                  controller: _loginScrollController,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.business,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : AppColors.loginGradientStart),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.get('select_workspace') ??
                            'Select Workspace',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),

                      // Organization Dropdown
                      DropdownButtonFormField<dynamic>(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)
                                  ?.get('organization') ??
                              'Organization',
                          prefixIcon: const Icon(Icons.domain),
                        ),
                        initialValue: _selectedOrganization,
                        items: _organizations.map((org) {
                          return DropdownMenuItem(
                            value: org,
                            child: Text(org.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedOrganization = val;
                          });
                          if (val != null) {
                            _fetchStores(val.id);
                            _fetchFinancialSessions(val.id);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Store Dropdown
                      DropdownButtonFormField<dynamic>(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)
                                  ?.get('store_branch') ??
                              'Store / Branch',
                          prefixIcon: const Icon(Icons.store),
                        ),
                        initialValue: _selectedStore,
                        items: _stores.map((store) {
                          return DropdownMenuItem(
                            value: store,
                            child: Text(store.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStore = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Financial Year Dropdown
                      DropdownButtonFormField<FinancialSession>(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)
                                  ?.get('financial_year') ??
                              'Financial Year',
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        initialValue: _selectedSession,
                        items: _financialSessions.map((session) {
                          return DropdownMenuItem(
                            value: session,
                            child: Text(
                                '${session.sYear} (${DateFormat('MM/yy').format(session.startDate)} - ${DateFormat('MM/yy').format(session.endDate)})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSession = val;
                          });
                        },
                      ),

                      const SizedBox(height: 32),
                      ElevatedButton(
                        key: const Key('continue_button'),
                        onPressed: _continueToDashboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loginGradientStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(AppLocalizations.of(context)
                                ?.get('continue_to_dashboard') ??
                            'Continue to Dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full height gradient background that covers top half
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.loginGradientStart,
                    AppColors.loginGradientEnd
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                )),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ORDER MATE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Login Card extended
          Align(
            alignment: Alignment.bottomCenter,
            child: Scrollbar(
              controller: _loginScrollController,
              child: SingleChildScrollView(
                controller: _loginScrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height *
                                0.35), // push down
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color ??
                                Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppLocalizations.of(context)?.get('sign_in') ??
                                    'Sign In',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E3C57),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)
                                        ?.get('welcome_back') ??
                                    'Welcome back! Please enter your details.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey,
                                    ),
                              ),
                              const SizedBox(height: 32),

                              // Email
                              TextFormField(
                                key: const Key('email_field'),
                                controller: _emailController,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                          ?.get('email') ??
                                      'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                key: const Key('password_field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)
                                          ?.get('password') ??
                                      'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  child: Text(AppLocalizations.of(context)
                                          ?.get('forgot_password') ??
                                      'Forgot Password?'),
                                ),
                              ),

                              const SizedBox(height: 24),

                              ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.loginGradientStart,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                key: const Key('login_button'),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        AppLocalizations.of(context)
                                                ?.get('sign_in')
                                                .toUpperCase() ??
                                            'SIGN IN',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                              ),

                              // Custom Biometric Button
                              if (_canCheckBiometrics) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _showBiometricDialog,
                                  icon: const Icon(Icons.fingerprint,
                                      color: AppColors.loginGradientStart),
                                  label: Text(
                                      AppLocalizations.of(context)
                                              ?.get('login_with_biometrics') ??
                                          'Login with Biometrics',
                                      style: const TextStyle(
                                          color: AppColors.loginGradientStart)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: const BorderSide(
                                        color: AppColors.loginGradientStart),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                            ?.get('no_account') ??
                                        "Don't have an account?",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => context.push('/register'),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: Text(
                                        AppLocalizations.of(context)
                                                ?.get('sign_up') ??
                                            'Sign Up',
                                        style: const TextStyle(
                                          color: AppColors.loginGradientStart,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _loginScrollController.dispose();
    super.dispose();
  }
}
