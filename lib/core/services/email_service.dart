import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ordermate/core/network/supabase_client.dart';

class EmailService {
  // Singleton pattern
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // SMTP Credentials - Fetched via getters to ensure they are read AFTER dotenv.load()
  String get smtpUsername =>
      (dotenv.env['SMTP_EMAIL'] ?? dotenv.env['GMAIL_USERNAME'] ?? '').trim();
  String get smtpPassword =>
      (dotenv.env['SMTP_PASSWORD'] ?? dotenv.env['GMAIL_APP_PASSWORD'] ?? '')
          .replaceAll(' ', '')
          .trim();

  String get _smtpUsername => smtpUsername;
  String get _smtpPassword => smtpPassword;

  Future<bool> _sendWebEmail({
    required String email,
    required String subject,
    required String html,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send-email-v2',
        body: {
          'email': email,
          'subject': subject,
          'html': html,
          'smtp_settings': {
            'username': _smtpUsername,
            'password': _smtpPassword,
          },
        },
      );
      return response.status == 200;
    } catch (e) {
      debugPrint('Web SMTP Error: $e');
      return false;
    }
  }

  Future<bool> sendOtpEmail(String recipientEmail, String otp) async {
    const subject = 'OrderMate App - Your Verification Code';
    final html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #2196F3;">OrderMate App Verification</h2>
          <p>Hello,</p>
          <p>Your verification code is:</p>
          <div style="font-size: 32px; font-weight: bold; color: #333; margin: 20px 0;">$otp</div>
          <p style="color: #666; font-size: 14px;">This code is valid for 10 minutes. If you did not request this, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>
      """;

    if (kIsWeb) {
      return _sendWebEmail(email: recipientEmail, subject: subject, html: html);
    }

    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    final message = mailer.Message()
      ..from = mailer.Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text =
          'Your OrderMate App verification code is: $otp. It is valid for 10 minutes.'
      ..html = html;

    try {
      final sendReport = await mailer.send(message, smtpServer);
      debugPrint('Message sent: $sendReport');
      return true;
    } on mailer.MailerException catch (e) {
      debugPrint('Message not sent.');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    }
  }

  Future<bool> sendWelcomeEmail(
      String recipientEmail, String employeeName, String role) async {
    const subject = 'Welcome to OrderMate - Your Account is Ready';
    final html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #4CAF50;">Welcome to OrderMate, $employeeName!</h2>
          <p>Your account has been created successfully with the role of <strong>$role</strong>.</p>
          <p>You can now log in to the application and start managing your tasks.</p>
          <div style="padding: 15px; background: #f5f5f5; border-radius: 5px; margin: 20px 0;">
             <p><strong>Login Email:</strong> $recipientEmail</p>
          </div>
          <p>If you have any questions, please contact your administrator.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>
      """;

    if (kIsWeb) {
      return _sendWebEmail(email: recipientEmail, subject: subject, html: html);
    }

    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    final message = mailer.Message()
      ..from = mailer.Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..html = html;

    try {
      await mailer.send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('Error sending welcome email: $e');
      return false;
    }
  }

  Future<bool> sendCredentialsEmail(String recipientEmail, String employeeName,
      String password, String loginUrl) async {
    const subject = 'OrderMate App - Your Login Credentials';
    final html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px; max-width: 600px; margin: auto;">
          <h2 style="color: #2196F3;">Welcome to OrderMate, $employeeName!</h2>
          <p>Your account has been set up. Please use the following credentials to log in and then set your permanent password.</p>
          
          <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #dee2e6;">
            <p style="margin: 0 0 10px 0;"><strong>Login Email:</strong> $recipientEmail</p>
            <p style="margin: 0;"><strong>Default Password:</strong> <code style="background: #eee; padding: 2px 5px; border-radius: 4px;">$password</code></p>
          </div>
          
          <p style="margin-bottom: 25px;">Click the button below to set your permanent credentials and log in:</p>
          
          <div style="text-align: center;">
            <a href="$loginUrl" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Set Credentials & Login</a>
          </div>
          
          <p style="margin-top: 25px; color: #666; font-size: 14px;">If you cannot click the button, copy and paste this link into your browser:</p>
          <p style="word-break: break-all; color: #007bff; font-size: 12px;">$loginUrl</p>
          
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">Sent safely via OrderMate App</p>
        </div>
      """;

    if (kIsWeb) {
      return _sendWebEmail(email: recipientEmail, subject: subject, html: html);
    }

    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    final message = mailer.Message()
      ..from = mailer.Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..html = html;

    try {
      final sendReport = await mailer.send(message, smtpServer);
      debugPrint('Credentials email sent: $sendReport');
      return true;
    } catch (e) {
      debugPrint('Error sending credentials email: $e');
      return false;
    }
  }
 
  Future<bool> sendModuleConfigurationEmail({
    required String recipientEmail,
    required String orgName,
    required String businessType,
    required String moduleConfigUrl,
  }) async {
    const subject = 'OrderMate - Module Configuration';
    final html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px; max-width: 600px; margin: auto;">
          <h2 style="color: #2196F3;">Module Configuration</h2>
          <p>Hello,</p>
          <p>Your organization <strong>$orgName</strong> has been successfully initiated in OrderMate.</p>
          <p><strong>Business Type:</strong> $businessType</p>
          
          <p style="margin-top: 25px;">You can configuration your modules and permissions using the link below:</p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="$moduleConfigUrl" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Configure Modules & More</a>
          </div>
          
          <p style="color: #666; font-size: 14px;">If you have any questions, please contact your administrator or OrderMate support.</p>
          
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          <p style="font-size: 12px; color: #999; text-align: center;">Sent safely via OrderMate App</p>
        </div>
      """;
 
    if (kIsWeb) {
      return _sendWebEmail(email: recipientEmail, subject: subject, html: html);
    }
 
    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    final message = mailer.Message()
      ..from = mailer.Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..html = html;
 
    try {
      await mailer.send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('Error sending module config email: $e');
      return false;
    }
  }
}
