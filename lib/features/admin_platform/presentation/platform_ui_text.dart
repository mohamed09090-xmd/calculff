import 'package:flutter/widgets.dart';

import '../../../core/localization/app_translator.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/common/platform_failure.dart';

String platformText(BuildContext context, String arabic) {
  if (Localizations.localeOf(context).languageCode == 'fr') {
    final translated = _platformFrench[arabic];
    if (translated != null) {
      return translated;
    }
  }
  return AppTranslator.translate(context, arabic);
}

String platformFailureText(BuildContext context, AdminAuthFailureCode? code) {
  final source = switch (code) {
    AdminAuthFailureCode.invalidCredentials => 'بيانات الدخول غير صحيحة.',
    AdminAuthFailureCode.networkUnavailable => 'لا يوجد اتصال بالمنصة.',
    AdminAuthFailureCode.sessionExpired => 'انتهت الجلسة.',
    AdminAuthFailureCode.unauthorized => 'الحساب غير مخول لإدارة المنصة.',
    AdminAuthFailureCode.configurationUnavailable => 'إعداد المنصة غير متوفر.',
    AdminAuthFailureCode.operationInProgress =>
      'هناك محاولة تسجيل دخول قيد التنفيذ.',
    AdminAuthFailureCode.unknown || null => 'حدث خطأ آمن. أعد المحاولة.',
  };
  return platformText(context, source);
}

String platformDataFailureText(BuildContext context, PlatformFailure failure) {
  final source = switch (failure.code) {
    PlatformFailureCode.networkUnavailable =>
      'تعذر الاتصال بالمنصة. تحقق من الشبكة ثم أعد المحاولة.',
    PlatformFailureCode.sessionExpired =>
      'انتهت الجلسة. سجّل الدخول مجددًا للمتابعة.',
    PlatformFailureCode.unauthorized =>
      'لا يملك هذا الحساب صلاحية تنفيذ العملية.',
    PlatformFailureCode.notFound => 'لم تعد اللعبة المطلوبة موجودة.',
    PlatformFailureCode.validation => 'تحقق من القيم المدخلة.',
    PlatformFailureCode.duplicateSlug => 'المعرّف النصي مستخدم من لعبة أخرى.',
    PlatformFailureCode.dependencyExists =>
      'لا يمكن تنفيذ العملية لوجود بيانات مرتبطة.',
    PlatformFailureCode.malformedResponse =>
      'استلم التطبيق بيانات غير صالحة من المنصة.',
    PlatformFailureCode.temporarilyUnavailable =>
      'الخدمة غير متاحة مؤقتًا. أعد المحاولة لاحقًا.',
    PlatformFailureCode.unknown => 'حدث خطأ آمن. أعد المحاولة.',
  };
  return platformText(context, source);
}

