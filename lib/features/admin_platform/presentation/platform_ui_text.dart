import 'package:flutter/widgets.dart';

import '../../../core/localization/app_translator.dart';
import '../domain/admin_auth_failure.dart';

String platformText(BuildContext context, String arabic) {
  return AppTranslator.translate(context, arabic);
}

String platformFailureText(
  BuildContext context,
  AdminAuthFailureCode? code,
) {
  final source = switch (code) {
    AdminAuthFailureCode.invalidCredentials => 'بيانات الدخول غير صحيحة.',
    AdminAuthFailureCode.networkUnavailable => 'لا يوجد اتصال بالمنصة.',
    AdminAuthFailureCode.sessionExpired => 'انتهت الجلسة.',
    AdminAuthFailureCode.unauthorized => 'الحساب غير مخول لإدارة المنصة.',
    AdminAuthFailureCode.configurationUnavailable =>
      'إعداد المنصة غير متوفر.',
    AdminAuthFailureCode.operationInProgress =>
      'هناك محاولة تسجيل دخول قيد التنفيذ.',
    AdminAuthFailureCode.unknown || null =>
      'حدث خطأ آمن. أعد المحاولة.',
  };
  return platformText(context, source);
}
