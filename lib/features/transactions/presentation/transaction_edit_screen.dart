import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/customer_autocomplete.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/credit_package.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/models/optimization_result.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/transaction_details.dart';
import '../../../shared/providers/app_providers.dart';
import '../../calculator/application/calculation_draft_engine.dart';
import '../../calculator/presentation/calculation_customization_editor.dart';

class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen> {
  static const _engine = CalculationDraftEngine();
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _customerFocusNode = FocusNode();
  late final Future<_EditData> _dataFuture;

  CalculationDraft? _draft;
  bool _initialized = false;
  bool _saving = false;
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  Future<_EditData> _loadData() async {
    final repository = ref.read(appRepositoryProvider);
    final values = await Future.wait<Object>([
      repository.getTransactionDetails(widget.transactionId),
      repository.getProducts(),
      repository.getPackages(),
      repository.getCustomers(),
      repository.getEditableInventoryCredit(widget.transactionId),
    ]);
    return _EditData(
      details: values[0] as TransactionDetails,
      products: values[1] as List<Product>,
      packages: values[2] as List<CreditPackage>,
      customers: values[3] as List<Customer>,
      availableInventoryCredit: values[4] as int,
    );
  }

  void _initialize(_EditData data) {
    if (_initialized) return;
    _initialized = true;
    final transaction = data.details.transaction;
    _selectedCustomerId = transaction.customerId;
    _selectedCustomerName = transaction.customerName;
    _customerController.text = transaction.customerName;

    final product = data.products.cast<Product?>().firstWhere(
      (item) => item?.id == transaction.productId,
      orElse: () => null,
    );
    final needsProduct =
        transaction.mode == CalculationMode.customerAmount ||
        transaction.mode == CalculationMode.gems ||
        transaction.mode == CalculationMode.directProduct;
    if (needsProduct && product == null) {
      throw StateError(
        'تعذر تعديل العملية لأن المنتج الأصلي لم يعد مسجلًا. '
        'Impossible de modifier l’opération car le produit d’origine n’est plus enregistré.',
      );
    }

    final selections = <PackageSelection>[
      for (final item in data.details.items)
        PackageSelection(
          package:
              data.packages.cast<CreditPackage?>().firstWhere(
                (package) => package?.id == item.packageId,
                orElse: () => null,
              ) ??
              item.asPackage(),
          quantity: item.quantity,
        ),
    ];
    final optimization = selections.isEmpty
        ? null
        : OptimizationResult(
            requiredCredit: transaction.additionalCreditRequired,
            selections: selections,
            totalCost: selections.fold(0, (sum, item) => sum + item.totalCost),
            totalCredit: selections.fold(
              0,
              (sum, item) => sum + item.totalCredit,
            ),
            minimumValidityHours: selections
                .map((item) => item.package.validityHours)
                .reduce((a, b) => a < b ? a : b),
          );
    final result = CalculationResult(
      request: CalculationRequest(
        mode: transaction.mode,
        product: product,
        inputValue: transaction.inputValue,
        useInventory: transaction.useInventory,
      ),
      units: transaction.units,
      gems: transaction.gems,
      customerPaid: transaction.customerPaid,
      chargedAmount: transaction.chargedAmount,
      customerChange: transaction.customerChange,
      requiredCredit: transaction.requiredCredit,
      inventoryCreditUsed: transaction.inventoryCreditUsed,
      additionalCreditRequired: transaction.additionalCreditRequired,
      optimization: optimization,
      creditCostUsed: transaction.chargedAmount - transaction.cashProfit,
      cashProfit: transaction.cashProfit,
    );
    _draft = _engine.fromResult(
      result,
      packages: data.packages,
      availableInventoryCredit: data.availableInventoryCredit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    return AppShell(
      title: 'تعديل آخر عملية',
      body: FutureBuilder<_EditData>(
        future: _dataFuture,
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
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('العودة'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          try {
            _initialize(data);
          } catch (error) {
            return Center(
              child: Text(error.toString(), textAlign: TextAlign.center),
            );
          }
          final draft = _draft!;
          final issues = _engine.validate(draft);

          return Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                SectionCard(
                  title: 'العميل',
                  icon: Icons.person_outline_rounded,
                  child: CustomerAutocomplete(
                    controller: _customerController,
                    focusNode: _customerFocusNode,
                    customers: data.customers,
                    enabled: !_saving,
                    onSelected: _selectCustomer,
                    onTextChanged: _customerTextChanged,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'اسم العميل مطلوب';
                      if (name.length < 2) return 'اسم العميل قصير جدًا';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                CalculationCustomizationEditor(
                  draft: draft,
                  settings: settings,
                  enabled: !_saving,
                  onChanged: (next) => setState(() => _draft = next),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'تعديل ذري وآمن',
                  icon: Icons.shield_outlined,
                  child: const Text(
                    'سيُلغى أثر العملية القديم ثم يُطبق الأثر الجديد مرة واحدة داخل معاملة SQLite واحدة. عند حدوث خطأ تُستعاد العملية والمخزون تلقائيًا.',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving || issues.isNotEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_as_outlined),
                  label: const Text('حفظ تعديل آخر عملية'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomerId = customer.id;
      _selectedCustomerName = customer.name;
      _customerController.text = customer.name;
      _customerController.selection = TextSelection.collapsed(
        offset: customer.name.length,
      );
    });
  }

  void _customerTextChanged(String value) {
    if (_selectedCustomerName == null) return;
    if (value.trim().toLowerCase() ==
        _selectedCustomerName!.trim().toLowerCase()) {
      return;
    }
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerName = null;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _draft;
    if (draft == null) return;
    final result = _engine.finalize(draft);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حفظ تعديل آخر عملية؟'),
            content: const Text(
              'سيتم إلغاء أثر العملية القديم على المخزون وتطبيق القيم الجديدة مرة واحدة فقط.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('مراجعة'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ التعديل'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .editTransactionResult(
            transactionId: widget.transactionId,
            result: result,
            customerName: _customerController.text,
            customerId: _selectedCustomerId,
          );
      invalidateAppData(ref);
      if (mounted) context.go('/transactions/${widget.transactionId}?undo=1');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditData {
  const _EditData({
    required this.details,
    required this.products,
    required this.packages,
    required this.customers,
    required this.availableInventoryCredit,
  });

  final TransactionDetails details;
  final List<Product> products;
  final List<CreditPackage> packages;
  final List<Customer> customers;
  final int availableInventoryCredit;
}
