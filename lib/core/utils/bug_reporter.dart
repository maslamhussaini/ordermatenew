// lib/core/utils/bug_reporter.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart' as smtp;
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional Import
import 'web_utils.dart' if (dart.library.html) 'web_utils_web.dart';

final screenshotControllerProvider = Provider((ref) => ScreenshotController());

class BugReportService {
  final Ref ref;
  static DateTime? _lastReportedTime;

  BugReportService(this.ref);

  /// Automatically reports an error found in the console/logs
  Future<void> reportError(dynamic error, StackTrace? stack) async {
    // Rate limit: Don't send more than one error report every 5 minutes
    if (_lastReportedTime != null &&
        DateTime.now().difference(_lastReportedTime!) <
            const Duration(minutes: 5)) {
      debugPrint('Skipping auto-error report due to rate limiting.');
      return;
    }

    final username = dotenv.env['GMAIL_USERNAME'];
    final password = dotenv.env['GMAIL_APP_PASSWORD'];

    if (username == null ||
        password == null ||
        username.isEmpty ||
        password.isEmpty) {
      debugPrint('Auto-Error: No SMTP credentials found. Cannot send email.');
      return;
    }

    _lastReportedTime = DateTime.now();

    try {
      if (kIsWeb) {
        debugPrint(
            'Auto-Error: Silent SMTP reporting is not supported on Web. Skipping.');
        return;
      }

      final smtpServer = gmail(username, password);
      final message = smtp.Message()
        ..from = smtp.Address(username, 'OrderMate Auto-Logger')
        ..recipients.add('maslamhussaini@gmail.com')
        ..subject = 'CRITICAL: OrderMate Error Alert'
        ..text = '''
OrderMate has encountered a runtime error. 
Please find the detailed log attached.

System Info: ${defaultTargetPlatform.name}
Time: ${DateTime.now()}
''';

      // ON MOBILE/DESKTOP, we can attach a file
      if (!kIsWeb) {
        final directory = (await getTemporaryDirectory()).path;
        final logFile = File(
            '$directory/error_log_${DateTime.now().millisecondsSinceEpoch}.txt');
        await logFile.writeAsString('ERROR:\n$error\n\nSTACK TRACE:\n$stack');
        message.attachments.add(smtp.FileAttachment(logFile));
      }

      await smtp.send(message, smtpServer);
      debugPrint('Auto-error report sent successfully.');
    } catch (e) {
      debugPrint('Failed to send auto-error report: $e');
    }
  }

  Future<void> captureAndReport(BuildContext context) async {
    final controller = ref.read(screenshotControllerProvider);

    try {
      // Capture High-Res Image as Bytes (Platform Agnostic)
      final Uint8List? imageBytes = await controller.capture(pixelRatio: 1.5);

      if (imageBytes == null) {
        debugPrint('Screenshot failed');
        return;
      }

      // Handle Web
      if (kIsWeb) {
        final fileName =
            'bug_report_${DateTime.now().millisecondsSinceEpoch}.png';

        // 1. Download
        downloadFile(imageBytes, fileName);

        // 2. Open Mail Client (Interactive only, browsers block silent send)
        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: 'maslamhussaini@gmail.com',
          query: _encodeQueryParameters(<String, String>{
            'subject': 'OrderMate Bug Report',
            'body':
                'A screenshot has been downloaded to your device.\n\nPLEASE ATTACH THE DOWNLOADED SCREENSHOT MANUALLY.\n\nSystem Info: Web/Browser',
          }),
        );

        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        } else {
          debugPrint('Could not launch email client.');
        }
        return;
      }

      // Handle Mobile/Desktop
      final directory = (await getApplicationDocumentsDirectory()).path;
      final fileName =
          'bug_report_${DateTime.now().millisecondsSinceEpoch}.png';
      final path = '$directory/$fileName';

      final File imageFile = File(path);
      await imageFile.writeAsBytes(imageBytes);

      // Check if we have credentials for silent send (Mobile/Desktop only)
      final username = dotenv.env['GMAIL_USERNAME'];
      final password = dotenv.env['GMAIL_APP_PASSWORD'];

      if (username != null &&
          password != null &&
          username.isNotEmpty &&
          password.isNotEmpty) {
        // SILENT SEND
        debugPrint('Attempting silent email via SMTP...');
        await _sendSilently(username, password, path);
        if (context.mounted) {
          debugPrint('Silent email sent successfully!');
        }
      } else {
        // INTERACTIVE SEND (Fallback)
        debugPrint('No SMTP credentials in .env, using interactive Intent.');
        await _sendInteractively(path);
      }
    } catch (e) {
      debugPrint('Bug Report Error: $e');
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _sendSilently(
      String username, String password, String attachmentPath) async {
    final smtpServer = gmail(username, password);

    final message = smtp.Message()
      ..from = smtp.Address(username, 'OrderMate Bug Reporter')
      ..recipients.add('maslamhussaini@gmail.com')
      ..subject = 'OrderMate Bug Report (Auto-Captured)'
      ..text =
          'Please find the attached screenshot of the bug.\n\nSystem Info: ${defaultTargetPlatform.name}'
      ..attachments.add(smtp.FileAttachment(File(attachmentPath)));

    try {
      final sendReport = await smtp.send(message, smtpServer);
      debugPrint('Message sent: $sendReport');
    } on smtp.MailerException catch (e) {
      debugPrint('Message not sent.');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      rethrow;
    }
  }

  Future<void> _sendInteractively(String attachmentPath) async {
    final Email email = Email(
      body:
          'Please describe the bug encountered:\n\n\n\nSystem Info: ${defaultTargetPlatform.name}',
      subject: 'OrderMate Bug Report',
      recipients: ['maslamhussaini@gmail.com'],
      attachmentPaths: [attachmentPath],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }
}

final bugReportServiceProvider = Provider((ref) => BugReportService(ref));
