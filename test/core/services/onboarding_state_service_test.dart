import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';

void main() {
  group('OnboardingStateService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and resume data for team step', () async {
      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/team',
        orgId: 1,
        storeId: 2,
        email: 'test@example.com',
      );

      final data = await OnboardingStateService.resumeData();
      expect(data, isNotNull);
      expect(data!['route'], '/onboarding/team');
      expect(data['orgId'], 1);
      expect(data['storeId'], 2);
      expect(data['email'], 'test@example.com');
    });

    test('save and resume data for verify step', () async {
      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/verify',
        orgId: 10,
        storeId: 20,
        email: 'verify@example.com',
      );

      final data = await OnboardingStateService.resumeData();
      expect(data, isNotNull);
      expect(data!['route'], '/onboarding/verify');
      expect(data['orgId'], 10);
      expect(data['storeId'], 20);
      expect(data['email'], 'verify@example.com');
    });

    test('clear removes all data', () async {
      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/verify',
        orgId: 1,
        storeId: 2,
        email: 'test@example.com',
      );

      await OnboardingStateService.clear();

      final data = await OnboardingStateService.resumeData();
      expect(data, isNull);
    });

    test('resumeData returns null when not in progress', () async {
      final data = await OnboardingStateService.resumeData();
      expect(data, isNull);
    });

    test('resumeData returns null when route is missing', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_in_progress': true,
        'onboarding_org_id': 1,
        'onboarding_store_id': 2,
        'onboarding_email': 'test@example.com',
      });

      final data = await OnboardingStateService.resumeData();
      expect(data, isNull);
    });

    test('resumeData returns null when orgId is missing', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_in_progress': true,
        'onboarding_route': '/onboarding/verify',
        'onboarding_store_id': 2,
        'onboarding_email': 'test@example.com',
      });

      final data = await OnboardingStateService.resumeData();
      expect(data, isNull);
    });

    test('resumeData returns null when email is missing', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_in_progress': true,
        'onboarding_route': '/onboarding/verify',
        'onboarding_org_id': 1,
        'onboarding_store_id': 2,
      });

      final data = await OnboardingStateService.resumeData();
      expect(data, isNull);
    });

    test('overwrite updates existing onboarding state', () async {
      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/team',
        orgId: 1,
        storeId: 2,
        email: 'old@example.com',
      );

      await OnboardingStateService.save(
        inProgress: true,
        route: '/onboarding/verify',
        orgId: 10,
        storeId: 20,
        email: 'new@example.com',
      );

      final data = await OnboardingStateService.resumeData();
      expect(data!['route'], '/onboarding/verify');
      expect(data['orgId'], 10);
      expect(data['storeId'], 20);
      expect(data['email'], 'new@example.com');
    });
  });
}
