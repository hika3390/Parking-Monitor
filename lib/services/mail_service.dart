import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class MailService {
  // Gmail SMTPサーバーの設定
  static final smtpServer = gmail('your-email@gmail.com', 'your-app-password');

  static Future<void> sendNotification({
    required String toEmail,
    required String subject,
    required String body,
    File? imageFile,
  }) async {
    final message = Message()
      ..from = Address('your-email@gmail.com', 'Parking Monitor')
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = body;

    if (imageFile != null) {
      final attachment = FileAttachment(imageFile)
        ..location = Location.inline
        ..cid = '<image>';
      message.attachments.add(attachment);
    }

    try {
      await send(message, smtpServer);
    } catch (e) {
      throw Exception('メール送信に失敗しました: $e');
    }
  }

  static bool isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    return emailRegExp.hasMatch(email);
  }
}
