// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/database/database_helper.dart'
    as import_database_helper;
import 'package:ordermate/core/services/auth_service_biometrics.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/features/settings/presentation/screens/pdf_settings_screen.dart'; // Import
import 'package:ordermate/core/localization/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    final textScale = settings.textScaleFactor;

    final userProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(AppLocalizations.of(context)?.get('settings') ?? 'Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: ListView(
        children: [
          // Appearance Section
          _SectionHeader(
              title: AppLocalizations.of(context)?.get('appearance') ??
                  'Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(AppLocalizations.of(context)?.get('theme_mode') ??
                'Theme Mode'),
            subtitle: Text(_getThemeModeName(context, themeMode)),
            onTap: () {
              _showThemeDialog(context, ref, themeMode);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(
                AppLocalizations.of(context)?.get('font_size') ?? 'Font Size'),
            subtitle: Text(_getFontScaleName(context, textScale)),
            onTap: () {
              _showFontDialog(context, ref, textScale);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(AppLocalizations.of(context)?.get('theme_skin') ??
                'Theme Skin'),
            subtitle: Text(_getSkinName(context, settings.themeColor)),
            onTap: () {
              _showSkinDialog(context, ref, settings.themeColor);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text(AppLocalizations.of(context)?.get('pdf_settings') ??
                'Print PDF Settings'),
            subtitle: Text(
                AppLocalizations.of(context)?.get('pdf_settings_subtitle') ??
                    'Configure content & layout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const PdfSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: Text(AppLocalizations.of(context)?.get('font_family') ??
                'Font Family'),
            subtitle: Text(settings.fontFamily),
            onTap: () {
              _showFontFamilyDialog(context, ref, settings.fontFamily);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          const Divider(),

          // Preferences Section
          _SectionHeader(
              title: AppLocalizations.of(context)?.get('preferences') ??
                  'Preferences'),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(
                AppLocalizations.of(context)?.get('language') ?? 'Language'),
            subtitle: Text(_getLanguageName(settings.language)),
            onTap: () {
              _showLanguageDialog(context, ref, settings.language);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(AppLocalizations.of(context)?.get('landing_page') ??
                'Default Landing Page'),
            subtitle: Text(_getLandingPageName(context, settings.landingPage)),
            onTap: () {
              _showLandingPageDialog(context, ref, settings.landingPage);
            },
            trailing: const Icon(Icons.chevron_right),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(
                AppLocalizations.of(context)?.get('push_notifications') ??
                    'Push Notifications'),
            value: settings.notificationsEnabled,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).setNotificationsEnabled(val);
            },
          ),

          const Divider(),

          // Account Section
          _SectionHeader(
              title: AppLocalizations.of(context)?.get('account') ?? 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title:
                Text(AppLocalizations.of(context)?.get('profile') ?? 'Profile'),
            subtitle: Text(userProfile?.fullName ?? 'User'),
            onTap: () {
              // Navigate to Profile Edit if exists
            },
          ),
          FutureBuilder<bool>(
            future: ref.read(authServiceProvider).isBiometricAvailable(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(
                      AppLocalizations.of(context)?.get('biometric_login') ??
                          'Biometric Login'),
                  subtitle: Text(
                      AppLocalizations.of(context)?.get('biometric_subtitle') ??
                          'FaceID / TouchID'),
                  value: settings.biometricEnabled,
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .setBiometricEnabled(val);
                    if (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Biometric login enabled (Simulated)')),
                      );
                    }
                  },
                );
              }
              return const SizedBox.shrink(); // Hide if not available
            },
          ),

          const Divider(),

          // Data & Storage
          _SectionHeader(
              title: AppLocalizations.of(context)?.get('data_sync') ??
                  'Data & Sync'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_off),
            title: const Text('Simulated Offline Mode'),
            subtitle: const Text('Force app to behave as if offline'),
            value: settings.offlineMode,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).setOfflineMode(val);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(AppLocalizations.of(context)?.get('manual_sync') ??
                'Manual Sync'),
            subtitle: Text(
                AppLocalizations.of(context)?.get('manual_sync_subtitle') ??
                    'Force sync data with server'),
            onTap: () async {
              _showSyncingDialog(context);
              try {
                await ref.read(syncServiceProvider).syncAll();
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync Complete')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Sync Failed: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            trailing: FutureBuilder<DateTime?>(
              future: ref.read(syncServiceProvider).getLastSyncTime(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  // Simple formatter: '10:30 AM' or 'Dec 31'
                  final date = snapshot.data!;
                  return Text(
                    '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(AppLocalizations.of(context)?.get('clear_cache') ??
                'Clear Local Cache'),
            subtitle: Text(
                AppLocalizations.of(context)?.get('clear_cache_subtitle') ??
                    'Troubleshooting only'),
            onTap: () {
              _showClearCacheDialogWithRef(context, ref);
            },
          ),

          const Divider(),

          // System Section
          _SectionHeader(
              title: AppLocalizations.of(context)?.get('system') ?? 'System'),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: Text(AppLocalizations.of(context)?.get('printer_config') ??
                'Printer Configuration'),
            onTap: () {
              context.go('/settings/printer');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
                AppLocalizations.of(context)?.get('about_app') ?? 'About App'),
            subtitle: const Text('OrderMate v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'OrderMate',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Triangular Technologies',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(AppLocalizations.of(context)?.get('logout') ?? 'Logout',
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              try {
                // 1. Attempt Global Logout (Server + Local)
                await SupabaseConfig.client.auth.signOut();
              } catch (e) {
                debugPrint('Logout error: $e');
              } finally {
                // 2. Safety Check: If session persists locally, force kill it
                // 2. Always Force Local Signout to ensure cache is cleared
                // This is critical because sometimes 'signOut()' clears memory but fails network/storage,
                // leaving a ghost token. We unconditionally wipe local storage here.
                try {
                  debugPrint('Forcing local signout cleanup...');
                  await SupabaseConfig.client.auth
                      .signOut(scope: SignOutScope.local);
                } catch (e) {
                  // Ignore errors (e.g. "AuthSessionMissingException") since we are just cleaning up
                  debugPrint('Local signout cleanup warning: $e');
                }

                // 3. Navigate
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String lang) {
    switch (lang) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish (Español)';
      case 'fr':
        return 'French (Français)';
      default:
        return 'English';
    }
  }

  String _getLandingPageName(BuildContext context, String route) {
    if (route == '/dashboard') {
      return AppLocalizations.of(context)?.get('dashboard') ?? 'Dashboard';
    }
    if (route == '/orders') {
      return AppLocalizations.of(context)?.get('customer_list') ??
          'Order List'; // Wait, orders or customer list? List says Order List. It routes to /orders. AppDrawer says 'Orders'. Let's use 'orders'
    }
    // Actually /orders filters. Let's stick to what we have in AppLocalizations. 'orders' -> 'Orders'.
    if (route == '/orders') {
      return AppLocalizations.of(context)?.get('orders') ?? 'Order List';
    }
    if (route == '/orders/create') {
      return AppLocalizations.of(context)?.get('new_order') ??
          'New Order'; // Missing new_order key
    }
    return AppLocalizations.of(context)?.get('dashboard') ?? 'Dashboard';
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return AppLocalizations.of(context)?.get('system_default') ??
            'System Default';
      case ThemeMode.light:
        return AppLocalizations.of(context)?.get('light_mode') ?? 'Light Mode';
      case ThemeMode.dark:
        return AppLocalizations.of(context)?.get('dark_mode') ?? 'Dark Mode';
    }
  }

  String _getFontScaleName(BuildContext context, double scale) {
    if (scale <= 0.85) {
      return AppLocalizations.of(context)?.get('small') ?? 'Small';
    }
    if (scale >= 1.15) {
      return AppLocalizations.of(context)?.get('large') ?? 'Large';
    }
    return AppLocalizations.of(context)?.get('normal') ?? 'Normal';
  }

  String _getSkinName(BuildContext context, String color) {
    switch (color) {
      case 'classic':
        return AppLocalizations.of(context)?.get('skin_classic') ?? 'Classic';
      case 'crimson':
        return AppLocalizations.of(context)?.get('skin_crimson') ?? 'Crimson';
      case 'emerald':
        return AppLocalizations.of(context)?.get('skin_emerald') ?? 'Emerald';
      case 'sunset':
        return AppLocalizations.of(context)?.get('skin_sunset') ?? 'Sunset';
      case 'royal':
        return AppLocalizations.of(context)?.get('skin_royal') ?? 'Royal';
      case 'midnight':
        return AppLocalizations.of(context)?.get('skin_midnight') ?? 'Midnight';
      case 'ledger':
        return AppLocalizations.of(context)?.get('skin_ledger') ??
            'Professional Ledger';
      case 'audit':
        return AppLocalizations.of(context)?.get('skin_audit') ??
            'Midnight Audit';
      case 'mint':
        return AppLocalizations.of(context)?.get('skin_mint') ?? 'Mint Growth';
      case 'glass':
        return AppLocalizations.of(context)?.get('skin_glass') ??
            'Glass Inventory';
      case 'slate':
        return AppLocalizations.of(context)?.get('skin_slate') ??
            'Industrial Slate';
      default:
        return AppLocalizations.of(context)?.get('skin_classic') ?? 'Classic';
    }
  }

  Future<bool> _confirmRestart(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)?.get('confirm_change') ??
                'Confirm Change'),
            content: Text(AppLocalizations.of(context)
                    ?.get('restart_required') ??
                'This change requires an app restart to fully take effect. Do you want to apply it now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                    AppLocalizations.of(context)?.get('cancel') ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    Text(AppLocalizations.of(context)?.get('apply') ?? 'Apply'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, String currentLang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.get('language') ?? 'Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioItem<String>(
              label: 'English',
              val: 'en',
              groupValue: currentLang,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setLanguage(val!);
                }
              },
            ),
            _buildRadioItem<String>(
              label: 'Spanish (Español)',
              val: 'es',
              groupValue: currentLang,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setLanguage(val!);
                }
              },
            ),
            _buildRadioItem<String>(
              label: 'French (Français)',
              val: 'fr',
              groupValue: currentLang,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setLanguage(val!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLandingPageDialog(
      BuildContext context, WidgetRef ref, String currentRoute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.get('landing_page') ??
            'Default Landing Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioItem<String>(
              label:
                  AppLocalizations.of(context)?.get('dashboard') ?? 'Dashboard',
              val: '/dashboard',
              groupValue: currentRoute,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setLandingPage(val!);
                Navigator.pop(context);
              },
            ),
            _buildRadioItem<String>(
              label:
                  AppLocalizations.of(context)?.get('orders') ?? 'Order List',
              val: '/orders',
              groupValue: currentRoute,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setLandingPage(val!);
                Navigator.pop(context);
              },
            ),
            _buildRadioItem<String>(
              label:
                  AppLocalizations.of(context)?.get('new_order') ?? 'New Order',
              val: '/orders/create',
              groupValue: currentRoute,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).setLandingPage(val!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper for cleaner code
  Widget _buildRadioItem<T>(
      {required String label,
      required T val,
      required T groupValue,
      required ValueChanged<T?> onChanged}) {
    return ListTile(
      title: Text(label),
      leading: Radio<T>(
        value: val,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(val),
    );
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.get('theme_mode') ?? 'Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioItem<ThemeMode>(
              label: AppLocalizations.of(context)?.get('system_default') ??
                  'System Default',
              val: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setThemeMode(val!);
                }
              },
            ),
            _buildRadioItem<ThemeMode>(
              label: AppLocalizations.of(context)?.get('light_mode') ??
                  'Light Mode',
              val: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setThemeMode(val!);
                }
              },
            ),
            _buildRadioItem<ThemeMode>(
              label:
                  AppLocalizations.of(context)?.get('dark_mode') ?? 'Dark Mode',
              val: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (val) async {
                Navigator.pop(context);
                if (await _confirmRestart(context)) {
                  ref.read(settingsProvider.notifier).setThemeMode(val!);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  AppLocalizations.of(context)?.get('cancel') ?? 'Cancel')),
        ],
      ),
    );
  }

  void _showFontDialog(
      BuildContext context, WidgetRef ref, double currentScale) {
    // Round to nearest handy value or check strict equality?
    // Let's rely on standard sets
    final standardScales = [0.85, 1.0, 1.15];
    final isCustom = !standardScales.contains(currentScale);
    double selected = isCustom ? -1.0 : currentScale;

    // Limit Dropdown options
    final customOptions = [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(
              AppLocalizations.of(context)?.get('font_size') ?? 'Font Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)?.get('small') ??
                    'Small (0.85)'),
                leading: Radio<double>(
                  value: 0.85,
                  groupValue: selected,
                  onChanged: (val) async {
                    Navigator.pop(context);
                    if (await _confirmRestart(context)) {
                      ref.read(settingsProvider.notifier).setTextScale(val!);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)?.get('normal') ??
                    'Normal (1.0)'),
                leading: Radio<double>(
                  value: 1.0,
                  groupValue: selected,
                  onChanged: (val) async {
                    Navigator.pop(context);
                    if (await _confirmRestart(context)) {
                      ref.read(settingsProvider.notifier).setTextScale(val!);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)?.get('large') ??
                    'Large (1.15)'),
                leading: Radio<double>(
                  value: 1.15,
                  groupValue: selected,
                  onChanged: (val) async {
                    Navigator.pop(context);
                    if (await _confirmRestart(context)) {
                      ref.read(settingsProvider.notifier).setTextScale(val!);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Custom Size'),
                leading: Radio<double>(
                  value: -1.0,
                  groupValue: selected,
                  onChanged: (val) {
                    setDialogState(() => selected = -1.0);
                  },
                ),
                subtitle: selected == -1.0
                    ? DropdownButton<double>(
                        value: customOptions.contains(currentScale)
                            ? currentScale
                            : 1.0,
                        isExpanded: true,
                        items: customOptions
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s.toString())))
                            .toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            Navigator.pop(context);
                            if (await _confirmRestart(context)) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTextScale(val);
                            }
                          }
                        },
                      )
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    AppLocalizations.of(context)?.get('cancel') ?? 'Cancel')),
          ],
        );
      }),
    );
  }

  void _showFontFamilyDialog(
      BuildContext context, WidgetRef ref, String currentFont) {
    const fonts = [
      'Poppins',
      'Roboto',
      'Open Sans',
      'Lato',
      'Inter',
      'Montserrat',
      'Nunito'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.get('font_family') ?? 'Font Family'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: fonts.map((font) {
              return _buildRadioItem<String>(
                label: font,
                val: font,
                groupValue: currentFont,
                onChanged: (val) async {
                  Navigator.pop(context);
                  if (await _confirmRestart(context)) {
                    ref.read(settingsProvider.notifier).setFontFamily(val!);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  AppLocalizations.of(context)?.get('cancel') ?? 'Cancel')),
        ],
      ),
    );
  }

  void _showSkinDialog(
      BuildContext context, WidgetRef ref, String currentColor) {
    final skins = [
      {
        'id': 'classic',
        'label': AppLocalizations.of(context)?.get('skin_classic') ??
            'Classic (Blue)',
        'color': const Color(0xFF054C78)
      },
      {
        'id': 'crimson',
        'label': AppLocalizations.of(context)?.get('skin_crimson') ??
            'Crimson (Red)',
        'color': const Color(0xFFD32F2F)
      },
      {
        'id': 'emerald',
        'label': AppLocalizations.of(context)?.get('skin_emerald') ??
            'Emerald (Green)',
        'color': const Color(0xFF2E7D32)
      },
      {
        'id': 'sunset',
        'label': AppLocalizations.of(context)?.get('skin_sunset') ??
            'Sunset (Orange)',
        'color': const Color(0xFFED6C02)
      },
      {
        'id': 'royal',
        'label':
            AppLocalizations.of(context)?.get('skin_royal') ?? 'Royal (Purple)',
        'color': const Color(0xFF7B1FA2)
      },
      {
        'id': 'midnight',
        'label': AppLocalizations.of(context)?.get('skin_midnight') ??
            'Midnight (Dark)',
        'color': const Color(0xFF37474F)
      },
      {
        'id': 'ledger',
        'label': AppLocalizations.of(context)?.get('skin_ledger') ??
            'Professional Ledger',
        'color': const Color(0xFF103766)
      },
      {
        'id': 'audit',
        'label':
            AppLocalizations.of(context)?.get('skin_audit') ?? 'Midnight Audit',
        'color': const Color(0xFF00E676)
      },
      {
        'id': 'mint',
        'label':
            AppLocalizations.of(context)?.get('skin_mint') ?? 'Mint Growth',
        'color': const Color(0xFF00A36C)
      },
      {
        'id': 'glass',
        'label': AppLocalizations.of(context)?.get('skin_glass') ??
            'Glass Inventory',
        'color': const Color(0xFF00BCD4)
      },
      {
        'id': 'slate',
        'label': AppLocalizations.of(context)?.get('skin_slate') ??
            'Industrial Slate',
        'color': const Color(0xFF455A64)
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            AppLocalizations.of(context)?.get('theme_skin') ?? 'Theme Skin'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: skins.map((skin) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: skin['color'] as Color,
                  radius: 12,
                ),
                title: Text(skin['label'] as String),
                trailing: currentColor == skin['id']
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (await _confirmRestart(context)) {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeColor(skin['id'] as String);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  AppLocalizations.of(context)?.get('cancel') ?? 'Cancel')),
        ],
      ),
    );
  }

  void _showSyncingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing data...'),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialogWithRef(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.get('clear_cache') ??
            'Clear Local Cache?'),
        content: Text(AppLocalizations.of(context)
                ?.get('clear_cache_confirmation') ??
            'This will delete all local data (Orders, Products, Partners, Stores). The app will logout. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(AppLocalizations.of(context)?.get('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close first dialog

              // safety check
              final hasUnsynced =
                  await ref.read(syncServiceProvider).hasUnsyncedData();
              if (hasUnsynced && context.mounted) {
                final confirmForce = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title: const Text('Unsynced Data Detected!'),
                          content: const Text(
                              'You have offline changes that have NOT been synced to the server. clearing the cache will PERMANENTLY DELETE these changes.\n\nAre you sure?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('DELETE ANYWAY',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ));
                if (confirmForce != true) return;
              }

              if (context.mounted) {
                await _performClearCache(context);
              }
            },
            child: const Text('Clear & Logout',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache(BuildContext context) async {
    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final db = await import_database_helper.DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        // Truncate/Delete all transactional tables
        await txn.delete(
            'local_order_items'); // If exists, else ignore (it's payload usually)
        await txn.delete('local_orders');
        await txn.delete('local_products');
        await txn.delete('local_businesspartners');
        await txn.delete('local_stores'); // Clears stores
        await txn.delete('local_organizations'); // Clears orgs
        await txn.delete('local_brands');
        await txn.delete('local_categories');
        await txn.delete('local_product_types');
        await txn.delete('local_cities');
        await txn.delete('local_states');
        await txn.delete('local_countries');
        await txn.delete('local_business_types');
        await txn.delete('local_deleted_records');
        // Don't delete local_users or local_app_users unless we want full reset
        // But since we are logging out, it's fine.

        // Clear sync metadata
        await txn.delete('sync_metadata');
        await txn.delete('sync_queue');
      });

      // Sign out Supabase
      await SupabaseConfig.client.auth.signOut();

      if (context.mounted) {
        Navigator.pop(context); // Pop Loading
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Local cache cleared. Please login again.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
