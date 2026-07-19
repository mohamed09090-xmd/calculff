import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_translator.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/customer_order_summary.dart';
import '../../domain/orders/order_enums.dart';
import '../platform_ui_text.dart';
import 'orders_ui_text.dart';

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final CustomerOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFrench = AppTranslator.isFrench(context);
    final gameName = isFrench
        ? order.gameNameFrSnapshot
        : order.gameNameArSnapshot;
    final offerName = isFrench
        ? order.offerNameFrSnapshot
        : order.offerNameArSnapshot;
    final rewardUnit = isFrench
        ? order.rewardUnitNameFr
        : order.rewardUnitNameAr;
    final createdAt = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm().format(order.createdAt.toLocal());
    final proofLabel = order.hasPaymentProof
        ? orderText(context, 'يوجد إثبات دفع')
        : orderText(context, 'لا يوجد إثبات دفع');
    final openIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label:
          '${orderText(context, 'طلب')} ${order.displayId}، '
          '$gameName، $offerName، ${order.customerName}، '
          '${orderText(context, 'فتح تفاصيل الطلب')}',
      child: Card(
        key: Key('order-card-${order.displayId}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('order-card-open-${order.displayId}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#${order.displayId}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 4),
                          Icon(openIcon),
                        ],
                      ),
                      OrderStatusBadge(
                        text: orderStatusText(context, order.orderStatus),
                        icon: Icons.receipt_long_outlined,
                      ),
                      OrderStatusBadge(
                        text: proofLabel,
                        icon: order.hasPaymentProof
                            ? Icons.attachment_outlined
                            : Icons.do_not_disturb_alt_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    gameName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(offerName),
                  const Divider(height: 22),
                  _OrderField(
                    icon: Icons.person_outline,
                    label: orderText(context, 'الزبون'),
                    value: order.customerName,
                  ),
                  _OrderField(
                    icon: Icons.badge_outlined,
                    label: orderText(context, 'معرّف اللاعب'),
                    value: order.playerId,
                  ),
                  if (order.inGameName case final name?)
                    _OrderField(
                      icon: Icons.sports_esports_outlined,
                      label: orderText(context, 'الاسم داخل اللعبة'),
                      value: name,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrderStatusBadge(
                        text:
                            '${orderText(context, 'الكمية')}: '
                            '${order.rewardQuantity} $rewardUnit',
                        icon: Icons.redeem_outlined,
                      ),
                      OrderStatusBadge(
                        text:
                            '${orderText(context, 'السعر')}: '
                            '${order.salePriceDzd} ${orderText(context, 'دج')}',
                        icon: Icons.payments_outlined,
                      ),
                      OrderStatusBadge(
                        text: paymentMethodText(context, order.paymentMethod),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      OrderStatusBadge(
                        text: paymentStatusText(context, order.paymentStatus),
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OrderField(
                    icon: Icons.schedule_outlined,
                    label: orderText(context, 'وقت الإنشاء'),
                    value: createdAt,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(text),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class OrdersStateMessage extends StatelessWidget {
  const OrdersStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRefresh,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRefresh;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 96),
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel case final label?) ...[
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: label,
              child: FilledButton.icon(
                key: const Key('orders-retry-button'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrdersStaleBanner extends StatelessWidget {
  const OrdersStaleBanner({super.key, required this.failureCode});

  final PlatformFailureCode? failureCode;

  @override
  Widget build(BuildContext context) {
    final failure = PlatformFailure(failureCode ?? PlatformFailureCode.unknown);
    return Semantics(
      liveRegion: true,
      label: orderText(context, 'البيانات المعروضة قديمة.'),
      child: Card(
        key: const Key('orders-stale-banner'),
        child: ListTile(
          leading: const Icon(Icons.history_toggle_off_outlined),
          title: Text(orderText(context, 'البيانات المعروضة قديمة.')),
          subtitle: Text(platformDataFailureText(context, failure)),
        ),
      ),
    );
  }
}

class OrderField extends StatelessWidget {
  const OrderField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
    this.forceLtr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    final displayed = value.isEmpty ? label : '$label: $value';
    final text = selectable
        ? SelectableText(
            displayed,
            textDirection: forceLtr ? TextDirection.ltr : null,
          )
        : Text(
            displayed,
            softWrap: true,
            textDirection: forceLtr ? TextDirection.ltr : null,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(child: text),
        ],
      ),
    );
  }
}

String orderStatusText(BuildContext context, OrderStatus status) {
  return orderText(context, switch (status) {
    OrderStatus.newOrder => 'جديد',
    OrderStatus.accepted => 'مقبول',
    OrderStatus.processing => 'قيد المعالجة',
    OrderStatus.completed => 'مكتمل',
    OrderStatus.rejected => 'مرفوض',
    OrderStatus.cancelled => 'ملغى',
  });
}

String paymentStatusText(BuildContext context, PaymentStatus status) {
  return orderText(context, switch (status) {
    PaymentStatus.awaitingPayment => 'بانتظار الدفع',
    PaymentStatus.underReview => 'قيد المراجعة',
    PaymentStatus.paid => 'مدفوع',
    PaymentStatus.proofRejected => 'إثبات مرفوض',
    PaymentStatus.refundPending => 'استرداد معلق',
    PaymentStatus.refunded => 'مسترد',
  });
}

String paymentMethodText(BuildContext context, PaymentMethod method) {
  return orderText(context, switch (method) {
    PaymentMethod.cash => 'نقدًا',
    PaymentMethod.transfer => 'تحويل',
  });
}

String timelineEventTypeText(
  BuildContext context,
  OrderTimelineEventType eventType,
) {
  return orderText(context, switch (eventType) {
    OrderTimelineEventType.created => 'إنشاء الطلب',
    OrderTimelineEventType.orderChanged => 'تغيير حالة الطلب',
    OrderTimelineEventType.paymentChanged => 'تغيير حالة الدفع',
    OrderTimelineEventType.proofAttached => 'إرفاق إثبات الدفع',
    OrderTimelineEventType.refundStarted => 'بدء الاسترداد',
    OrderTimelineEventType.refunded => 'اكتمال الاسترداد',
  });
}
