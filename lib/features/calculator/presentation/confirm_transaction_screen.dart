import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';



import '../../../core/localization/localized_text.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/customer_autocomplete.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/customer.dart';
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
  final _customerFocusNode = FocusNode();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(calculationProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final customers = ref.watch(activeCustomersProvider);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  customers.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('تعذر تحميل العملاء: $error'),
                        TextButton.icon(
                          onPressed: () =>
                              ref.invalidate(activeCustomersProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                    data: (items) => CustomerAutocomplete(
                      controller: _customerNameController,
                      focusNode: _customerFocusNode,
                      customers: items,
                      enabled: !_saving,
                      autofocus: true,
                      onSelected: _selectCustomer,
                      onTextChanged: _customerTextChanged,
                      validator: _validateCustomer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => context.push('/customers'),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('إدارة العملاء'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'قبل الحفظ',
              icon: Icons.fact_check_outlined,
              child: const Text(
                'تأكد أن العميل والمبلغ والباقات يعكسون العملية الفعلية. عند الحفظ سيُخصم المخزون وفق FEFO وتُنشأ رزم الرصيد الجديدة.',
              ),
            ),
            const SizedBox(height: 12),
            CalculationSummary(result: result, settings: settings),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || customers.isLoading ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('حفظ العملية'),
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

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomerId = customer.id;
      _selectedCustomerName = customer.name;
      _customerNameController.text = customer.name;
      _customerNameController.selection = TextSelection.collapsed(
        offset: customer.name.length,
      );
    });
  }

  void _customerTextChanged(String value) {
    if (_selectedCustomerName == null) return;
    if (value.trim().toLowerCase() ==
        _selectedCustomerName!.trim().toLowerCase()) {
      return;
    }
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerName = null;
    });
  }

  String? _validateCustomer(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'اختر العميل أو اكتب اسمه';
    if (normalized.length < 2) return 'اسم العميل قصير جدًا';
    return null;
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
            customerId: _selectedCustomerId,
          );
      invalidateAppData(ref);
      ref.read(calculationProvider.notifier).clear();
      if (mounted) context.go('/transactions/$id?undo=1');
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
