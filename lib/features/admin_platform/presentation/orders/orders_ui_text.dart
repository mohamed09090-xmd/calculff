import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_translator.dart';

String orderText(BuildContext context, String arabic) {
  if (Localizations.localeOf(context).languageCode == 'fr') {
    return _french[arabic] ?? arabic;
  }
  return AppTranslator.translate(context, arabic);
}

const Map<String, String> _french = <String, String>{
  'الطلبات': 'Commandes',
  'قائمة الطلبات': 'Liste des commandes',
  'تحديث الطلبات': 'Actualiser les commandes',
  'الفلاتر': 'Filtres',
  'تطبيق الفلاتر': 'Appliquer les filtres',
  'مسح الفلاتر': 'Effacer les filtres',
  'بحث': 'Recherche',
  'ابحث باسم الزبون أو Player ID': 'Rechercher par client ou Player ID',
  'حالة الطلب': 'Statut de la commande',
  'حالة الدفع': 'Statut du paiement',
  'طريقة الدفع': 'Mode de paiement',
  'اللعبة': 'Jeu',
  'الكل': 'Tous',
  'من تاريخ': 'À partir du',
  'إلى تاريخ': 'Jusqu’au',
  'تحميل المزيد': 'Charger plus',
  'لا توجد طلبات.': 'Aucune commande.',
  'لا توجد نتائج مطابقة للفلاتر الحالية.':
      'Aucun résultat ne correspond aux filtres actuels.',
  'لا يوجد اتصال بالمنصة.': 'Connexion à la plateforme indisponible.',
  'تعذر تحميل الطلبات.': 'Impossible de charger les commandes.',
  'إعادة المحاولة': 'Réessayer',
  'البيانات المعروضة قديمة.': 'Les données affichées sont obsolètes.',
  'طلب': 'Commande',
  'الزبون': 'Client',
  'الاسم داخل اللعبة': 'Nom dans le jeu',
  'الكمية': 'Quantité',
  'السعر': 'Prix',
  'وقت الإنشاء': 'Créée le',
  'يوجد إثبات دفع': 'Preuve de paiement disponible',
  'لا يوجد إثبات دفع': 'Aucune preuve de paiement',
  'نقدًا': 'Espèces',
  'تحويل': 'Virement',
  'جديد': 'Nouvelle',
  'مقبول': 'Acceptée',
  'قيد المعالجة': 'En traitement',
  'مكتمل': 'Terminée',
  'مرفوض': 'Refusée',
  'ملغى': 'Annulée',
  'بانتظار الدفع': 'En attente de paiement',
  'قيد المراجعة': 'En cours de vérification',
  'مدفوع': 'Payée',
  'إثبات مرفوض': 'Preuve refusée',
  'استرداد معلق': 'Remboursement en attente',
  'مسترد': 'Remboursée',
  'إلغاء': 'Annuler',
};
