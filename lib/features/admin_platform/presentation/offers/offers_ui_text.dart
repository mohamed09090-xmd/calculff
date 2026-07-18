import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_translator.dart';

String offerText(BuildContext context, String source) {
  if (!AppTranslator.isFrench(context)) {
    return source;
  }
  return _offerFrench[source] ?? AppTranslator.translate(context, source);
}

const Map<String, String> _offerFrench = {
  'إدارة العروض العامة': 'Gestion des offres publiques',
  'تحديث العروض': 'Actualiser les offres',
  'إنشاء عرض': 'Créer une offre',
  'جاري تحميل العروض': 'Chargement des offres',
  'لا توجد عروض عامة بعد.': 'Aucune offre publique pour le moment.',
  'أنشئ أول عرض، ثم انشره عندما تكون لعبته فعالة.':
      'Créez la première offre, puis publiez-la lorsque son jeu est actif.',
  'تعذر تحميل العروض بأمان. أعد المحاولة.':
      'Impossible de charger les offres en toute sécurité. Réessayez.',
  'البيانات المعروضة قديمة': 'Les données affichées sont obsolètes',
  'عرض': 'Offre',
  'منشور': 'Publiée',
  'مخفي': 'Masquée',
  'نشر العرض': 'Publier l’offre',
  'العرض ظاهر للزبائن.': 'L’offre est visible pour les clients.',
  'العرض مخفي عن الزبائن.': 'L’offre est masquée pour les clients.',
  'تعديل العرض': 'Modifier l’offre',
  'اللعبة': 'Jeu',
  'غير فعالة': 'Inactif',
  'اختيار اللعبة مطلوب.': 'Le jeu est requis.',
  'اسم العرض بالعربية': 'Nom de l’offre en arabe',
  'اسم العرض بالفرنسية': 'Nom de l’offre en français',
  'كمية المكافأة': 'Quantité de récompense',
  'ترتيب العرض': 'Ordre d’affichage',
  'أدخل صفرًا أو رقمًا موجبًا.': 'Saisissez zéro ou un nombre positif.',
  'لا يمكن نشر عرض تابع للعبة غير فعالة.':
      'Une offre liée à un jeu inactif ne peut pas être publiée.',
  'يمكن حفظ العرض مخفيًا ثم نشره لاحقًا.':
      'L’offre peut être enregistrée masquée puis publiée plus tard.',
  'حفظ العرض': 'Enregistrer l’offre',
  'العرض غير موجود.': 'L’offre est introuvable.',
  'تحقق من بيانات العرض.': 'Vérifiez les données de l’offre.',
  'استجابة المنصة غير صالحة.': 'La réponse de la plateforme est invalide.',
  'المنصة غير متاحة مؤقتًا.': 'La plateforme est temporairement indisponible.',
  'عملية حفظ العرض قيد التنفيذ.':
      'L’enregistrement de l’offre est déjà en cours.',
  'تم تحديث حالة النشر.': 'L’état de publication a été mis à jour.',
  'تم الحفظ، لكن تعذر تحديث القائمة. البيانات المعروضة قديمة.':
      'L’enregistrement a réussi, mais la liste n’a pas pu être actualisée. Les données affichées sont obsolètes.',
  'دج': 'DA',
};
