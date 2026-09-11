// نسخة الويب/غير المدعومة: لا يوجد SMTP في المتصفح.
import 'mail_service.dart';

MailTransport createTransport() => const _NoTransport();

class _NoTransport implements MailTransport {
  const _NoTransport();
  @override
  bool get available => false;
  @override
  Future<void> send(MailMessage message) async =>
      throw UnsupportedError('SMTP غير مدعوم على هذه المنصة');
}
