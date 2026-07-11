import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/product.dart';
import '../../../shared/providers/app_providers.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  CalculationMode _mode = CalculationMode.customerAmount;
  Product? _product;
  bool _useInventory = true;
  bool _submitting = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String get _inputLabel => switch (_mode) {
        CalculationMode.customerAmount => 'المبلغ المدفوع بالدينار',
        CalculationMode.gems => 'عدد الجواهر المطلوبة',
        CalculationMode.credit => 'الرصيد المطلوب',
      };

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(activeProductsProvider);
    return AppShell(
      title: AppStrings.newCalculation,
      body: AsyncStateView(
        value: products,
        onRetry: () => ref.invalidate(activeProductsProvider),
        data: (items) {
          if (_product == null && items.isNotEmpty) _product = items.first;
          return Form(
            key: _formKey,
            child: ListView(
              children: [
                SectionCard(
                  title: 'طريقة الحساب',
                  icon: Icons.swap_horiz,
                  child: SegmentedButton<CalculationMode>(
                    segments: const [
                      ButtonSegment(value: CalculationMode.customerAmount, label: Text('المبلغ'), icon: Icon(Icons.payments_outlined)),
                      ButtonSegment(value: CalculationMode.gems, label: Text('الجواهر'), icon: Icon(Icons.diamond_outlined)),
                      ButtonSegment(value: CalculationMode.credit, label: Text('الرصيد'), icon: Icon(Icons.toll_outlined)),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() {
                        _mode = selection.first;
                        _valueController.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'المدخلات',
                  icon: Icons.edit_note,
                  child: Column(
                    children: [
                      if (_mode != CalculationMode.credit)
                        DropdownButtonFormField<Product>(
                          initialValue: _product,
                          decoration: const InputDecoration(labelText: 'المنتج'),
                          items: [
                            for (final product in items)
                              DropdownMenuItem(value: product, child: Text(product.name)),
                          ],
                          onChanged: (value) => setState(() => _product = value),
                          validator: (value) => value == null ? 'اختر منتجًا' : null,
                        ),
                      if (_mode != CalculationMode.credit) const SizedBox(height: 12),
                      TextFormField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: _inputLabel,
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) return 'أدخل قيمة صحيحة أكبر من صفر';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('استخدام الرصيد الموجود'),
                        subtitle: const Text('سيُستهلك الأقرب انتهاءً أولًا'),
                        value: _useInventory,
                        onChanged: (value) => setState(() => _useInventory = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _calculate,
                  icon: _submitting
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate_outlined),
                  label: const Text('احسب أفضل نتيجة'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'هذه الأداة لا تنفذ أي شراء أو دفع. النتائج خطة حسابية تُسجّل يدويًا فقط.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(calculationProvider.notifier).calculate(
            CalculationRequest(
              mode: _mode,
              product: _mode == CalculationMode.credit ? null : _product,
              inputValue: int.parse(_valueController.text),
              useInventory: _useInventory,
            ),
          );
      if (mounted) context.push('/calculate/result');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
