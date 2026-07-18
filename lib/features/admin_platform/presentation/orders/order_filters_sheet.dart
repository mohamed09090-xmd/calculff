import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_translator.dart';
import '../../domain/games/game.dart';
import '../../domain/orders/order_enums.dart';
import '../../domain/orders/order_filters.dart';
import 'order_widgets.dart';
import 'orders_ui_text.dart';

class OrderFiltersSheet extends StatefulWidget {
  const OrderFiltersSheet({
    super.key,
    required this.initialFilters,
    required this.games,
  });

  final OrderFilters initialFilters;
  final List<Game> games;

  @override
  State<OrderFiltersSheet> createState() => _OrderFiltersSheetState();
}

class _OrderFiltersSheetState extends State<OrderFiltersSheet> {
  late final TextEditingController _searchController;
  late OrderStatus? _orderStatus;
  late PaymentStatus? _paymentStatus;
  late PaymentMethod? _paymentMethod;
  late String? _gameId;
  late DateTime? _dateFrom;
  late DateTime? _dateToExclusive;

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _searchController = TextEditingController(text: filters.searchText ?? '');
    _orderStatus = filters.orderStatus;
    _paymentStatus = filters.paymentStatus;
    _paymentMethod = filters.paymentMethod;
    _gameId = filters.gameId;
    _dateFrom = filters.dateFrom;
    _dateToExclusive = filters.dateToExclusive;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isFrench = AppTranslator.isFrench(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              orderText(context, 'الفلاتر'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Semantics(
              textField: true,
              label: orderText(context, 'بحث'),
              child: TextField(
                key: const Key('orders-search-field'),
                controller: _searchController,
                maxLength: OrderFilters.maxSearchLength,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    OrderFilters.maxSearchLength,
                  ),
                ],
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: orderText(context, 'بحث'),
                  hintText: orderText(context, 'ابحث باسم الزبون أو Player ID'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<OrderStatus?>(
              key: const Key('orders-order-status-filter'),
              initialValue: _orderStatus,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: orderText(context, 'حالة الطلب'),
              ),
              items: <DropdownMenuItem<OrderStatus?>>[
                DropdownMenuItem<OrderStatus?>(
                  value: null,
                  child: Text(orderText(context, 'الكل')),
                ),
                for (final status in OrderStatus.values)
                  DropdownMenuItem<OrderStatus?>(
                    value: status,
                    child: Text(orderStatusText(context, status)),
                  ),
              ],
              onChanged: (value) => setState(() => _orderStatus = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentStatus?>(
              key: const Key('orders-payment-status-filter'),
              initialValue: _paymentStatus,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: orderText(context, 'حالة الدفع'),
              ),
              items: <DropdownMenuItem<PaymentStatus?>>[
                DropdownMenuItem<PaymentStatus?>(
                  value: null,
                  child: Text(orderText(context, 'الكل')),
                ),
                for (final status in PaymentStatus.values)
                  DropdownMenuItem<PaymentStatus?>(
                    value: status,
                    child: Text(paymentStatusText(context, status)),
                  ),
              ],
              onChanged: (value) => setState(() => _paymentStatus = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod?>(
              key: const Key('orders-payment-method-filter'),
              initialValue: _paymentMethod,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: orderText(context, 'طريقة الدفع'),
              ),
              items: <DropdownMenuItem<PaymentMethod?>>[
                DropdownMenuItem<PaymentMethod?>(
                  value: null,
                  child: Text(orderText(context, 'الكل')),
                ),
                for (final method in PaymentMethod.values)
                  DropdownMenuItem<PaymentMethod?>(
                    value: method,
                    child: Text(paymentMethodText(context, method)),
                  ),
              ],
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('orders-game-filter'),
              initialValue: _gameId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: orderText(context, 'اللعبة'),
              ),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(orderText(context, 'الكل')),
                ),
                for (final game in widget.games)
                  DropdownMenuItem<String?>(
                    value: game.id,
                    child: Text(isFrench ? game.nameFr : game.nameAr),
                  ),
              ],
              onChanged: (value) => setState(() => _gameId = value),
            ),
            const SizedBox(height: 12),
            _DateFilterTile(
              key: const Key('orders-date-from-filter'),
              label: orderText(context, 'من تاريخ'),
              date: _dateFrom,
              onTap: () => _pickDate(isStart: true),
              onClear: _dateFrom == null
                  ? null
                  : () => setState(() => _dateFrom = null),
            ),
            const SizedBox(height: 8),
            _DateFilterTile(
              key: const Key('orders-date-to-filter'),
              label: orderText(context, 'إلى تاريخ'),
              date: _inclusiveEndDate,
              onTap: () => _pickDate(isStart: false),
              onClear: _dateToExclusive == null
                  ? null
                  : () => setState(() => _dateToExclusive = null),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton.icon(
                  key: const Key('orders-clear-filters-button'),
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(orderText(context, 'مسح الفلاتر')),
                ),
                FilledButton.icon(
                  key: const Key('orders-apply-filters-button'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(orderText(context, 'تطبيق الفلاتر')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime? get _inclusiveEndDate {
    return _dateToExclusive?.subtract(const Duration(days: 1));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _dateFrom : _inclusiveEndDate;
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current?.toLocal() ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (selected == null || !mounted) {
      return;
    }
    final utcDate = DateTime.utc(selected.year, selected.month, selected.day);
    setState(() {
      if (isStart) {
        _dateFrom = utcDate;
      } else {
        _dateToExclusive = utcDate.add(const Duration(days: 1));
      }
    });
  }

  void _clear() {
    _searchController.clear();
    setState(() {
      _orderStatus = null;
      _paymentStatus = null;
      _paymentMethod = null;
      _gameId = null;
      _dateFrom = null;
      _dateToExclusive = null;
    });
  }

  void _apply() {
    final filters = OrderFilters(
      orderStatus: _orderStatus,
      paymentStatus: _paymentStatus,
      paymentMethod: _paymentMethod,
      gameId: _gameId,
      dateFrom: _dateFrom,
      dateToExclusive: _dateToExclusive,
      searchText: _searchController.text,
    );
    if (!filters.isValid) {
      return;
    }
    Navigator.of(context).pop(filters);
  }
}

class _DateFilterTile extends StatelessWidget {
  const _DateFilterTile({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final value = date == null
        ? orderText(context, 'الكل')
        : DateFormat.yMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(date!.toLocal());
    return Semantics(
      button: true,
      label: '$label: $value',
      child: ListTile(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(label),
        subtitle: Text(value),
        onTap: onTap,
        trailing: onClear == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: orderText(context, 'مسح الفلاتر'),
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}
