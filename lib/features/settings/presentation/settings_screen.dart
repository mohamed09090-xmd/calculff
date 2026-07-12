import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_lock_state.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_lock_provider.dart';
import '../../../shared/providers/app_providers.dart';
import '../../security/presentation/pattern_management_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final appLock = ref.watch(appLockProvider);
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
              title: 'المظهر وطريقة العرض',
              icon: Icons.palette_outlined,
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.brightness_auto_outlined),
                    title: Text('سمة التطبيق'),
                    subtitle: Text(
                      'تتبع سمة الهاتف تلقائيًا: داكنة مع الهاتف الداكن وفاتحة مع الهاتف الفاتح.',
                    ),
                    trailing: Icon(Icons.phone_android_outlined),
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
          decoration: const InputDecoration(
            labelText: 'عدد الساعات قبل الانتهاء',
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
