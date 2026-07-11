import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_providers.dart';
import 'calculation_summary.dart';

class ConfirmTransactionScreen extends ConsumerStatefulWidget {
  const ConfirmTransactionScreen({super.key});

  @override
  ConsumerState<ConfirmTransactionScreen> createState() =>
      _ConfirmTransactionScreenState();
}

class _ConfirmTransactionScreenState
    extends ConsumerState<ConfirmTransactionScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    if (result == null) {
      return AppShell(
        title: 'تأكيد العملية',
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/calculate'),
            child: const Text('ابدأ من الحاسبة'),
          ),
        ),
      );
    }
    return AppShell(
      title: 'تأكيد العملية',
      body: ListView(
        children: [
          SectionCard(
            title: 'قبل الحفظ',
            icon: Icons.fact_check_outlined,
            accent: Theme.of(context).colorScheme.secondary,
            child: const Text(
              'تأكد أن المبلغ والباقات يعكسان العملية الفعلية. عند الحفظ سيُخصم المخزون وفق FEFO وتُنشأ رزم الرصيد الجديدة.',
            ),
          ),
          const SizedBox(height: 12),
          CalculationSummary(result: result, settings: settings),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('حفظ العملية وتحديث المخزون'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('العودة للنتيجة'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final result = ref.read(calculationProvider);
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(appRepositoryProvider).saveTransaction(result);
      invalidateAppData(ref);
      ref.read(calculationProvider.notifier).clear();
      if (mounted) context.go('/transactions/$id');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
