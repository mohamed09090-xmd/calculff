import 'package:flutter/material.dart' hide Text;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../../core/localization/localized_text.dart';

import '../../../core/localization/app_translator.dart';


import '../../../core/constants/app_strings.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_lock_state.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_lock_provider.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/app_language_provider.dart';
import '../../../shared/providers/theme_mode_provider.dart';
import '../../security/presentation/pattern_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final appLock = ref.watch(appLockProvider);
    final themePreference = ref.watch(themeModeProvider).valueOrNull ??
        AppThemeModePreference.system;
    final languagePreference =
        ref.watch(appLanguageProvider).valueOrNull ??
            AppLanguagePreference.arabic;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    return AppShell(
      title: AppStrings.settings,
      body: AsyncStateView(
        value: settings,
        onRetry: () => ref.invalidate(settingsProvider),
        data: (data) => ListView(
          children: [
            SectionCard(
              title: 'الأمان والخصوصية',
              icon: Icons.security_outlined,
              accent: Theme.of(context).colorScheme.secondary,
              child: appLock.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: LinearProgressIndicator(),
                ),
                error: (error, stack) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تعذر قراءة إعدادات القفل: $error'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(appLockProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
                data: (lock) => _SecuritySettings(
                  lock: lock,
                  onToggle: (enabled) =>
                      _togglePatternLock(context, enabled),
                  onChange: () => _openPatternFlow(
                    context,
                    PatternManagementMode.change,
                  ),
                  onLockNow: () {
                    ref.read(appLockProvider.notifier).lock();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'اللغة',
              icon: Icons.language_outlined,
              accent: Theme.of(context).colorScheme.secondary,
              child: SegmentedButton<AppLanguagePreference>(
                segments: const [
                  ButtonSegment(
                    value: AppLanguagePreference.arabic,
                    label: Text('العربية'),
                    icon: Icon(Icons.format_textdirection_r_to_l),
                  ),
                  ButtonSegment(
                    value: AppLanguagePreference.french,
                    label: Text('الفرنسية'),
                    icon: Icon(Icons.format_textdirection_l_to_r),
                  ),
                ],
                selected: {languagePreference},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(appLanguageProvider.notifier)
                    .setLanguage(selection.first),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'المظهر وطريقة العرض',
              icon: Icons.palette_outlined,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.brightness_auto_outlined),
                    title: const Text('اتباع سمة الهاتف تلقائيًا'),
                    subtitle: const Text(
                      'عند تفعيله، يفتح التطبيق داكنًا أو فاتحًا حسب إعداد الهاتف.',
                    ),
                    value:
                        themePreference == AppThemeModePreference.system,
                    onChanged: (value) => ref
                        .read(themeModeProvider.notifier)
                        .followSystem(value, platformBrightness),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الوضع الداكن'),
                    subtitle: Text(
                      themePreference == AppThemeModePreference.system
                          ? 'يتبع الهاتف حاليًا. تغييره يثبت اختيارك يدويًا.'
                          : 'تغيير مظهر التطبيق فقط',
                    ),
                    value: themePreference.isDark(platformBrightness),
                    onChanged: (value) => ref
                        .read(themeModeProvider.notifier)
                        .setDarkMode(value),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('عرض المبالغ بصيغة الألف'),
                    subtitle: Text(
                      data.useThousands ? 'مثال: 35 ألف' : 'مثال: 350 دج',
                    ),
                    value: data.useThousands,
                    onChanged: (value) =>
                        _update(ref, data.copyWith(useThousands: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'تسعير بيع الرصيد',
              icon: Icons.price_change_outlined,
              accent: Theme.of(context).colorScheme.secondary,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${data.creditSaleReferenceCredit} رصيد = '
                  '${MoneyFormatter.format(data.creditSaleReferencePriceDzd, useThousands: data.useThousands)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'قاعدة مشتركة لبيع الرصيد والمنتجات المباشرة، مع التقريب إلى أقرب 10 دج.',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editCreditPricing(context, ref, data),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'تنبيهات الصلاحية',
              icon: Icons.notifications_active_outlined,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التنبيه قبل الانتهاء'),
                subtitle: Text('${data.expiryWarningHours} ساعة'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editWarning(context, ref, data),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'البيانات',
              icon: Icons.storage_outlined,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('النسخ الاحتياطي والاستعادة'),
                subtitle: const Text('تصدير أو استيراد ملف JSON محلي'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.go('/backup'),
              ),
            ),
            const SizedBox(height: 12),
            const SectionCard(
              title: 'حدود التطبيق',
              icon: Icons.verified_user_outlined,
              child: Text(
                'لا يتصل التطبيق بدجيزي أو الألعاب ولا ينفذ شراءً أو دفعًا. جميع الأرقام والعمليات تُدخل وتُراجع يدويًا.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePatternLock(
    BuildContext context,
    bool enabled,
  ) async {
    await _openPatternFlow(
      context,
      enabled
          ? PatternManagementMode.enable
          : PatternManagementMode.disable,
    );
  }

  Future<void> _openPatternFlow(
    BuildContext context,
    PatternManagementMode mode,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PatternManagementScreen(mode: mode),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (mode) {
              PatternManagementMode.enable => 'تم تفعيل قفل التطبيق بالنمط.',
              PatternManagementMode.change => 'تم تغيير نمط القفل.',
              PatternManagementMode.disable => 'تم إيقاف قفل التطبيق.',
            },
          ),
        ),
      );
    }
  }

  Future<void> _update(WidgetRef ref, AppSettings settings) =>
      ref.read(settingsProvider.notifier).save(settings);

  Future<void> _editCreditPricing(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final creditController = TextEditingController(
      text: '${settings.creditSaleReferenceCredit}',
    );
    final priceController = TextEditingController(
      text: '${settings.creditSaleReferencePriceDzd}',
    );
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسعير بيع الرصيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: creditController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: AppTranslator.translate(context, 'الرصيد المرجعي'),
                prefixIcon: Icon(Icons.toll_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: AppTranslator.translate(context, 'سعر البيع المرجعي بالدينار'),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'يُحسب سعر أي كمية أو منتج مباشر نسبيًا، ثم يُقرّب إلى أقرب 10 دج.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final credit = int.tryParse(creditController.text);
              final price = int.tryParse(priceController.text);
              if (credit == null || credit <= 0 || price == null || price <= 0) {
                return;
              }
              Navigator.pop(context, (credit, price));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    creditController.dispose();
    priceController.dispose();
    if (result != null) {
      await _update(
        ref,
        settings.copyWith(
          creditSaleReferenceCredit: result.$1,
          creditSaleReferencePriceDzd: result.$2,
        ),
      );
    }
  }

  Future<void> _editWarning(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(
      text: '${settings.expiryWarningHours}',
    );
    final hours = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مدة التنبيه'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: AppTranslator.translate(context, 'عدد الساعات قبل الانتهاء'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hours != null) {
      await _update(
        ref,
        settings.copyWith(expiryWarningHours: hours),
      );
    }
  }
}

class _SecuritySettings extends StatelessWidget {
  const _SecuritySettings({
    required this.lock,
    required this.onToggle,
    required this.onChange,
    required this.onLockNow,
  });

  final AppLockState lock;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChange;
  final VoidCallback onLockNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('قفل التطبيق بنمط'),
          subtitle: Text(
            lock.enabled
                ? 'سيطلب التطبيق النمط عند الفتح أو العودة من الخلفية.'
                : 'ميزة اختيارية لحماية العملاء والعمليات المالية.',
          ),
          value: lock.enabled,
          onChanged: onToggle,
        ),
        if (lock.enabled) ...[
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gesture_outlined),
            title: const Text('تغيير نمط القفل'),
            subtitle: const Text('يتطلب رسم النمط الحالي أولًا'),
            trailing: const Icon(Icons.chevron_left),
            onTap: onChange,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_clock_outlined),
            title: const Text('قفل التطبيق الآن'),
            subtitle: const Text('اختبار شاشة القفل مباشرة'),
            trailing: const Icon(Icons.lock_outline),
            onTap: onLockNow,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'النمط لا يدخل ضمن ملف النسخة الاحتياطية. نسيانه يتطلب مسح بيانات التطبيق أو إعادة تثبيته.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
