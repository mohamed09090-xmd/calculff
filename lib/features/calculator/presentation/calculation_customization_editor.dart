import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../application/calculation_draft_engine.dart';

class CalculationCustomizationEditor extends StatelessWidget {
  const CalculationCustomizationEditor({
    super.key,
    required this.draft,
    required this.settings,
    required this.onChanged,
    this.enabled = true,
  });

  final CalculationDraft draft;
  final AppSettings settings;
  final ValueChanged<CalculationDraft> onChanged;
  final bool enabled;

  static const _engine = CalculationDraftEngine();

  @override
  Widget build(BuildContext context) {
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final gemSale =
        draft.request.mode == CalculationMode.customerAmount ||
        draft.request.mode == CalculationMode.gems;
    final issues = _engine.validate(draft);
    String tr(String ar, String fr) => french ? fr : ar;
    String money(num value) =>
        MoneyFormatter.format(value, useThousands: settings.useThousands);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: tr('تخصيص العملية', 'Personnaliser l’opération'),
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadOnlyValue(
                key: const ValueKey('primary-input-readonly'),
                label: _primaryLabel(draft.request.mode, french),
                value: draft.request.mode == CalculationMode.directProduct
                    ? tr('وحدة واحدة', 'Une unité')
                    : '${draft.primaryInputValue}',
                helper: tr(
                  'قيمة ثابتة حسب العملية ولا يمكن تعديلها من شاشة النتيجة.',
                  'Valeur fixe de l’opération, non modifiable depuis l’écran de résultat.',
                ),
                emphasized: true,
              ),
              if (gemSale) ...[
                const SizedBox(height: 12),
                if (draft.request.mode == CalculationMode.customerAmount)
                  _NumberEditor(
                    key: const ValueKey('gems-input'),
                    label: tr('عدد الجواهر', 'Nombre de gemmes'),
                    value: draft.gems,
                    enabled: enabled,
                    onChanged: (value) =>
                        _apply(context, () => _engine.updateGems(draft, value)),
                  )
                else
                  _ReadOnlyValue(
                    label: tr('الجواهر الناتجة', 'Gemmes calculées'),
                    value: '${draft.gems}',
                  ),
                const SizedBox(height: 12),
                if (draft.request.mode == CalculationMode.customerAmount)
                  _NumberEditor(
                    key: const ValueKey('units-input'),
                    label: tr('عدد الحزم', 'Nombre de lots'),
                    value: draft.units,
                    enabled: enabled,
                    onChanged: (value) => _apply(
                      context,
                      () => _engine.updateUnits(draft, value),
                    ),
                  )
                else
                  _ReadOnlyValue(
                    label: tr('عدد الحزم', 'Nombre de lots'),
                    value: '${draft.units}',
                  ),
              ],
              if (draft.request.mode == CalculationMode.customerAmount) ...[
                const SizedBox(height: 12),
                _NumberEditor(
                  key: const ValueKey('change-input'),
                  label: tr('المبلغ المعاد', 'Montant rendu'),
                  value: draft.customerChange,
                  enabled: enabled,
                  suffix: tr('دج', 'DA'),
                  onChanged: (value) => _apply(
                    context,
                    () => _engine.updateCustomerChange(draft, value),
                  ),
                ),
              ],
              if (gemSale) ...[
                const SizedBox(height: 12),
                _ReadOnlyValue(
                  label: tr('سعر بيع الحزمة', 'Prix de vente du lot'),
                  value: money(draft.salePrice),
                  helper: tr(
                    'ثابت في هذه الشاشة ويُغيّر من إعدادات المنتج فقط.',
                    'Fixe sur cet écran et modifiable uniquement dans les paramètres du produit.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _NumberEditor(
                key: const ValueKey('calculated-amount-input'),
                label: tr('المبلغ المحتسب', 'Montant calculé'),
                value: draft.chargedAmount,
                enabled: enabled,
                emphasized: true,
                suffix: tr('دج', 'DA'),
                helper: tr(
                  'تعديله يغيّر الربح وهامش الربح فقط ولا يغيّر أي قيمة أخرى.',
                  'Sa modification change uniquement le bénéfice et la marge.',
                ),
                onChanged: (value) => _apply(
                  context,
                  () => _engine.updateCalculatedAmount(draft, value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: tr('استخدام المخزون', 'Utilisation du stock'),
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NumberEditor(
                key: const ValueKey('inventory-input'),
                label: tr(
                  'الرصيد المستخدم من المخزون',
                  'Crédit utilisé du stock',
                ),
                value: draft.inventoryCreditUsed,
                enabled: enabled,
                helper: tr(
                  'المتاح: ${draft.availableInventoryCredit}',
                  'Disponible : ${draft.availableInventoryCredit}',
                ),
                onChanged: (value) => _apply(
                  context,
                  () => _engine.updateInventoryCreditUsed(draft, value),
                ),
              ),
              const SizedBox(height: 12),
              _ReadOnlyValue(
                label: tr('الرصيد المطلوب شراؤه', 'Crédit à acheter'),
                value: '${draft.additionalCreditRequired}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: tr('خطة الباقات', 'Plan des forfaits'),
          icon: Icons.account_balance_wallet_outlined,
          child: _PackagePlanEditor(
            draft: draft,
            enabled: enabled,
            french: french,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: tr('النتيجة المحسوبة', 'Résultat calculé'),
          icon: Icons.calculate_outlined,
          child: Column(
            children: [
              _SummaryRow(
                label: tr('إجمالي الرصيد المشترى', 'Crédit total acheté'),
                value: '${draft.purchasedCredit}',
              ),
              _SummaryRow(
                label: tr('الرصيد المتبقي', 'Crédit restant'),
                value: '${draft.remainingPurchasedCredit}',
              ),
              _SummaryRow(
                label: tr('تكلفة شراء الباقات', 'Coût d’achat des forfaits'),
                value: money(draft.newPackagesCost),
              ),
              _SummaryRow(
                label: tr('تكلفة الرصيد المستعمل', 'Coût du crédit utilisé'),
                value: money(draft.creditCostUsed),
              ),
              _SummaryRow(
                label: tr('الربح', 'Bénéfice'),
                value: money(draft.cashProfit),
              ),
              _SummaryRow(
                label: tr('هامش الربح', 'Marge bénéficiaire'),
                value: '${draft.marginPercent.toStringAsFixed(1)}%',
                last: true,
              ),
            ],
          ),
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: tr('تعذر الحفظ', 'Enregistrement impossible'),
            icon: Icons.error_outline,
            accent: Theme.of(context).colorScheme.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${french ? issue.messageFr : issue.messageAr}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _apply(BuildContext context, CalculationDraft Function() update) {
    try {
      onChanged(update());
    } on CalculationDraftValidationException catch (error) {
      final french = Localizations.localeOf(context).languageCode == 'fr';
      final message = error.issues
          .map((issue) => french ? issue.messageFr : issue.messageAr)
          .join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _primaryLabel(CalculationMode mode, bool french) => switch (mode) {
    CalculationMode.customerAmount =>
      french
          ? 'Montant payé (valeur principale)'
          : 'المبلغ المدفوع (المدخل الأساسي)',
    CalculationMode.gems =>
      french
          ? 'Gemmes demandées (valeur principale)'
          : 'عدد الجواهر (المدخل الأساسي)',
    CalculationMode.credit =>
      french
          ? 'Crédit demandé (valeur principale)'
          : 'مقدار الرصيد (المدخل الأساسي)',
    CalculationMode.directProduct =>
      french ? 'Valeur principale' : 'المدخل الأساسي',
  };
}

class _PackagePlanEditor extends StatefulWidget {
  const _PackagePlanEditor({
    required this.draft,
    required this.enabled,
    required this.french,
    required this.onChanged,
  });

  final CalculationDraft draft;
  final bool enabled;
  final bool french;
  final ValueChanged<CalculationDraft> onChanged;

  @override
  State<_PackagePlanEditor> createState() => _PackagePlanEditorState();
}

class _PackagePlanEditorState extends State<_PackagePlanEditor> {
  static const _engine = CalculationDraftEngine();
  String? _packageToAdd;

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String fr) => widget.french ? fr : ar;
    final selections = widget.draft.optimization?.selections ?? const [];
    final selectedIds = selections.map((item) => item.package.id).toSet();
    final available = widget.draft.packages
        .where((item) => !selectedIds.contains(item.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.draft.additionalCreditRequired <= 0)
          Text(
            tr(
              'المخزون يغطي العملية بالكامل، ولا توجد باقات مطلوبة.',
              'Le stock couvre entièrement l’opération ; aucun forfait n’est requis.',
            ),
          ),
        for (final selection in selections)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selection.package.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${selection.package.credit} ${tr('رصيد', 'crédits')} • '
                              '${selection.package.priceDzd} ${tr('دج', 'DA')}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr('حذف الباقة', 'Supprimer le forfait'),
                        onPressed: widget.enabled
                            ? () => _apply(
                                () => _engine.removePackage(
                                  widget.draft,
                                  selection.package.id,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: tr('تقليل العدد', 'Diminuer la quantité'),
                        onPressed: widget.enabled
                            ? () => _apply(
                                () => _engine.decrementPackage(
                                  widget.draft,
                                  selection.package.id,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Tooltip(
                        message: tr('الكمية', 'Quantité'),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 44),
                          child: Text(
                            '${selection.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('زيادة العدد', 'Augmenter la quantité'),
                        onPressed: widget.enabled
                            ? () => _apply(
                                () => _engine.incrementPackage(
                                  widget.draft,
                                  selection.package.id,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final dropdown = DropdownButtonFormField<String>(
                key: ValueKey(_packageToAdd),
                initialValue: available.any((item) => item.id == _packageToAdd)
                    ? _packageToAdd
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(
                    'إضافة باقة مسجلة',
                    'Ajouter un forfait enregistré',
                  ),
                ),
                items: [
                  for (final package in available)
                    DropdownMenuItem(
                      value: package.id,
                      child: Text(
                        '${package.name} — ${package.credit} ${tr('رصيد', 'crédits')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: widget.enabled
                    ? (value) => setState(() => _packageToAdd = value)
                    : null,
              );
              final button = FilledButton.icon(
                onPressed: widget.enabled && _packageToAdd != null
                    ? () {
                        final id = _packageToAdd!;
                        setState(() => _packageToAdd = null);
                        _apply(
                          () => _engine.incrementPackage(widget.draft, id),
                        );
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: Text(tr('إضافة', 'Ajouter')),
              );
              if (MediaQuery.sizeOf(context).width < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [dropdown, const SizedBox(height: 8), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: dropdown),
                  const SizedBox(width: 8),
                  button,
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _apply(CalculationDraft Function() update) {
    try {
      widget.onChanged(update());
    } on CalculationDraftValidationException catch (error) {
      final message = error.issues
          .map((issue) => widget.french ? issue.messageFr : issue.messageAr)
          .join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _NumberEditor extends StatefulWidget {
  const _NumberEditor({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.suffix,
    this.helper,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final String? suffix;
  final String? helper;
  final bool emphasized;

  @override
  State<_NumberEditor> createState() => _NumberEditorState();
}

class _NumberEditorState extends State<_NumberEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant _NumberEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.value = TextEditingValue(
        text: '${widget.value}',
        selection: TextSelection.collapsed(offset: '${widget.value}'.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    enabled: widget.enabled,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: widget.emphasized
        ? const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
        : null,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: widget.suffix,
      helperText: widget.helper,
      border: widget.emphasized ? const OutlineInputBorder() : null,
    ),
    onChanged: (text) {
      final value = int.tryParse(text);
      if (value != null) widget.onChanged(value);
    },
  );
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? helper;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, helperText: helper),
    child: Text(
      value,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: emphasized ? 18 : 16,
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      if (!last) const Divider(height: 20),
    ],
  );
}
