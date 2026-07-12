import 'package:flutter/material.dart' hide Text;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/credit_package.dart';
import '../../../shared/providers/app_providers.dart';

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: AppStrings.packages,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('باقة جديدة'),
      ),
      body: AsyncStateView(
        value: packages,
        onRetry: () => ref.invalidate(packagesProvider),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final package = items[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(child: Text('${package.credit}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
                title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  '${MoneyFormatter.format(package.priceDzd, useThousands: settings.useThousands)} • ${_validity(package.validityHours)}',
                ),
                trailing: Switch(
                  value: package.isActive,
                  onChanged: (value) => _save(ref, package.copyWith(isActive: value)),
                ),
                onTap: () => _openEditor(context, ref, package),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _validity(int hours) =>
      hours >= 24 && hours % 24 == 0 ? '${hours ~/ 24} يوم' : '$hours ساعة';

  Future<void> _save(WidgetRef ref, CreditPackage package) async {
    await ref.read(appRepositoryProvider).savePackage(package);
    ref
      ..invalidate(packagesProvider)
      ..invalidate(activePackagesProvider);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, [
    CreditPackage? package,
  ]) async {
    final result = await showDialog<CreditPackage>(
      context: context,
      builder: (context) => _PackageDialog(package: package),
    );
    if (result != null) await _save(ref, result);
  }
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({this.package});
  final CreditPackage? package;

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _credit;
  late final TextEditingController _price;
  late final TextEditingController _validity;
  late bool _validityInDays;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final package = widget.package;
    _name = TextEditingController(text: package?.name ?? '');
    _credit = TextEditingController(text: package?.credit.toString() ?? '');
    _price = TextEditingController(text: package?.priceDzd.toString() ?? '');
    _validityInDays = package == null || package.validityHours % 24 == 0;
    _validity = TextEditingController(
      text: package == null
          ? ''
          : (_validityInDays ? package.validityHours ~/ 24 : package.validityHours).toString(),
    );
    _active = package?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _credit.dispose();
    _price.dispose();
    _validity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.package == null ? 'إضافة باقة' : 'تعديل الباقة'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم الباقة'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 10),
                _numberField(_credit, 'رصيد الألعاب'),
                const SizedBox(height: 10),
                _numberField(_price, 'السعر بالدينار'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _numberField(_validity, 'مدة الصلاحية')),
                    const SizedBox(width: 8),
                    DropdownButton<bool>(
                      value: _validityInDays,
                      items: const [
                        DropdownMenuItem(value: false, child: Text('ساعة')),
                        DropdownMenuItem(value: true, child: Text('يوم')),
                      ],
                      onChanged: (value) => setState(() => _validityInDays = value ?? true),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('باقة فعّالة'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: _submit, child: const Text('حفظ')),
        ],
      );

  Widget _numberField(TextEditingController controller, String label) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = int.tryParse(value ?? '');
          return parsed == null || parsed <= 0 ? 'قيمة غير صالحة' : null;
        },
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.package;
    final rawValidity = int.parse(_validity.text);
    Navigator.pop(
      context,
      CreditPackage(
        id: old?.id ?? IdGenerator.next('package'),
        name: _name.text.trim(),
        priceDzd: int.parse(_price.text),
        credit: int.parse(_credit.text),
        validityHours: _validityInDays ? rawValidity * 24 : rawValidity,
        isActive: _active,
        createdAt: old?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
