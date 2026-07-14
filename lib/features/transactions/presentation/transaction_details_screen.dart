import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/localization/app_translator.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/transaction_details.dart';
import '../../../shared/providers/app_providers.dart';

class TransactionDetailsScreen extends ConsumerStatefulWidget {
  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
    this.showUndo = false,
  });

  final String transactionId;
  final bool showUndo;

  @override
  ConsumerState<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState
    extends ConsumerState<TransactionDetailsScreen> {
  late Future<TransactionDetails> _detailsFuture;
  late Future<bool> _editableFuture;
  bool _undoScheduled = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
    _editableFuture = ref
        .read(appRepositoryProvider)
        .isLatestTransaction(widget.transactionId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showUndo || _undoScheduled) return;
    _undoScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showUndoSnackBar());
    });
  }

  Future<TransactionDetails> _loadDetails() => ref
      .read(appRepositoryProvider)
      .getTransactionDetails(widget.transactionId);

  void _reload() {
    setState(() {
      _detailsFuture = _loadDetails();
      _editableFuture = ref
          .read(appRepositoryProvider)
          .isLatestTransaction(widget.transactionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: 'تفاصيل العملية',
      actions: [
        FutureBuilder<bool>(
          future: _editableFuture,
          builder: (context, snapshot) {
            final editable = snapshot.data ?? false;
            return IconButton(
              tooltip: AppTranslator.translate(
                context,
                editable ? 'تعديل العملية' : 'يمكن تعديل آخر عملية فقط',
              ),
              onPressed: editable
                  ? () => context.push(
                      '/transactions/${widget.transactionId}/edit',
                    )
                  : null,
              icon: const Icon(Icons.edit_outlined),
            );
          },
        ),
        IconButton(
          tooltip: AppTranslator.translate(context, 'حذف العملية'),
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      body: FutureBuilder<TransactionDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          final details = snapshot.data!;
          final item = details.transaction;
          String money(num value) =>
              MoneyFormatter.format(value, useThousands: settings.useThousands);
          final productName = item.displayProductName;
          final isGemSale =
              item.mode == CalculationMode.customerAmount ||
              item.mode == CalculationMode.gems;

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
                    if (item.productDescriptionSnapshot?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 6),
                      Text(item.productDescriptionSnapshot!),
                    ],
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
                    if (isGemSale) _row('الحزم', '${item.units}'),
                    if (isGemSale) _row('الجواهر', '${item.gems}'),
                    if (isGemSale)
                      _row('المبلغ المدفوع', money(item.customerPaid)),
                    _row('سعر البيع', money(item.chargedAmount)),
                    if (item.mode == CalculationMode.customerAmount)
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
                    _row('تكلفة الرصيد المستعمل', money(item.creditCostUsed)),
                    _row(
                      'المبلغ المدفوع الآن للباقات',
                      money(item.newPackagesCost),
                    ),
                    _row('الربح', money(item.cashProfit)),
                    _row('الرصيد المشتَرى', '${item.purchasedCredit}'),
                  ],
                ),
              ),
              const SizedBox(height: 90),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );

  Future<void> _showUndoSnackBar() async {
    final repository = ref.read(appRepositoryProvider);
    final message = repository.pendingTransactionUndoMessage;
    if (message == null) return;

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: AppTranslator.translate(context, 'تراجع'),
          onPressed: () async {
            final result = await repository.undoLastTransactionChange();
            invalidateAppData(ref);
            if (!mounted || result == null) return;
            if (result.transactionExistsAfterUndo) {
              context.go('/transactions/${result.transactionId}');
              _reload();
            } else {
              context.go('/transactions');
            }
          },
        ),
      ),
    );
    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) {
      repository.clearPendingTransactionUndo();
    }
  }

  Future<void> _delete() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف العملية؟'),
            content: const Text(
              'سيُعاد بناء المخزون من جميع العمليات المتبقية. سيظهر زر تراجع بعد الحذف.',
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
      await ref
          .read(appRepositoryProvider)
          .deleteTransactionWithUndo(widget.transactionId);
      invalidateAppData(ref);
      if (mounted) context.go('/transactions?undo=1');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
