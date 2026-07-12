import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/customer.dart';

class CustomerAutocomplete extends StatelessWidget {
  const CustomerAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.customers,
    required this.onSelected,
    required this.onTextChanged,
    this.enabled = true,
    this.autofocus = false,
    this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Customer> customers;
  final ValueChanged<Customer> onSelected;
  final ValueChanged<String> onTextChanged;
  final bool enabled;
  final bool autofocus;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Customer>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (customer) => customer.name,
      optionsBuilder: (textValue) {
        final query = textValue.text.trim().toLowerCase();
        final matches = customers.where((customer) {
          if (query.isEmpty) return true;
          return customer.name.toLowerCase().contains(query) ||
              (customer.phone?.contains(query) ?? false);
        }).take(8);
        return matches;
      },
      onSelected: onSelected,
      fieldViewBuilder: (
        context,
        textController,
        fieldFocusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textController,
          focusNode: fieldFocusNode,
          autofocus: autofocus,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: const InputDecoration(
            labelText: 'اسم العميل',
            hintText: 'ابحث أو اكتب اسم عميل جديد',
            prefixIcon: Icon(Icons.badge_outlined),
            suffixIcon: Icon(Icons.expand_more_rounded),
            helperText: 'الاسم الجديد سيُضاف إلى قائمة العملاء تلقائيًا.',
          ),
          validator: validator,
          onChanged: onTextChanged,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, select, options) {
        final entries = options.toList(growable: false);
        if (entries.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 360),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = entries[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(customer.name.substring(0, 1)),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: customer.phone == null
                        ? Text('${customer.transactionCount} عملية')
                        : Text('${customer.phone} • ${customer.transactionCount} عملية'),
                    trailing: customer.isActive
                        ? null
                        : const Icon(Icons.archive_outlined),
                    onTap: () => select(customer),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
