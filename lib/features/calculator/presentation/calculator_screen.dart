import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/product.dart';
import '../../../shared/providers/app_providers.dart';
import '../application/credit_sale_pricing.dart';

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
        CalculationMode.directProduct => 'وحدة واحدة من المنتج',
      };

  bool get _requiresInput => _mode != CalculationMode.directProduct;
  bool get _requiresProduct =>
      _mode != CalculationMode.credit;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(activeProductsProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final pricing = CreditSalePricing(
      referenceCredit: settings.creditSaleReferenceCredit,
      referencePriceDzd: settings.creditSaleReferencePriceDzd,
    );
    return AppShell(
      title: AppStrings.newCalculation,
      body: AsyncStateView(
        value: products,
        onRetry: () => ref.invalidate(activeProductsProvider),
        data: (items) {
          final relevantProducts = items.where((product) {
            if (_mode == CalculationMode.directProduct) {
              return product.isDirectProduct;
            }
            if (_mode == CalculationMode.credit) return false;
            return product.isGemProduct;
          }).toList(growable: false);
          if (_requiresProduct &&
              (_product == null || !relevantProducts.contains(_product))) {
            _product = relevantProducts.isEmpty ? null : relevantProducts.first;
          }
          final selectedDirect = _mode == CalculationMode.directProduct
              ? _product
              : null;

          return Form(
            key: _formKey,
            child: ListView(
              children: [
                SectionCard(
                  title: 'طريقة الحساب',
                  icon: Icons.swap_horiz,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<CalculationMode>(
                      segments: const [
                        ButtonSegment(
                          value: CalculationMode.customerAmount,
                          label: Text('المبلغ'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                        ButtonSegment(
                          value: CalculationMode.gems,
                          label: Text('الجواهر'),
                          icon: Icon(Icons.diamond_outlined),
                        ),
                        ButtonSegment(
                          value: CalculationMode.credit,
                          label: Text('الرصيد'),
                          icon: Icon(Icons.toll_outlined),
                        ),
                        ButtonSegment(
                          value: CalculationMode.directProduct,
                          label: Text('منتج مباشر'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                      ],
                      selected: {_mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() {
                          _mode = selection.first;
                          _valueController.clear();
                          _product = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'المدخلات',
                  icon: Icons.edit_note,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_requiresProduct)
                        DropdownButtonFormField<Product>(
                          key: ValueKey('${_mode.name}-${_product?.id}'),
                          initialValue: _product,
                          decoration: InputDecoration(
                            labelText: _mode == CalculationMode.directProduct
                                ? 'المنتج المباشر'
                                : 'منتج الجواهر',
                          ),
                          items: [
                            for (final product in relevantProducts)
                              DropdownMenuItem(
                                value: product,
                                child: Text(product.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _product = value),
                          validator: (value) =>
                              value == null ? 'اختر منتجًا' : null,
                        ),
                      if (_requiresProduct) const SizedBox(height: 12),
                      if (_requiresInput)
                        TextFormField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: _inputLabel,
                            prefixIcon: const Icon(Icons.pin_outlined),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'أدخل قيمة صحيحة أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                      if (selectedDirect != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDirect.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (selectedDirect.description?.trim().isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 6),
                                Text(selectedDirect.description!),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '${selectedDirect.creditPerUnit} رصيد • '
                                '${MoneyFormatter.format(pricing.priceFor(selectedDirect.creditPerUnit), useThousands: settings.useThousands)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_mode == CalculationMode.credit) ...[
                        const SizedBox(height: 10),
                        Text(
                          'سعر البيع ثابت حسب الإعداد الحالي: '
                          '${settings.creditSaleReferenceCredit} رصيد = '
                          '${MoneyFormatter.format(settings.creditSaleReferencePriceDzd, useThousands: settings.useThousands)}، '
                          'مع التقريب إلى أقرب 10 دج.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('استخدام الرصيد الموجود'),
                        subtitle: const Text('سيُستهلك الأقرب انتهاءً أولًا'),
                        value: _useInventory,
                        onChanged: (value) =>
                            setState(() => _useInventory = value),
                      ),
                    ],
                  ),
                ),
                if (_requiresProduct && relevantProducts.isEmpty) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'لا توجد منتجات متاحة',
                    icon: Icons.info_outline,
                    child: Text(
                      _mode == CalculationMode.directProduct
                          ? 'أضف منتجًا مباشرًا وفعّله من شاشة المنتجات أولًا.'
                          : 'أضف منتج جواهر وفعّله من شاشة المنتجات أولًا.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ||
                          (_requiresProduct && relevantProducts.isEmpty)
                      ? null
                      : _calculate,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
              product: _requiresProduct ? _product : null,
              inputValue: _mode == CalculationMode.directProduct
                  ? 1
                  : int.parse(_valueController.text),
              useInventory: _useInventory,
            ),
          );
      if (mounted) context.push('/calculate/result');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
