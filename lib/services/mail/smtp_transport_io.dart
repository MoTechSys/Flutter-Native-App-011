// نسخة أندرويد/سطح المكتب: إرسال فعلي عبر SMTP (حزمة mailer).
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import 'mail_service.dart';

MailTransport createTransport() => const _SmtpTransport();

class _SmtpTransport implements MailTransport {
  const _SmtpTransport();

  @override
  bool get available => MailConfig.isConfigured;

  @override
  Future<void> send(MailMessage m) async {
    final server = SmtpServer(
      MailConfig.host,
      port: MailConfig.port,
      ssl: MailConfig.port == 465,
      username: MailConfig.user,
      password: MailConfig.pass,
    );
    final message = mailer.Message()
      ..from = mailer.Address(MailConfig.user, MailConfig.senderName)
      ..recipients.add(m.to)
      ..subject = m.subject
      ..text = m.text
      ..html = m.html;
    await mailer.send(message, server);
  }
}
