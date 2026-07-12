import 'package:flutter/material.dart' hide Text;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/localization/localized_text.dart';

import '../../../core/localization/app_translator.dart';


import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/inventory_lot.dart';
import '../../../shared/models/inventory_movement.dart';
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
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: AppStrings.inventory,
      actions: [
        IconButton(
          tooltip: AppTranslator.translate(context, 'تحديث المخزون'),
          onPressed: () => ref.invalidate(inventoryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: AsyncStateView(
        value: lots,
        onRetry: () => ref.invalidate(inventoryProvider),
        data: (items) {
          final now = DateTime.now();
          final warningEnd =
              now.add(Duration(hours: settings.expiryWarningHours));
          final active = items
              .where(
                (lot) =>
                    lot.status == InventoryLotStatus.active &&
                    !lot.isExpiredAt(now),
              )
              .fold<int>(0, (sum, lot) => sum + lot.remainingCredit);
          final expired = items
              .where((lot) => lot.status == InventoryLotStatus.expired)
              .fold<int>(0, (sum, lot) => sum + lot.remainingCredit);
          final filtered = items.where((lot) {
            return switch (_filter) {
              _LotFilter.all => true,
              _LotFilter.active =>
                lot.status == InventoryLotStatus.active &&
                    !lot.isExpiredAt(now),
              _LotFilter.expiring =>
                lot.status == InventoryLotStatus.active &&
                    lot.expiresAt.isBefore(warningEnd),
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
                      child: Text(
                        '$active رصيد',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SectionCard(
                      title: 'منتهي',
                      accent: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '$expired رصيد',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'تعديل المخزون يدويًا',
                icon: Icons.tune_outlined,
                accent: Theme.of(context).colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'يمكنك إضافة رصيد مع تكلفته وتاريخ انتهائه، أو خصم رصيد من المخزون العام وفق ترتيب FEFO. كل تعديل يُحفظ في سجل الحركة.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openAddCredit,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('إضافة رصيد'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                active > 0 ? () => _openRemoveCredit(active) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('خصم رصيد'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_LotFilter>(
                  segments: const [
                    ButtonSegment(value: _LotFilter.all, label: Text('الكل')),
                    ButtonSegment(
                      value: _LotFilter.active,
                      label: Text('فعّال'),
                    ),
                    ButtonSegment(
                      value: _LotFilter.expiring,
                      label: Text('قريب'),
                    ),
                    ButtonSegment(
                      value: _LotFilter.expired,
                      label: Text('منتهي'),
                    ),
                    ButtonSegment(
                      value: _LotFilter.depleted,
                      label: Text('مستهلك'),
                    ),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const SectionCard(
                  child: Text('لا توجد رزم ضمن هذا التصنيف.'),
                )
              else
                for (final lot in filtered) ...[
                  _LotCard(
                    lot: lot,
                    settings: settings,
                    onTap: () => _showMovements(lot),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddCredit() async {
    final result = await showDialog<_AddCreditData>(
      context: context,
      builder: (context) => const _AddCreditDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(inventoryAdjustmentRepositoryProvider).addCredit(
            name: result.name,
            amount: result.amount,
            purchaseCost: result.purchaseCost,
            expiresAt: result.expiresAt,
            note: result.note,
          );
      invalidateAppData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت إضافة ${result.amount} رصيد إلى المخزون.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _openRemoveCredit(int activeCredit) async {
    final result = await showDialog<_RemoveCreditData>(
      context: context,
      builder: (context) => _RemoveCreditDialog(activeCredit: activeCredit),
    );
    if (result == null) return;

    try {
      await ref.read(inventoryAdjustmentRepositoryProvider).removeCredit(
            amount: result.amount,
            reason: result.reason,
          );
      invalidateAppData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم خصم ${result.amount} رصيد وتسجيل السبب.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _showMovements(InventoryLot lot) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, controller) => FutureBuilder<List<InventoryMovement>>(
          future: ref
              .read(inventoryAdjustmentRepositoryProvider)
              .getMovements(lot.id),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lot.packageNameSnapshot,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text('سجل الإضافة والاستهلاك والخصم'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: switch (snapshot.connectionState) {
                      ConnectionState.waiting =>
                        const Center(child: CircularProgressIndicator()),
                      _ when snapshot.hasError => Center(
                          child: Text(snapshot.error.toString()),
                        ),
                      _ => _MovementList(
                          movements: snapshot.data ?? const [],
                          controller: controller,
                        ),
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.settings,
    required this.onTap,
  });

  final InventoryLot lot;
  final AppSettings settings;
  final VoidCallback onTap;

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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SectionCard(
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lot.packageNameSnapshot,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (lot.isManual) ...[
                  const Chip(
                    avatar: Icon(Icons.edit_outlined, size: 16),
                    label: Text('يدوي'),
                  ),
                  const SizedBox(width: 6),
                ],
                Chip(
                  label: Text(
                    expired ? 'منتهي' : depleted ? 'مستهلك' : 'فعّال',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: lot.purchasedCredit == 0
                  ? 0
                  : lot.remainingCredit / lot.purchasedCredit,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(
              '${lot.remainingCredit} متبقٍ من ${lot.purchasedCredit}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'التكلفة: ${MoneyFormatter.format(lot.purchaseCost, useThousands: settings.useThousands)}',
            ),
            Text('الإضافة: ${AppDateUtils.format(lot.purchasedAt)}'),
            Text(
              'الانتهاء: ${AppDateUtils.format(lot.expiresAt)} • '
              '${AppDateUtils.remaining(lot.expiresAt)}',
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 5),
                Text('اضغط لعرض سجل الحركة'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementList extends StatelessWidget {
  const _MovementList({
    required this.movements,
    required this.controller,
  });

  final List<InventoryMovement> movements;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const Center(child: Text('لا توجد حركات مسجلة لهذه الرزمة.'));
    }
    return ListView.separated(
      controller: controller,
      itemCount: movements.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final movement = movements[index];
        final inbound =
            movement.direction == InventoryMovementDirection.inbound;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(
              inbound ? Icons.add : Icons.remove,
            ),
          ),
          title: Text(
            '${inbound ? '+' : '-'}${movement.amount} رصيد',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${movement.reason}\n${AppDateUtils.format(movement.createdAt)}',
          ),
          isThreeLine: true,
        );
      },
    );
  }
}

class _AddCreditData {
  const _AddCreditData({
    required this.name,
    required this.amount,
    required this.purchaseCost,
    required this.expiresAt,
    this.note,
  });

  final String name;
  final int amount;
  final int purchaseCost;
  final DateTime expiresAt;
  final String? note;
}

class _AddCreditDialog extends StatefulWidget {
  const _AddCreditDialog();

  @override
  State<_AddCreditDialog> createState() => _AddCreditDialogState();
}

class _AddCreditDialogState extends State<_AddCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'رصيد مضاف يدويًا');
  final _amount = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _note = TextEditingController();
  late DateTime _expiresAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _expiresAt = DateTime(now.year, now.month, now.day + 1, 23, 59);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة رصيد إلى المخزون'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: AppTranslator.translate(context, 'اسم الرصيد أو مصدره'),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.length < 2 ? AppTranslator.translate(context, 'اكتب اسمًا واضحًا') : null;
                },
              ),
              const SizedBox(height: 10),
              _numberField(
                controller: _amount,
                label: AppTranslator.translate(context, 'كمية الرصيد'),
                icon: Icons.toll_outlined,
                allowZero: false,
              ),
              const SizedBox(height: 10),
              _numberField(
                controller: _cost,
                label: AppTranslator.translate(context, 'تكلفة شراء الرصيد بالدينار'),
                icon: Icons.payments_outlined,
                allowZero: true,
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('تاريخ ووقت الانتهاء'),
                subtitle: Text(AppDateUtils.format(_expiresAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickExpiry,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 3,
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: AppTranslator.translate(context, 'سبب أو ملاحظة (اختياري)'),
                  alignLabelWithHint: true,
                ),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool allowZero,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null || parsed < 0 || (!allowZero && parsed == 0)) {
          return allowZero
              ? 'أدخل صفرًا أو رقمًا موجبًا'
              : 'أدخل رقمًا أكبر من صفر';
        }
        return null;
      },
    );
  }

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );
    if (time == null) return;
    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_expiresAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر تاريخ انتهاء في المستقبل.')),
      );
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _AddCreditData(
        name: _name.text.trim(),
        amount: int.parse(_amount.text),
        purchaseCost: int.parse(_cost.text),
        expiresAt: _expiresAt,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class _RemoveCreditData {
  const _RemoveCreditData({required this.amount, required this.reason});

  final int amount;
  final String reason;
}

class _RemoveCreditDialog extends StatefulWidget {
  const _RemoveCreditDialog({required this.activeCredit});

  final int activeCredit;

  @override
  State<_RemoveCreditDialog> createState() => _RemoveCreditDialogState();
}

class _RemoveCreditDialogState extends State<_RemoveCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('خصم رصيد من المخزون'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الرصيد الفعّال المتاح: ${widget.activeCredit}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: AppTranslator.translate(context, 'كمية الرصيد المراد خصمها'),
                  prefixIcon: Icon(Icons.remove_circle_outline),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'أدخل رقمًا أكبر من صفر';
                  }
                  if (parsed > widget.activeCredit) {
                    return 'الكمية أكبر من الرصيد المتاح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reason,
                minLines: 2,
                maxLines: 3,
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: AppTranslator.translate(context, 'سبب الخصم أو الحذف'),
                  hintText: AppTranslator.translate(context, 'مثال: تصحيح خطأ، رصيد تالف، استعمال خارجي'),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.length < 2 ? AppTranslator.translate(context, 'اكتب سبب الخصم') : null;
                },
              ),
              const Text(
                'سيُخصم الرصيد من الأقرب انتهاءً أولًا، مع حفظ سجل تدقيق كامل.',
                style: TextStyle(fontSize: 12),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('تأكيد الخصم'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _RemoveCreditData(
        amount: int.parse(_amount.text),
        reason: _reason.text.trim(),
      ),
    );
  }
}
