import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
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
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SectionCard(
              title: 'بيانات العميل',
              icon: Icons.person_outline_rounded,
              accent: Theme.of(context).colorScheme.secondary,
              child: TextFormField(
                controller: _customerNameController,
                autofocus: true,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                inputFormatters: [
                  LengthLimitingTextInputFormatter(80),
                ],
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  hintText: 'مثال: إسلام أو محمد',
                  prefixIcon: Icon(Icons.badge_outlined),
                  helperText: 'سيظهر الاسم في السجل وتفاصيل العملية.',
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) return 'اكتب اسم العميل قبل الحفظ';
                  if (normalized.length < 2) {
                    return 'اسم العميل قصير جدًا';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_saving) _save();
                },
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'قبل الحفظ',
              icon: Icons.fact_check_outlined,
              child: const Text(
                'تأكد أن اسم العميل والمبلغ والباقات يعكسون العملية الفعلية. عند الحفظ سيُخصم المخزون وفق FEFO وتُنشأ رزم الرصيد الجديدة.',
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
              label: const Text('حفظ العملية باسم العميل'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _saving ? null : () => context.pop(),
              child: const Text('العودة للنتيجة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = ref.read(calculationProvider);
    if (result == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final id = await ref.read(appRepositoryProvider).saveTransaction(
            result,
            customerName: _customerNameController.text,
          );
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
