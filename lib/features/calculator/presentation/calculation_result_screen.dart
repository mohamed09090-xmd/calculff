import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/providers/app_providers.dart';
import '../application/calculation_draft_engine.dart';
import 'calculation_customization_editor.dart';

class CalculationResultScreen extends ConsumerStatefulWidget {
  const CalculationResultScreen({super.key});

  @override
  ConsumerState<CalculationResultScreen> createState() =>
      _CalculationResultScreenState();
}

class _CalculationResultScreenState
    extends ConsumerState<CalculationResultScreen> {
  static const _engine = CalculationDraftEngine();
  CalculationDraft? _draft;
  CalculationResult? _sourceResult;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationProvider);
    final packages = ref.watch(activePackagesProvider);
    final inventory = ref.watch(activeInventoryCreditProvider);
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

    if (packages.isLoading || inventory.isLoading) {
      return const AppShell(
        title: 'نتيجة الحساب',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (packages.hasError || inventory.hasError) {
      final error = packages.error ?? inventory.error;
      return AppShell(
        title: 'نتيجة الحساب',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تعذر تحميل بيانات التخصيص: $error'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ref
                    ..invalidate(activePackagesProvider)
                    ..invalidate(activeInventoryCreditProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (!identical(_sourceResult, result) || _draft == null) {
      _sourceResult = result;
      _draft = _engine.fromResult(
        result,
        packages: packages.requireValue,
        availableInventoryCredit: inventory.requireValue,
      );
    }
    final draft = _draft!;
    final issues = _engine.validate(draft);

    return AppShell(
      title: 'نتيجة الحساب',
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          CalculationCustomizationEditor(
            draft: draft,
            settings: settings,
            onChanged: (next) => setState(() => _draft = next),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: issues.isEmpty ? _reviewAndSave : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('مراجعة وحفظ العملية'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('العودة إلى المدخلات'),
          ),
        ],
      ),
    );
  }

  void _reviewAndSave() {
    final draft = _draft;
    if (draft == null) return;
    try {
      final result = _engine.finalize(draft);
      ref.read(calculationProvider.notifier).setResult(result);
      context.push('/calculate/confirm');
    } on CalculationDraftValidationException catch (error) {
      final french = Localizations.localeOf(context).languageCode == 'fr';
      final message = error.issues
          .map((issue) => french ? issue.messageFr : issue.messageAr)
          .join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
