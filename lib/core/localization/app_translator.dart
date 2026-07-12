import 'package:flutter/widgets.dart';

import 'french_catalog.dart';

abstract final class AppTranslator {
  static bool isFrench(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fr';

  static String translate(BuildContext context, String source) =>
      translateForLanguage(
        source,
        Localizations.localeOf(context).languageCode,
      );

  static String translateForLanguage(String source, String languageCode) {
    if (languageCode != 'fr' || source.trim().isEmpty) return source;

    final exact = _exactFrench[source] ?? additionalFrenchTranslations[source];
    if (exact != null) return exact;

    var result = source;

    final dateRange = RegExp(r'^من\s+(.+)\s+إلى\s+(.+)$').firstMatch(result);
    if (dateRange != null) {
      result = 'Du ${dateRange.group(1)} au ${dateRange.group(2)}';
    }

    result = result
        .replaceAllMapped(
          RegExp(r'(\d+)\s*جوهرة'),
          (match) => '${match.group(1)} gemmes',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)\s*رصيد'),
          (match) => '${match.group(1)} crédits',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)\s*ساعة'),
          (match) => '${match.group(1)} h',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)\s*عملية'),
          (match) => '${match.group(1)} opérations',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)\s*عميل'),
          (match) => '${match.group(1)} clients',
        )
        .replaceAllMapped(
          RegExp(r'(\d+)\s*دج'),
          (match) => '${match.group(1)} DA',
        )
        .replaceAll('٪', '%');

    final phrases = <MapEntry<String, String>>[
      ...additionalFrenchPhrases.entries,
      ..._phraseFrench.entries,
    ]..sort((first, second) => second.key.length.compareTo(first.key.length));
    for (final entry in phrases) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }

  static const Map<String, String> _exactFrench = {
    'مدير رصيد الألعاب': 'Gestionnaire de crédit de jeux',
    'حساب • مخزون • ربح': 'Calcul • Stock • Bénéfice',
    'لوحة المتابعة': 'Tableau de bord',
    'عملية جديدة': 'Nouvelle opération',
    'العملاء': 'Clients',
    'التقارير': 'Rapports',
    'المنتجات': 'Produits',
    'باقات الرصيد': 'Forfaits de crédit',
    'مخزون الرصيد': 'Stock de crédit',
    'سجل العمليات': 'Historique des opérations',
    'الإعدادات': 'Paramètres',
    'النسخ الاحتياطي': 'Sauvegarde',
    'حفظ': 'Enregistrer',
    'إلغاء': 'Annuler',
    'تعديل': 'Modifier',
    'حذف': 'Supprimer',
    'إضافة': 'Ajouter',
    'إعادة المحاولة': 'Réessayer',
    'لا توجد بيانات بعد': 'Aucune donnée pour le moment',
    'تحديث': 'Actualiser',
    'بحث': 'Rechercher',
    'تأكيد': 'Confirmer',
    'إغلاق': 'Fermer',
    'متابعة': 'Continuer',
    'رجوع': 'Retour',
    'التالي': 'Suivant',
    'تم': 'Terminé',
    'الكل': 'Tous',
    'فعّال': 'Actif',
    'قريب': 'Bientôt expiré',
    'منتهي': 'Expiré',
    'مستهلك': 'Épuisé',
    'يدوي': 'Manuel',
    'المبلغ': 'Montant',
    'الجواهر': 'Gemmes',
    'الرصيد': 'Crédit',
    'منتج مباشر': 'Produit direct',
    'المبيعات': 'Ventes',
    'الربح': 'Bénéfice',
    'الربح الصافي': 'Bénéfice net',
    'التكلفة': 'Coût',
    'العمليات': 'Opérations',
    'عدد العمليات': "Nombre d'opérations",
    'عدد العملاء': 'Nombre de clients',
    'متوسط العملية': "Moyenne par opération",
    'متوسط الربح': 'Bénéfice moyen',
    'الرصيد المطلوب': 'Crédit requis',
    'الرصيد المشتَرى': 'Crédit acheté',
    'ملخص تشغيلي': 'Résumé opérationnel',
    'اتجاه المبيعات والربح': 'Évolution des ventes et du bénéfice',
    'أفضل المنتجات': 'Meilleurs produits',
    'أفضل العملاء': 'Meilleurs clients',
    'اليوم': "Aujourd'hui",
    'آخر 7 أيام': '7 derniers jours',
    'هذا الشهر': 'Ce mois-ci',
    'آخر 30 يومًا': '30 derniers jours',
    'كل الوقت': 'Depuis le début',
    'مشاركة أو حفظ التقرير': 'Partager ou enregistrer le rapport',
    'تصدير التقرير': 'Exporter le rapport',
    'اختر الصيغة، ثم شارك التقرير أو احفظ نسخة في الجهاز.':
        'Choisissez le format, puis partagez ou enregistrez une copie sur l’appareil.',
    'ملف جداول قابل للفتح في Excel': 'Fichier de tableau compatible avec Excel',
    'تقرير منظم على صفحات جاهزة للطباعة': 'Rapport paginé prêt à imprimer',
    'صورة طويلة واضحة للمشاركة السريعة':
        'Image longue et nette pour un partage rapide',
    'صورة PNG': 'Image PNG',
    'حفظ في الجهاز': "Enregistrer sur l’appareil",
    'مشاركة': 'Partager',
    'لا مقارنة متاحة': 'Comparaison indisponible',
    'لا توجد بيانات كافية للرسم.': 'Données insuffisantes pour le graphique.',
    'لا توجد منتجات ضمن هذه الفترة.': 'Aucun produit pour cette période.',
    'لا توجد عمليات عملاء ضمن هذه الفترة.':
        'Aucune opération client pour cette période.',
    'لا توجد بيانات ضمن هذه الفترة.': 'Aucune donnée pour cette période.',
    'لا توجد عمليات محفوظة حتى الآن.':
        'Aucune opération enregistrée pour le moment.',
    'لا توجد عمليات محفوظة': 'Aucune opération enregistrée',
    'طريقة الحساب': 'Mode de calcul',
    'المدخلات': 'Données saisies',
    'المبلغ المدفوع بالدينار': 'Montant payé en dinars',
    'عدد الجواهر المطلوبة': 'Nombre de gemmes demandé',
    'وحدة واحدة من المنتج': 'Une unité du produit',
    'منتج الجواهر': 'Produit de gemmes',
    'المنتج المباشر': 'Produit direct',
    'اختر منتجًا': 'Choisissez un produit',
    'أدخل قيمة صحيحة أكبر من صفر':
        'Saisissez une valeur correcte supérieure à zéro',
    'استخدام الرصيد الموجود': 'Utiliser le crédit disponible',
    'سيُستهلك الأقرب انتهاءً أولًا':
        'Le crédit expirant le plus tôt sera utilisé en premier',
    'احسب أفضل نتيجة': 'Calculer le meilleur résultat',
    'لا توجد منتجات متاحة': 'Aucun produit disponible',
    'أضف منتجًا مباشرًا وفعّله من شاشة المنتجات أولًا.':
        "Ajoutez d’abord un produit direct et activez-le depuis l’écran Produits.",
    'أضف منتج جواهر وفعّله من شاشة المنتجات أولًا.':
        "Ajoutez d’abord un produit de gemmes et activez-le depuis l’écran Produits.",
    'هذه الأداة لا تنفذ أي شراء أو دفع. النتائج خطة حسابية تُسجّل يدويًا فقط.':
        "Cet outil n’effectue aucun achat ni paiement. Les résultats sont un plan de calcul enregistré manuellement.",
    'نتيجة الحساب': 'Résultat du calcul',
    'تأكيد العملية': "Confirmer l’opération",
    'اسم العميل': 'Nom du client',
    'عميل غير مسمى': 'Client sans nom',
    'منتج غير مسمى': 'Produit sans nom',
    'بيع رصيد مباشر': 'Vente directe de crédit',
    'إضافة رصيد': 'Ajouter du crédit',
    'خصم رصيد': 'Retirer du crédit',
    'تعديل المخزون يدويًا': 'Ajustement manuel du stock',
    'اسم الرصيد أو مصدره': 'Nom ou source du crédit',
    'كمية الرصيد': 'Quantité de crédit',
    'تكلفة شراء الرصيد بالدينار': "Coût d’achat en dinars",
    'تاريخ ووقت الانتهاء': "Date et heure d’expiration",
    'سبب أو ملاحظة (اختياري)': 'Motif ou note (facultatif)',
    'إضافة رصيد إلى المخزون': 'Ajouter du crédit au stock',
    'خصم رصيد من المخزون': 'Retirer du crédit du stock',
    'كمية الرصيد المراد خصمها': 'Quantité de crédit à retirer',
    'سبب الخصم أو الحذف': 'Motif du retrait ou de la suppression',
    'اكتب سبب الخصم': 'Saisissez le motif du retrait',
    'تأكيد الخصم': 'Confirmer le retrait',
    'لا توجد رزم ضمن هذا التصنيف.': 'Aucun lot dans cette catégorie.',
    'اضغط لعرض سجل الحركة': 'Appuyez pour afficher les mouvements',
    'سجل الإضافة والاستهلاك والخصم':
        'Historique des ajouts, consommations et retraits',
    'لا توجد حركات مسجلة لهذه الرزمة.':
        'Aucun mouvement enregistré pour ce lot.',
    'الأمان والخصوصية': 'Sécurité et confidentialité',
    'المظهر وطريقة العرض': 'Apparence et affichage',
    'اتباع سمة الهاتف تلقائيًا': 'Suivre automatiquement le thème du téléphone',
    'عند تفعيله، يفتح التطبيق داكنًا أو فاتحًا حسب إعداد الهاتف.':
        "Lorsque cette option est activée, l’application suit le thème clair ou sombre du téléphone.",
    'الوضع الداكن': 'Mode sombre',
    'يتبع الهاتف حاليًا. تغييره يثبت اختيارك يدويًا.':
        'Le thème suit actuellement le téléphone. Le modifier fixe votre choix manuellement.',
    'تغيير مظهر التطبيق فقط':
        "Modifier uniquement l’apparence de l’application",
    'عرض المبالغ بصيغة الألف': 'Afficher les montants en milliers',
    'تسعير بيع الرصيد': 'Tarification de vente du crédit',
    'قاعدة مشتركة لبيع الرصيد والمنتجات المباشرة، مع التقريب إلى أقرب 10 دج.':
        'Règle commune pour le crédit et les produits directs, arrondie aux 10 DA les plus proches.',
    'تنبيهات الصلاحية': "Alertes d’expiration",
    'التنبيه قبل الانتهاء': "Alerter avant l’expiration",
    'البيانات': 'Données',
    'النسخ الاحتياطي والاستعادة': 'Sauvegarde et restauration',
    'تصدير أو استيراد ملف JSON محلي':
        'Exporter ou importer un fichier JSON local',
    'حدود التطبيق': "Limites de l’application",
    'لا يتصل التطبيق بدجيزي أو الألعاب ولا ينفذ شراءً أو دفعًا. جميع الأرقام والعمليات تُدخل وتُراجع يدويًا.':
        "L’application ne se connecte ni à Djezzy ni aux jeux et n’effectue aucun achat ou paiement. Toutes les valeurs et opérations sont saisies et vérifiées manuellement.",
    'قفل التطبيق بنمط': "Verrouillage de l’application par schéma",
    'سيطلب التطبيق النمط عند الفتح أو العودة من الخلفية.':
        "Le schéma sera demandé à l’ouverture ou au retour depuis l’arrière-plan.",
    'ميزة اختيارية لحماية العملاء والعمليات المالية.':
        'Fonction facultative pour protéger les clients et les opérations financières.',
    'تغيير نمط القفل': 'Modifier le schéma',
    'قفل التطبيق الآن': "Verrouiller l’application maintenant",
    'مدة التنبيه': "Délai d’alerte",
    'عدد الساعات قبل الانتهاء': "Nombre d’heures avant expiration",
    'الرصيد المرجعي': 'Crédit de référence',
    'سعر البيع المرجعي بالدينار': 'Prix de vente de référence en dinars',
    'يُحسب سعر أي كمية أو منتج مباشر نسبيًا، ثم يُقرّب إلى أقرب 10 دج.':
        'Le prix de toute quantité ou produit direct est calculé proportionnellement, puis arrondi aux 10 DA les plus proches.',
    'اللغة': 'Langue',
    'لغة التطبيق': "Langue de l’application",
    'العربية': 'Arabe',
    'الفرنسية': 'Français',
    'Français': 'Français',
    'اختيار اللغة': 'Choisir la langue',
    'سيصبح اتجاه التطبيق من اليسار إلى اليمين.':
        "L’application passera en affichage de gauche à droite.",
    'سيصبح اتجاه التطبيق من اليمين إلى اليسار.':
        "L’application passera en affichage de droite à gauche.",
    'النسخة الاحتياطية': 'Sauvegarde',
    'تصدير نسخة احتياطية': 'Exporter une sauvegarde',
    'استيراد نسخة احتياطية': 'Importer une sauvegarde',
    'اختيار ملف': 'Choisir un fichier',
    'إنشاء نسخة احتياطية': 'Créer une sauvegarde',
    'استعادة البيانات': 'Restaurer les données',
    'المنتج': 'Produit',
    'الباقة': 'Forfait',
    'السعر': 'Prix',
    'الكمية': 'Quantité',
    'الصلاحية': 'Validité',
    'الحالة': 'État',
    'الوصف': 'Description',
    'الهاتف': 'Téléphone',
    'ملاحظات': 'Notes',
    'التاريخ': 'Date',
    'التفاصيل': 'Détails',
    'نسخ': 'Copier',
    'مفعّل': 'Activé',
    'غير مفعّل': 'Désactivé',
  };

  static const Map<String, String> _phraseFrench = {
    'تم الحفظ بنجاح': 'Enregistré avec succès',
    'تمت الإضافة بنجاح': 'Ajout effectué avec succès',
    'تم التعديل بنجاح': 'Modification effectuée avec succès',
    'تم الحذف بنجاح': 'Suppression effectuée avec succès',
    'تم حفظ': 'Enregistré : ',
    'تم إنشاء': 'Créé : ',
    'تمت إضافة': 'Ajouté : ',
    'تم خصم': 'Retiré : ',
    'تعذر': 'Impossible de ',
    'خطأ': 'Erreur',
    'لا توجد': 'Aucun élément : ',
    'أدخل': 'Saisissez ',
    'اختر': 'Choisissez ',
    'اسم': 'Nom',
    'سعر': 'Prix',
    'تكلفة': 'Coût',
    'ربح': 'Bénéfice',
    'مبيعات': 'Ventes',
    'رصيد': 'crédit',
    'جوهرة': 'gemme',
    'جواهر': 'gemmes',
    'عملية': 'opération',
    'عمليات': 'opérations',
    'عميل': 'client',
    'عملاء': 'clients',
    'منتج': 'produit',
    'منتجات': 'produits',
    'باقة': 'forfait',
    'باقات': 'forfaits',
    'مخزون': 'stock',
    'منتهي': 'expiré',
    'فعّال': 'actif',
    'متبقٍ': 'restant',
    'المتاح': 'disponible',
    'المطلوب': 'requis',
    'المشتَرى': 'acheté',
    'اليوم': "aujourd’hui",
    'ساعة': 'heure',
    'تاريخ الانتهاء': "date d’expiration",
    'وقت الانتهاء': "heure d’expiration",
    'إعادة المحاولة': 'Réessayer',
    'إلغاء': 'Annuler',
    'حفظ': 'Enregistrer',
    'حذف': 'Supprimer',
    'تعديل': 'Modifier',
    'إضافة': 'Ajouter',
    'مشاركة': 'Partager',
    'تصدير': 'Exporter',
    'استيراد': 'Importer',
    'السابقة': 'précédente',
    'دج': 'DA',
  };
}
