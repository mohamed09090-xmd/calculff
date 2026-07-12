import 'package:flutter/material.dart' hide Text;

import '../../../core/localization/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/providers/app_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;

    return AppShell(
      title: 'العملاء',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(customersProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('عميل جديد'),
      ),
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث بالاسم أو رقم الهاتف',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncStateView(
              value: customers,
              onRetry: () => ref.invalidate(customersProvider),
              data: (items) {
                final filtered = items.where((customer) {
                  if (_query.isEmpty) return true;
                  return customer.name.toLowerCase().contains(_query) ||
                      (customer.phone?.contains(_query) ?? false);
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return _EmptyCustomers(
                    hasQuery: _query.isNotEmpty,
                    onAdd: _openEditor,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return _CustomerCard(
                      customer: customer,
                      money: (value) => MoneyFormatter.format(
                        value,
                        useThousands: settings.useThousands,
                      ),
                      onEdit: () => _openEditor(customer),
                      onToggleActive: () => _toggleActive(customer),
                      onDelete: () => _delete(customer),
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

  Future<void> _openEditor([Customer? customer]) async {
    final draft = await showDialog<_CustomerDraft>(
      context: context,
      builder: (context) => _CustomerEditorDialog(customer: customer),
    );
    if (draft == null) return;

    try {
      await ref.read(appRepositoryProvider).saveCustomer(
            id: customer?.id,
            name: draft.name,
            phone: draft.phone,
            notes: draft.notes,
            isActive: customer?.isActive ?? true,
          );
      invalidateAppData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              customer == null ? 'تمت إضافة العميل' : 'تم تحديث بيانات العميل',
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

  Future<void> _toggleActive(Customer customer) async {
    try {
      await ref
          .read(appRepositoryProvider)
          .setCustomerActive(customer.id, !customer.isActive);
      invalidateAppData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              customer.isActive ? 'تمت أرشفة العميل' : 'تمت إعادة تفعيل العميل',
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

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('حذف ${customer.name}؟'),
            content: const Text(
              'يمكن حذف العميل فقط إذا لم تكن له عمليات محفوظة. العملاء ذوو العمليات يمكن أرشفتهم.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await ref.read(appRepositoryProvider).deleteCustomer(customer.id);
      invalidateAppData(ref);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.money,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Customer customer;
  final String Function(num value) money;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: customer.isActive
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              child: Text(
                customer.name.substring(0, 1),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!customer.isActive)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('مؤرشف'),
                        ),
                    ],
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 3),
                    Text(customer.phone!),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _Stat(
                        icon: Icons.receipt_long_outlined,
                        value: '${customer.transactionCount} عملية',
                      ),
                      _Stat(
                        icon: Icons.payments_outlined,
                        value: money(customer.totalSpent),
                      ),
                      _Stat(
                        icon: Icons.trending_up,
                        value: 'ربح ${money(customer.totalProfit)}',
                      ),
                    ],
                  ),
                  if (customer.lastTransactionAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'آخر عملية: ${AppDateUtils.format(customer.lastTransactionAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (customer.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      customer.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'active':
                    onToggleActive();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('تعديل'),
                  ),
                ),
                PopupMenuItem(
                  value: 'active',
                  child: ListTile(
                    leading: Icon(
                      customer.isActive
                          ? Icons.archive_outlined
                          : Icons.unarchive_outlined,
                    ),
                    title: Text(
                      customer.isActive ? 'أرشفة' : 'إعادة التفعيل',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.hasQuery, required this.onAdd});

  final bool hasQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 58),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'لا يوجد عميل مطابق' : 'لا يوجد عملاء بعد',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('إضافة أول عميل'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name);
    _phoneController = TextEditingController(text: widget.customer?.phone);
    _notesController = TextEditingController(text: widget.customer?.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'عميل جديد' : 'تعديل العميل'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'اسم العميل مطلوب';
                  if (name.length < 2) return 'الاسم قصير جدًا';
                  if (name.length > 80) return 'الاسم طويل جدًا';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف — اختياري',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات — اختيارية',
                  prefixIcon: Icon(Icons.notes_outlined),
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _CustomerDraft(
                name: _nameController.text,
                phone: _phoneController.text,
                notes: _notesController.text,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _CustomerDraft {
  const _CustomerDraft({
    required this.name,
    required this.phone,
    required this.notes,
  });

  final String name;
  final String phone;
  final String notes;
}
