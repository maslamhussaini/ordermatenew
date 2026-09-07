import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStateService {
  static const _keyInProgress = 'onboarding_in_progress';
  static const _keyRoute = 'onboarding_route';
  static const _keyOrgId = 'onboarding_org_id';
  static const _keyStoreId = 'onboarding_store_id';
  static const _keyEmail = 'onboarding_email';
  static const _keyFySyear = 'onboarding_fy_syear';

  static Future<void> save({
    required bool inProgress,
    required String route,
    int? orgId,
    int? storeId,
    String? email,
    int? fySyear,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInProgress, inProgress);
    await prefs.setString(_keyRoute, route);
    if (orgId != null) await prefs.setInt(_keyOrgId, orgId);
    if (storeId != null) await prefs.setInt(_keyStoreId, storeId);
    if (email != null) await prefs.setString(_keyEmail, email);
    if (fySyear != null) await prefs.setInt(_keyFySyear, fySyear);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyInProgress);
    await prefs.remove(_keyRoute);
    await prefs.remove(_keyOrgId);
    await prefs.remove(_keyStoreId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyFySyear);
  }

  static Future<Map<String, dynamic>?> resumeData() async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = prefs.getBool(_keyInProgress) ?? false;
    print('OnboardingStateService.resumeData: inProgress=$inProgress');
    if (!inProgress) {
      print('OnboardingStateService.resumeData: CASE A - inProgress is false');
      return null;
    }

    final route = prefs.getString(_keyRoute);
    final orgId = prefs.getInt(_keyOrgId);
    final storeId = prefs.getInt(_keyStoreId);
    final email = prefs.getString(_keyEmail);
    final fySyear = prefs.getInt(_keyFySyear);

    print(
        'OnboardingStateService.resumeData: route=$route, orgId=$orgId, storeId=$storeId, email=$email, fySyear=$fySyear');

    if (route == null || orgId == null || email == null) {
      if (route == null) {
        print('OnboardingStateService.resumeData: CASE B - route is null');
      } else if (orgId == null) {
        print('OnboardingStateService.resumeData: CASE C - orgId is null');
      } else if (email == null) {
        print('OnboardingStateService.resumeData: CASE D - email is null');
      }
      return null;
    }

    print('OnboardingStateService.resumeData: CASE E - valid resumeData returned');
    return {
      'route': route,
      'orgId': orgId,
      'storeId': storeId,
      'email': email,
      'fySyear': fySyear,
    };
  }
}
