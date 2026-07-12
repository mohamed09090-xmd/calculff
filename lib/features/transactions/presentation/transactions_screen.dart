import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/providers/app_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _query = '';
  bool _undoScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final showUndo =
        GoRouterState.of(context).uri.queryParameters['undo'] == '1';
    if (!showUndo || _undoScheduled) return;
    _undoScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showUndoSnackBar());
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: AppStrings.transactions,
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(transactionsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث باسم العميل أو المنتج',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncStateView(
              value: transactions,
              onRetry: () => ref.invalidate(transactionsProvider),
              data: (items) {
                final filtered = items.where((item) {
                  if (_query.isEmpty) return true;
                  final customer = item.customerName.toLowerCase();
                  final product = item.displayProductName.toLowerCase();
                  return customer.contains(_query) || product.contains(_query);
                }).toList(growable: false);
                if (filtered.isEmpty) {
                  return const Center(child: Text('لا توجد عمليات مطابقة.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final profitColor = item.cashProfit >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          child: Text(item.customerName.substring(0, 1)),
                        ),
                        title: Text(
                          item.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${item.displayProductName} • ${item.requiredCredit} رصيد\n'
                          'بيع: ${MoneyFormatter.format(item.chargedAmount, useThousands: settings.useThousands)} • '
                          '${AppDateUtils.format(item.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          MoneyFormatter.format(
                            item.cashProfit,
                            useThousands: settings.useThousands,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: profitColor,
                          ),
                        ),
                        onTap: () =>
                            context.push('/transactions/${item.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUndoSnackBar() async {
    final repository = ref.read(appRepositoryProvider);
    final message = repository.pendingTransactionUndoMessage;
    if (message == null) return;

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            final result = await repository.undoLastTransactionChange();
            invalidateAppData(ref);
            if (!mounted || result == null) return;
            ref.invalidate(transactionsProvider);
            context.go('/transactions');
          },
        ),
      ),
    );
    final reason = await controller.closed;
    if (reason != SnackBarClosedReason.action) {
      repository.clearPendingTransactionUndo();
    }
  }
}
