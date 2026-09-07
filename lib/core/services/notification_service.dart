import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ordermate/core/utils/logger.dart';

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    AppLogger.info('NotificationService: Initializing...');
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initializationSettingsWindows = WindowsInitializationSettings(
      appName: 'OrderMate',
      appUserModelId: 'com.ordermate.ordermate_app',
      guid: '6b703e30-67c4-4b52-9705-7f722c1e7a02',
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    try {
      final result = await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Handle notification tap
          AppLogger.info('NotificationService: Notification tapped');
        },
      );
      _isInitialized = result ?? false;
      AppLogger.info(
          'NotificationService: Initialization complete. Result: $result');
    } catch (e, stackTrace) {
      AppLogger.error(
          'NotificationService: Initialization failed: $e', e, stackTrace);
    }
  }

  Future<void> showOTPNotification(String otp) async {
    if (!_isInitialized) {
      await init();
      if (!_isInitialized) {
        throw Exception('Notification Service failed to initialize');
      }
    }

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'otp_channel',
      'OTP Notifications',
      channelDescription: 'Channel for OTP notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      windows: WindowsNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Verification Code',
      'Your verification code is: $otp',
      platformChannelSpecifics,
    );
  }
}
