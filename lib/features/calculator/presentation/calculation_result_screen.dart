import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/providers/app_providers.dart';
import 'calculation_summary.dart';

class CalculationResultScreen extends ConsumerWidget {
  const CalculationResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(calculationProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    if (result == null) {
      return AppShell(
        title: 'نتيجة الحساب',
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/calculate'),
            child: const Text('ابدأ حسابًا جديدًا'),
          ),
        ),
      );
    }
    final exactGems = result.request.mode != CalculationMode.gems ||
        result.gems == result.request.inputValue;
    final savable = result.requiredCredit > 0 &&
        result.units > 0 &&
        exactGems;
    return AppShell(
      title: 'نتيجة الحساب',
      body: ListView(
        children: [
          CalculationSummary(result: result, settings: settings),
          const SizedBox(height: 18),
          if (savable)
            FilledButton.icon(
              onPressed: () => context.push('/calculate/confirm'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('مراجعة وحفظ العملية'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.go('/calculate'),
              icon: const Icon(Icons.restart_alt),
              label: const Text('حساب جديد'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('تعديل المدخلات'),
          ),
        ],
      ),
    );
  }
}
