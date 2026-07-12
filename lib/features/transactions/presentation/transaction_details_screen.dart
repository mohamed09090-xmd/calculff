import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/transaction_details.dart';
import '../../../shared/providers/app_providers.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: 'تفاصيل العملية',
      actions: [
        IconButton(
          tooltip: 'حذف العملية',
          onPressed: () => _delete(context, ref),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: FutureBuilder<TransactionDetails>(
        future: ref
            .read(appRepositoryProvider)
            .getTransactionDetails(transactionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final details = snapshot.data!;
          final item = details.transaction;
          String money(num value) => MoneyFormatter.format(
                value,
                useThousands: settings.useThousands,
              );
          final productName = item.productNameSnapshot ?? 'عملية رصيد';

          return ListView(
            children: [
              SectionCard(
                title: item.customerName,
                icon: Icons.person_outline_rounded,
                accent: Theme.of(context).colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(AppDateUtils.format(item.createdAt)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'بيانات العملية',
                icon: Icons.receipt_long_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('المنتج', productName),
                    const Divider(height: 24),
                    _row('الحزم', '${item.units}'),
                    _row('الجواهر', '${item.gems}'),
                    _row('المبلغ المدفوع', money(item.customerPaid)),
                    _row('المبلغ المحتسب', money(item.chargedAmount)),
                    _row('المبلغ المعاد', money(item.customerChange)),
                    _row('الرصيد المطلوب', '${item.requiredCredit}'),
                    _row('من المخزون', '${item.inventoryCreditUsed}'),
                    _row(
                      'من الباقات الجديدة',
                      '${item.additionalCreditRequired}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'الباقات المشتراة',
                icon: Icons.inventory_2_outlined,
                child: details.items.isEmpty
                    ? const Text('لم تحتج العملية إلى باقات جديدة.')
                    : Column(
                        children: [
                          for (final package in details.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(package.packageNameSnapshot),
                              subtitle: Text(
                                '${package.creditSnapshot} رصيد • صلاحية '
                                '${package.validityHoursSnapshot} ساعة',
                              ),
                              trailing: Text(
                                '×${package.quantity}\n'
                                '${money(package.priceSnapshot * package.quantity)}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'النتيجة المالية',
                icon: Icons.trending_up,
                accent: item.cashProfit >= 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                child: Column(
                  children: [
                    _row('تكلفة الباقات', money(item.newPackagesCost)),
                    _row('الربح النقدي', money(item.cashProfit)),
                    _row('الرصيد المشتَرى', '${item.purchasedCredit}'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف العملية؟'),
            content: const Text(
              'سيُعاد بناء المخزون من جميع العمليات المتبقية لضمان صحة الرصيد والحركات.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف وإعادة الحساب'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(appRepositoryProvider).deleteTransaction(transactionId);
      invalidateAppData(ref);
      if (context.mounted) context.go('/transactions');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}
