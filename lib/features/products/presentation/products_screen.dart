import 'package:flutter/material.dart' hide Text;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../calculator/application/credit_sale_pricing.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/product.dart';
import '../../../shared/providers/app_providers.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final pricing = CreditSalePricing(
      referenceCredit: settings.creditSaleReferenceCredit,
      referencePriceDzd: settings.creditSaleReferencePriceDzd,
    );
    return AppShell(
      title: AppStrings.products,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      body: AsyncStateView(
        value: products,
        onRetry: () => ref.invalidate(productsProvider),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('لا توجد منتجات.'));
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = items[index];
              final subtitle = product.isDirectProduct
                  ? 'منتج مباشر • ${product.creditPerUnit} رصيد • '
                      '${MoneyFormatter.format(pricing.priceFor(product.creditPerUnit), useThousands: settings.useThousands)}'
                  : '${product.gemsPerUnit} جوهرة • '
                      '${product.creditPerUnit} رصيد • '
                      '${MoneyFormatter.format(product.salePriceDzd, useThousands: settings.useThousands)}';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      !product.isActive
                          ? Icons.block
                          : product.isDirectProduct
                              ? Icons.inventory_2_outlined
                              : Icons.diamond_outlined,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (product.isDirectProduct)
                        const Chip(label: Text('مباشر')),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subtitle),
                      if (product.description?.trim().isNotEmpty ?? false)
                        Text(
                          product.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Switch(
                    value: product.isActive,
                    onChanged: (value) =>
                        _save(ref, product.copyWith(isActive: value)),
                  ),
                  onTap: () => _openEditor(context, ref, product),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _save(WidgetRef ref, Product product) async {
    await ref.read(appRepositoryProvider).saveProduct(product);
    ref
      ..invalidate(productsProvider)
      ..invalidate(activeProductsProvider);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, [
    Product? product,
  ]) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductDialog(product: product),
    );
    if (result != null) await _save(ref, result);
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _gems;
  late final TextEditingController _credit;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late ProductType _type;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _gems = TextEditingController(
      text: product?.isGemProduct == true
          ? product!.gemsPerUnit.toString()
          : '',
    );
    _credit = TextEditingController(
      text: product?.creditPerUnit.toString() ?? '',
    );
    _price = TextEditingController(
      text: product?.isGemProduct == true
          ? product!.salePriceDzd.toString()
          : '',
    );
    _description = TextEditingController(text: product?.description ?? '');
    _type = product?.type ?? ProductType.gems;
    _active = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _gems.dispose();
    _credit.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل المنتج'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<ProductType>(
                segments: const [
                  ButtonSegment(
                    value: ProductType.gems,
                    label: Text('جواهر'),
                    icon: Icon(Icons.diamond_outlined),
                  ),
                  ButtonSegment(
                    value: ProductType.direct,
                    label: Text('مباشر'),
                    icon: Icon(Icons.inventory_2_outlined),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.first);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'الاسم مطلوب'
                    : null,
              ),
              const SizedBox(height: 10),
              if (_type == ProductType.gems) ...[
                _numberField(_gems, 'الجواهر في الحزمة'),
                const SizedBox(height: 10),
              ],
              _numberField(
                _credit,
                _type == ProductType.direct
                    ? 'الرصيد المطلوب لتنفيذ المنتج'
                    : 'الرصيد المطلوب للحزمة',
              ),
              if (_type == ProductType.gems) ...[
                const SizedBox(height: 10),
                _numberField(_price, 'سعر البيع بالدينار'),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'الوصف أو الملاحظات (اختياري)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_type == ProductType.direct)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'سعر البيع يُحسب تلقائيًا من قاعدة تسعير الرصيد في الإعدادات، ولا يُحفظ سعر مستقل لهذا المنتج.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('منتج فعّال'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        return parsed == null || parsed <= 0
            ? 'أدخل رقمًا أكبر من صفر'
            : null;
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.product;
    final description = _description.text.trim();
    Navigator.pop(
      context,
      Product(
        id: old?.id ?? IdGenerator.next('product'),
        name: _name.text.trim(),
        type: _type,
        gemsPerUnit:
            _type == ProductType.gems ? int.parse(_gems.text) : 0,
        creditPerUnit: int.parse(_credit.text),
        salePriceDzd:
            _type == ProductType.gems ? int.parse(_price.text) : 0,
        description: description.isEmpty ? null : description,
        isActive: _active,
        createdAt: old?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
