import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
        ? orderText(context, 'ÙŠÙˆØ¬Ø¯ Ø¥Ø«Ø¨Ø§Øª Ø¯ÙØ¹')
        : orderText(context, 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø¥Ø«Ø¨Ø§Øª Ø¯ÙØ¹');
    final openIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    return Semantics(
      container: true,
      button: true,
      explicitChildNodes: true,
      onTap: onTap,
      label:
          '${orderText(context, 'Ø·Ù„Ø¨')} ${order.displayId}ØŒ '
          '$gameNameØŒ $offerNameØŒ ${order.customerName}ØŒ '
          '${orderText(context, 'ÙØªØ­ ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨')}',
      child: Card(
        key: Key('order-card-${order.displayId}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('order-card-open-${order.displayId}'),
          onTap: onTap,
          excludeFromSemantics: true,
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
                  OrderField(
                    icon: Icons.person_outline,
                    label: orderText(context, 'Ø§Ù„Ø²Ø¨ÙˆÙ†'),
                    value: order.customerName,
                  ),
                  OrderField(
                    icon: Icons.badge_outlined,
                    label: orderText(context, 'Ù…Ø¹Ø±ÙƒÙ Ø§Ù„Ù„Ø§Ø¹Ø¨'),
                    value: order.playerId,
                    excludeFromSemantics: true,
                  ),
                  if (order.inGameName case final name?)
                    OrderField(
                      icon: Icons.sports_esports_outlined,
                      label: orderText(context, 'Ø§Ù„Ø§Ø³Ù… Ø¯Ø§Ø®Ù„ Ø§Ù„Ù„Ø¹Ø¨Ø©'),
                      value: name,
                      excludeFromSemantics: true,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrderStatusBadge(
                        text:
                            '${orderText(context, 'Ø§Ù„ÙƒÙ…ÙŠØ©')}: '
                            '${order.rewardQuantity} $rewardUnit',
                        icon: Icons.redeem_outlined,
                      ),
                      OrderStatusBadge(
                        text:
                            '${orderText(context, 'Ø§Ù„Ø³Ø¹Ø±')}: '
                            '${order.salePriceDzd} ${orderText(context, 'Ø¯Ø¬')}',
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
                  OrderField(
                    icon: Icons.schedule_outlined,
                    label: orderText(context, 'ÙˆÙ‚Øª Ø§Ù„Ø¥Ù†Ø´Ø§Ø¡'),
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
    final theme = Theme.of(context);
    final maximumWidth = MediaQuery.sizeOf(context).width - 48;
    return Semantics(
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maximumWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Flexible(child: Text(text, softWrap: true)),
                ],
              ),
            ),
          ),
        ),
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
      label: orderText(context, 'Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…Ø¹Ø±ÙˆØ¶Ø© Ù‚Ø¯ÙŠÙ…Ø©.'),
      child: Card(
        key: const Key('orders-stale-banner'),
        child: ListTile(
          leading: const Icon(Icons.history_toggle_off_outlined),
          title: Text(orderText(context, 'Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…Ø¹Ø±ÙˆØ¶Ø© Ù‚Ø¯ÙŠÙ…Ø©.')),
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
    this.excludeFromSemantics = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;
  final bool forceLtr;
  final bool excludeFromSemantics;

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
    final field = Padding(
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
    return excludeFromSemantics ? ExcludeSemantics(child: field) : field;
  }
}

String orderStatusText(BuildContext context, OrderStatus status) {
  return orderText(context, switch (status) {
    OrderStatus.newOrder => 'Ø¬Ø¯ÙŠØ¯',
    OrderStatus.accepted => 'Ù…Ù‚Ø¨ÙˆÙ„',
    OrderStatus.processing => 'Ù‚ÙŠØ¯ Ø§Ù„Ù…Ø¹Ø§Ù„Ø¬Ø©',
    OrderStatus.completed => 'Ù…ÙƒØªÙ…Ù„',
    OrderStatus.rejected => 'Ù…Ø±ÙÙˆØ¶',
    OrderStatus.cancelled => 'Ù…Ù„ØºÙ‰',
  });
}

String paymentStatusText(BuildContext context, PaymentStatus status) {
  return orderText(context, switch (status) {
    PaymentStatus.awaitingPayment => 'Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø¯ÙØ¹',
    PaymentStatus.underReview => 'Ù‚ÙŠØ¯ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©',
    PaymentStatus.paid => 'Ù…Ø¯ÙÙˆØ¹',
    PaymentStatus.proofRejected => 'Ø¥Ø«Ø¨Ø§Øª Ù…Ø±ÙÙˆØ¶',(€€€A…åµ•¹ÑMÑ…ÑÕÌ¹É•™Õ¹‘A•¹‘¥¹œ€ôø€ŸbŸbÏb«bÇb¿bŸb¼ƒfbçffœ°(€€€A…åµ•¹ÑMÑ…ÑÕÌ¹É•™Õ¹‘•€ôø€ŸfbÏb«bÇb¼œ°(€ô¤ì)ô()MÑÉ¥¹œÁ…åµ•¹Ñ5•Ñ¡½‘Q•áĞ¡	Õ¥±‘½¹Ñ•áĞ½¹Ñ•áĞ°A…åµ•¹Ñ5•Ñ¡½µ•Ñ¡½¤ì(€É•ÑÕÉ¸½É‘•ÉQ•áĞ¡½¹Ñ•áĞ°Íİ¥Ñ €¡µ•Ñ¡½¤ì(€€€A…åµ•¹Ñ5•Ñ¡½¹…Í €ôø€Ÿffb¿f/bœœ°(€€€A…åµ•¹Ñ5•Ñ¡½¹ÑÉ…¹Í™•È€ôø€Ÿb«b·f#f+fœ°(€ô¤ì)ô()MÑÉ¥¹œÑ¥µ•±¥¹•Ù•¹ÑQåÁ•Q•áĞ (€	Õ¥±‘½¹Ñ•áĞ½¹Ñ•áĞ°(€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”•Ù•¹ÑQåÁ”°(¤ì(€É•ÑÕÉ¸½É‘•ÉQ•áĞ¡½¹Ñ•áĞ°Íİ¥Ñ €¡•Ù•¹ÑQåÁ”¤ì(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹É•…Ñ•€ôø€Ÿb—fbÓbŸb„ƒbŸfbßfb œ°(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹½É‘•É¡…¹•€ôø€Ÿb«bëf+f+bÄƒb·bŸfb¤ƒbŸfbßfb œ°(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹Á…åµ•¹Ñ¡…¹•€ôø€Ÿb«bëf+f+bÄƒb·bŸfb¤ƒbŸfb¿fbäœ°(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹ÁÉ½½™ÑÑ…¡•€ôø€Ÿb—bÇfbŸfƒb—b¯b£bŸb¨ƒbŸfb¿fbäœ°(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹É•™Õ¹‘MÑ…ÉÑ•€ôø€Ÿb£b¿b„ƒbŸfbŸbÏb«bÇb¿bŸb¼œ°(€€€=É‘•ÉQ¥µ•±¥¹•Ù•¹ÑQåÁ”¹É•™Õ¹‘•€ôø€ŸbŸfb«fbŸfƒbŸfbŸbÏb«bÇb¿bŸb¼œ°(€ô¤ì)ô(