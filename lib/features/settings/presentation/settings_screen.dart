import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return AppShell(
      title: AppStrings.settings,
      body: AsyncStateView(
        value: settings,
        onRetry: () => ref.invalidate(settingsProvider),
        data: (data) => ListView(
          children: [
            SectionCard(
              title: 'المظهر وطريقة العرض',
              icon: Icons.palette_outlined,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الوضع الداكن'),
                    subtitle: const Text('تغيير مظهر التطبيق فقط'),
                    value: data.darkMode,
                    onChanged: (value) => _update(ref, data.copyWith(darkMode: value)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('عرض المبالغ بصيغة الألف'),
                    subtitle: Text(data.useThousands ? 'مثال: 35 ألف' : 'مثال: 350 دج'),
                    value: data.useThousands,
                    onChanged: (value) => _update(ref, data.copyWith(useThousands: value)),
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

  Future<void> _update(WidgetRef ref, AppSettings settings) =>
      ref.read(settingsProvider.notifier).update(settings);

  Future<void> _editWarning(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(text: '${settings.expiryWarningHours}');
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (hours != null) await _update(ref, settings.copyWith(expiryWarningHours: hours));
  }
}