const Map<String, String> _platformFrench = {
  'ملخص مباشر لحالة منصة الزبائن.': 'Résumé actuel de la plateforme clients.',
  'تحديث لوحة المنصة': 'Actualiser le tableau de bord',
  'جارٍ تحميل لوحة المنصة.': 'Chargement du tableau de bord…',
  'تعذر تحميل لوحة المنصة.': 'Impossible de charger le tableau de bord.',
  'الطلبات الجديدة': 'Nouvelles commandes',
  'قيد المعالجة': 'En traitement',
  'مراجعة الدفع': 'Paiements à vérifier',
  'المكتملة': 'Terminées',
  'العروض المنشورة': 'Offres publiées',
  'الألعاب النشطة': 'Jeux actifs',
  'آخر تحديث محلي': 'Dernière mise à jour locale',
  'إدارة الألعاب': 'Gestion des jeux',
  'أضف الألعاب وعدّل بياناتها أو فعّلها وعطّلها.':
      'Ajoutez des jeux, modifiez leurs données, activez-les ou désactivez-les.',
  'إضافة لعبة': 'Ajouter un jeu',
  'إضافة أول لعبة': 'Ajouter le premier jeu',
  'تعديل اللعبة': 'Modifier le jeu',
  'حفظ اللعبة': 'Enregistrer le jeu',
  'تحديث الألعاب': 'Actualiser les jeux',
  'جارٍ تحميل الألعاب.': 'Chargement des jeux…',
  'تعذر تحميل الألعاب.': 'Impossible de charger les jeux.',
  'لا توجد ألعاب بعد.': 'Aucun jeu pour le moment.',
  'أضف أول لعبة لبدء إدارة العروض لاحقًا.':
      'Ajoutez un premier jeu pour préparer la gestion des offres.',
  'البيانات المعروضة قديمة.': 'Les données affichées peuvent être obsolètes.',
  'لعبة': 'Jeu',
  'المعرّف النصي': 'Identifiant textuel',
  'أحرف إنجليزية صغيرة وأرقام وشرطات فقط.':
      'Utilisez uniquement des lettres minuscules, des chiffres et des tirets.',
  'اسم اللعبة بالعربية': 'Nom du jeu en arabe',
  'اسم اللعبة بالفرنسية': 'Nom du jeu en français',
  'رمز وحدة المكافأة': 'Code de l’unité de récompense',
  'أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط.':
      'Utilisez uniquement des lettres minuscules, des chiffres et un soulignement.',
  'اسم وحدة المكافأة بالعربية': 'Nom de l’unité de récompense en arabe',
  'اسم وحدة المكافأة بالفرنسية': 'Nom de l’unité de récompense en français',
  'ترتيب العرض': 'Ordre d’affichage',
  'اللعبة فعّالة': 'Jeu actif',
  'فعّالة': 'Actif',
  'معطّلة': 'Inactif',
  'تفعيل اللعبة': 'Activer le jeu',
  'تعطيل اللعبة': 'Désactiver le jeu',
  'تمت إضافة اللعبة.': 'Le jeu a été ajouté.',
  'تم تحديث اللعبة.': 'Le jeu a été mis à jour.',
  'تم تفعيل اللعبة.': 'Le jeu a été activé.',
  'تم تعطيل اللعبة.': 'Le jeu a été désactivé.',
  'أدخل ترتيبًا صحيحًا يبدأ من صفر.':
      'Saisissez un ordre valide à partir de zéro.',
  'هذا الحقل مطلوب.': 'Ce champ est obligatoire.',
  'القيمة قصيرة جدًا.': 'La valeur est trop courte.',
  'القيمة طويلة جدًا.': 'La valeur est trop longue.',
  'استخدم أحرفًا إنجليزية صغيرة فقط.':
      'Utilisez uniquement des lettres minuscules.',
  'صيغة القيمة غير صحيحة.': 'Le format de la valeur est invalide.',
  'يجب أن تكون القيمة أكبر من صفر.': 'La valeur doit être supérieure à zéro.',
  'اللعبة المحددة غير فعّالة.': 'Le jeu sélectionné est inactif.',
  'تحتوي القيمة على محارف غير مسموحة.':
      'La valeur contient des caractères non autorisés.',
  'النطاق غير صحيح.': 'La plage est invalide.',
  'تعذر الاتصال بالمنصة. تحقق من الشبكة ثم أعد المحاولة.':
      'Connexion à la plateforme impossible. Vérifiez le réseau puis réessayez.',
  'انتهت الجلسة. سجّل الدخول مجددًا للمتابعة.':
      'La session a expiré. Reconnectez-vous pour continuer.',
  'لا يملك هذا الحساب صلاحية تنفيذ العملية.':
      'Ce compte ne dispose pas des droits nécessaires.',
  'لم تعد اللعبة المطلوبة موجودة.': 'Le jeu demandé n’existe plus.',
  'تحقق من القيم المدخلة.': 'Vérifiez les valeurs saisies.',
  'المعرّف النصي مستخدم من لعبة أخرى.':
      'Cet identifiant textuel est déjà utilisé par un autre jeu.',
  'لا يمكن تنفيذ العملية لوجود بيانات مرتبطة.':
      'L’opération est impossible en raison de données associées.',
  'استلم التطبيق بيانات غير صالحة من المنصة.':
      'L’application a reçu des données invalides de la plateforme.',
  'الخدمة غير متاحة مؤقتًا. أعد المحاولة لاحقًا.':
      'Le service est temporairement indisponible. Réessayez plus tard.',
};
