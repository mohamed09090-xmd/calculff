import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/inventory_lot.dart';
import '../../../shared/providers/app_providers.dart';

enum _LotFilter { all, active, expiring, expired, depleted }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  _LotFilter _filter = _LotFilter.all;

  @override
  Widget build(BuildContext context) {
    final lots = ref.watch(inventoryProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: AppStrings.inventory,
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(inventoryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: AsyncStateView(
        value: lots,
        onRetry: () => ref.invalidate(inventoryProvider),
        data: (items) {
          final now = DateTime.now();
          final warningEnd = now.add(Duration(hours: settings.expiryWarningHours));
          final active = items
              .where((lot) => lot.status == InventoryLotStatus.active && !lot.isExpiredAt(now))
              .fold<int>(0, (sum, lot) => sum + lot.remainingCredit);
          final expired = items
              .where((lot) => lot.status == InventoryLotStatus.expired)
              .fold<int>(0, (sum, lot) => sum + lot.remainingCredit);
          final filtered = items.where((lot) {
            return switch (_filter) {
              _LotFilter.all => true,
              _LotFilter.active => lot.status == InventoryLotStatus.active && !lot.isExpiredAt(now),
              _LotFilter.expiring => lot.status == InventoryLotStatus.active && lot.expiresAt.isBefore(warningEnd),
              _LotFilter.expired => lot.status == InventoryLotStatus.expired,
              _LotFilter.depleted => lot.status == InventoryLotStatus.depleted,
            };
          }).toList(growable: false);
          return ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SectionCard(
                      title: 'فعّال',
                      accent: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.all(12),
                      child: Text('$active رصيد', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SectionCard(
                      title: 'منتهي',
                      accent: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.all(12),
                      child: Text('$expired رصيد', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_LotFilter>(
                  segments: const [
                    ButtonSegment(value: _LotFilter.all, label: Text('الكل')),
                    ButtonSegment(value: _LotFilter.active, label: Text('فعّال')),
                    ButtonSegment(value: _LotFilter.expiring, label: Text('قريب')),
                    ButtonSegment(value: _LotFilter.expired, label: Text('منتهي')),
                    ButtonSegment(value: _LotFilter.depleted, label: Text('مستهلك')),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const SectionCard(child: Text('لا توجد رزم ضمن هذا التصنيف.'))
              else
                for (final lot in filtered) ...[
                  _LotCard(lot: lot, settings: settings),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.settings});
  final InventoryLot lot;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expired = lot.status == InventoryLotStatus.expired || lot.isExpiredAt(now);
    final depleted = lot.status == InventoryLotStatus.depleted;
    final color = expired
        ? Theme.of(context).colorScheme.error
        : depleted
            ? Theme.of(context).colorScheme.outline
            : Theme.of(context).colorScheme.primary;
    return SectionCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lot.packageNameSnapshot, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              Chip(label: Text(expired ? 'منتهي' : depleted ? 'مستهلك' : 'فعّال')),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: lot.purchasedCredit == 0 ? 0 : lot.remainingCredit / lot.purchasedCredit,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 10),
          Text('${lot.remainingCredit} متبقٍ من ${lot.purchasedCredit}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('التكلفة: ${MoneyFormatter.format(lot.purchaseCost, useThousands: settings.useThousands)}'),
          Text('الشراء: ${AppDateUtils.format(lot.purchasedAt)}'),
          Text('الانتهاء: ${AppDateUtils.format(lot.expiresAt)} • ${AppDateUtils.remaining(lot.expiresAt)}'),
        ],
      ),
    );
  }
}
