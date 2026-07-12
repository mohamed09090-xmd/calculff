import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/customer_autocomplete.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/customer.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/transaction_details.dart';
import '../../../shared/providers/app_providers.dart';

class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState
    extends ConsumerState<TransactionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _valueController = TextEditingController();
  late final Future<_EditData> _dataFuture;

  bool _initialized = false;
  bool _saving = false;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  CalculationMode _mode = CalculationMode.customerAmount;
  Product? _product;
  bool _useInventory = true;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _customerFocusNode.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<_EditData> _loadData() async {
    final repository = ref.read(appRepositoryProvider);
    final values = await Future.wait<Object>([
      repository.getTransactionDetails(widget.transactionId),
      repository.getProducts(),
      repository.getCustomers(),
    ]);
    return _EditData(
      details: values[0] as TransactionDetails,
      products: values[1] as List<Product>,
      customers: values[2] as List<Customer>,
    );
  }

  void _initialize(_EditData data) {
    if (_initialized) return;
    _initialized = true;
    final transaction = data.details.transaction;
    _selectedCustomerId = transaction.customerId;
    _selectedCustomerName = transaction.customerName;
    _customerController.text = transaction.customerName;
    _valueController.text = '${transaction.inputValue}';
    _mode = transaction.mode == CalculationMode.credit
        ? CalculationMode.customerAmount
        : transaction.mode;
    _useInventory = transaction.useInventory;
    _product = data.products.cast<Product?>().firstWhere(
          (product) => product?.id == transaction.productId,
          orElse: () => data.products.isEmpty ? null : data.products.first,
        );
  }

  String get _inputLabel => switch (_mode) {
        CalculationMode.customerAmount => 'المبلغ المدفوع بالدينار',
        CalculationMode.gems => 'عدد الجواهر المطلوبة',
        CalculationMode.credit => 'الرصيد المطلوب',
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'تعديل العملية',
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
          _initialize(data);
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
                SectionCard(
                  title: 'إعادة حساب العملية',
                  icon: Icons.calculate_outlined,
                  child: Column(
                    children: [
                      SegmentedButton<CalculationMode>(
                        segments: const [
                          ButtonSegment(
                            value: CalculationMode.customerAmount,
                            label: Text('المبلغ'),
                            icon: Icon(Icons.payments_outlined),
                          ),
                          ButtonSegment(
                            value: CalculationMode.gems,
                            label: Text('الجواهر'),
                            icon: Icon(Icons.diamond_outlined),
                          ),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged: _saving
                            ? null
                            : (selection) => setState(() {
                                  _mode = selection.first;
                                  _valueController.clear();
                                }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Product>(
                        initialValue: _product,
                        decoration: const InputDecoration(labelText: 'المنتج'),
                        items: [
                          for (final product in data.products)
                            DropdownMenuItem(
                              value: product,
                              child: Text(product.name),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _product = value),
                        validator: (value) =>
                            value == null ? 'اختر المنتج' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _valueController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: _inputLabel,
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'أدخل قيمة صحيحة أكبر من صفر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('استخدام الرصيد الموجود'),
                        subtitle: const Text(
                          'سيُعاد بناء المخزون وتطبيق FEFO على جميع العمليات',
                        ),
                        value: _useInventory,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                setState(() => _useInventory = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'تعديل آمن',
                  icon: Icons.shield_outlined,
                  child: const Text(
                    'يُنفذ التعديل داخل معاملة واحدة. إذا فشل الحساب فلن تتغير العملية أو بيانات المخزون. بعد النجاح يمكنك التراجع فورًا.',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_as_outlined),
                  label: const Text('إعادة الحساب وحفظ التعديل'),
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حفظ تعديل العملية؟'),
            content: const Text(
              'سيُعاد حساب الباقات والمخزون وترتيب الاستهلاك وفق FEFO. يمكنك التراجع بعد نجاح التعديل.',
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
    if (!confirmed) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(appRepositoryProvider).editTransaction(
            transactionId: widget.transactionId,
            request: CalculationRequest(
              mode: _mode,
              product: _product,
              inputValue: int.parse(_valueController.text),
              useInventory: _useInventory,
            ),
            customerName: _customerController.text,
            customerId: _selectedCustomerId,
          );
      invalidateAppData(ref);
      if (mounted) {
        context.go('/transactions/${widget.transactionId}?undo=1');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
    required this.customers,
  });

  final TransactionDetails details;
  final List<Product> products;
  final List<Customer> customers;
}
