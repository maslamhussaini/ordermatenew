import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ordermate/core/services/auth_service_biometrics.dart';
import 'package:ordermate/features/settings/domain/models/pdf_settings.dart'; // Import PdfSettings

import 'package:ordermate/core/network/supabase_client.dart';

final currentUserIdProvider = StreamProvider<String?>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange
      .map((event) => event.session?.user.id);
});

// Provider to hold the current theme mode and visual settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final userIdAsync = ref.watch(currentUserIdProvider);
  return SettingsNotifier(userIdAsync.value);
});

// Create a State class to hold multiple settings
class SettingsState {
  final ThemeMode themeMode;
  final double textScaleFactor;
  final bool notificationsEnabled;
  final String language;
  final String landingPage;
  final bool biometricEnabled;
  final String fontFamily;
  final String themeColor;
  final PdfSettings pdfSettings;
  final bool offlineMode;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.textScaleFactor = 1.0,
    this.notificationsEnabled = true,
    this.language = 'en',
    this.landingPage = '/dashboard',
    this.biometricEnabled = false,
    this.fontFamily = 'Montserrat',
    this.themeColor = 'classic',
    this.pdfSettings = const PdfSettings(),
    this.offlineMode = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? textScaleFactor,
    bool? notificationsEnabled,
    String? language,
    String? landingPage,
    bool? biometricEnabled,
    String? fontFamily,
    String? themeColor,
    PdfSettings? pdfSettings,
    bool? offlineMode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      landingPage: landingPage ?? this.landingPage,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      fontFamily: fontFamily ?? this.fontFamily,
      themeColor: themeColor ?? this.themeColor,
      pdfSettings: pdfSettings ?? this.pdfSettings,
      offlineMode: offlineMode ?? this.offlineMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final String? userId;

  SettingsNotifier(this.userId) : super(const SettingsState()) {
    _loadPreference();
  }

  String _key(String baseKey) =>
      userId == null ? baseKey : '${userId}_$baseKey';

  static const _themeKey = 'theme_mode_preference';
  static const _fontScaleKey = 'font_scale_preference';
  static const _notifKey = 'notifications_enabled_preference';
  static const _langKey = 'language_preference';
  static const _landingKey = 'landing_page_preference';
  // Use constant from AuthService to ensure consistency
  static const _bioKey = AuthService.biometricPrefsKey;
  static const _fontFamilyKey = 'font_family_preference';
  static const _themeColorKey = 'theme_color_preference';
  static const _pdfSettingsKey = 'pdf_settings_preference';
  static const _offlineKey = 'offline_mode_preference';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    final savedMode = prefs.getString(_key(_themeKey));
    ThemeMode mode = ThemeMode.system;
    if (savedMode == 'light') mode = ThemeMode.light;
    if (savedMode == 'dark') mode = ThemeMode.dark;

    // Load Font Scale
    final savedScale = prefs.getDouble(_key(_fontScaleKey)) ?? 1.0;

    // Load Notifications
    final notifs = prefs.getBool(_key(_notifKey)) ?? true;

    // Load New Settings
    final lang = prefs.getString(_key(_langKey)) ?? 'en';
    final landing = prefs.getString(_key(_landingKey)) ?? '/dashboard';
    final bio = prefs.getBool(_key(_bioKey)) ?? false;
    final font = prefs.getString(_key(_fontFamilyKey)) ?? 'Montserrat';
    final color = prefs.getString(_key(_themeColorKey)) ?? 'classic';

    // Load PDF Settings
    final pdfJson = prefs.getString(_key(_pdfSettingsKey));
    final pdfSettings =
        pdfJson != null ? PdfSettings.fromJson(pdfJson) : const PdfSettings();
    final offline = prefs.getBool(_key(_offlineKey)) ?? false;

    if (mounted) {
      state = SettingsState(
        themeMode: mode,
        textScaleFactor: savedScale,
        notificationsEnabled: notifs,
        language: lang,
        landingPage: landing,
        biometricEnabled: bio,
        fontFamily: font,
        themeColor: color,
        pdfSettings: pdfSettings,
        offlineMode: offline,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await prefs.setString(_key(_themeKey), value);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScaleFactor: scale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key(_fontScaleKey), scale);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_notifKey), enabled);
  }

  Future<void> setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_langKey), lang);
  }

  Future<void> setLandingPage(String route) async {
    state = state.copyWith(landingPage: route);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_landingKey), route);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_bioKey), enabled);
  }

  Future<void> setFontFamily(String font) async {
    state = state.copyWith(fontFamily: font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_fontFamilyKey), font);
  }

  Future<void> setThemeColor(String color) async {
    state = state.copyWith(themeColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_themeColorKey), color);
  }

  Future<void> setPdfSettings(PdfSettings settings) async {
    state = state.copyWith(pdfSettings: settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_pdfSettingsKey), settings.toJson());
  }

  Future<void> setOfflineMode(bool enabled) async {
    state = state.copyWith(offlineMode: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(_offlineKey), enabled);
  }
}

// Deprecated: kept for backward compatibility if any, or to be removed
// final themeModeProvider = ... (removed)
