import 'package:flutter/material.dart' hide Text;






import '../../../core/localization/localized_text.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';

class CalculationSummary extends StatelessWidget {
  const CalculationSummary({
    super.key,
    required this.result,
    required this.settings,
  });

  final CalculationResult result;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    String money(num value) => MoneyFormatter.format(
          value,
          useThousands: settings.useThousands,
        );
    final mode = result.request.mode;
    final isGemSale = mode == CalculationMode.customerAmount ||
        mode == CalculationMode.gems;
    final isDirectProduct = mode == CalculationMode.directProduct;
    return Column(
      children: [
        if (result.warning != null) ...[
          SectionCard(
            title: 'تنبيه',
            icon: Icons.warning_amber_rounded,
            accent: Theme.of(context).colorScheme.error,
            child: Text(result.warning!),
          ),
          const SizedBox(height: 12),
        ],
        if (isDirectProduct) ...[
          SectionCard(
            title: result.request.product?.name ?? 'منتج مباشر',
            icon: Icons.inventory_2_outlined,
            accent: Theme.of(context).colorScheme.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.request.product?.description?.trim().isNotEmpty ??
                    false)
                  Text(result.request.product!.description!),
                if (result.request.product?.description?.trim().isNotEmpty ??
                    false)
                  const SizedBox(height: 10),
                _Rows(
                  rows: [
                    ('الكمية', 'وحدة واحدة'),
                    ('الرصيد المطلوب', '${result.requiredCredit}'),
                    ('سعر البيع الثابت', money(result.chargedAmount)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          title: mode == CalculationMode.credit
              ? 'بيع الرصيد'
              : 'نتيجة العميل',
          icon: Icons.person_outline,
          child: _Rows(
            rows: [
              if (isGemSale) ('عدد الحزم', '${result.units}'),
              if (isGemSale) ('عدد الجواهر', '${result.gems}'),
              if (isGemSale) ('المبلغ المدفوع', money(result.customerPaid)),
              if (isGemSale) ('المبلغ المحتسب', money(result.chargedAmount)),
              if (mode == CalculationMode.customerAmount)
                ('المبلغ المعاد', money(result.customerChange)),
              if (mode == CalculationMode.credit)
                ('سعر البيع الثابت', money(result.chargedAmount)),
              if (!isDirectProduct)
                ('الرصيد المطلوب', '${result.requiredCredit}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'خطة الرصيد',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            children: [
              _Rows(
                rows: [
                  ('من المخزون', '${result.inventoryCreditUsed}'),
                  ('المطلوب شراؤه/تغطيته', '${result.additionalCreditRequired}'),
                  ('الرصيد المشتَرى', '${result.purchasedCredit}'),
                  ('الرصيد المتبقي', '${result.remainingPurchasedCredit}'),
                ],
              ),
              if (result.optimization != null) ...[
                const Divider(height: 28),
                for (final selection in result.optimization!.selections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '×${selection.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selection.package.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(money(selection.totalCost)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'أقصر صلاحية ضمن الخطة: '
                  '${_validity(result.optimization!.minimumValidityHours)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('المخزون الحالي يغطي العملية بالكامل.'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'النتيجة المالية',
          icon: Icons.trending_up,
          accent: result.cashProfit >= 0
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          child: _Rows(
            rows: [
              ('سعر البيع', money(result.chargedAmount)),
              ('تكلفة الرصيد المستعمل', money(result.creditCostUsed)),
              ('المبلغ المدفوع الآن للباقات', money(result.newPackagesCost)),
              ('الربح', money(result.cashProfit)),
              ('هامش الربح', '${result.marginPercent.toStringAsFixed(1)}%'),
            ],
          ),
        ),
      ],
    );
  }

  String _validity(int hours) {
    if (hours >= 24 && hours % 24 == 0) return '${hours ~/ 24} يوم';
    return '$hours ساعة';
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            Row(
              children: [
                Expanded(child: Text(rows[index].$1)),
                Text(
                  rows[index].$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (index != rows.length - 1) const Divider(height: 20),
          ],
        ],
      );
}
