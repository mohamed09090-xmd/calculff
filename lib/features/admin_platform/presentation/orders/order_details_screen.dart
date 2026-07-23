import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_translator.dart';
import '../../application/common/platform_common_providers.dart';
import '../../application/orders/order_details_controller.dart';
import '../../application/orders/order_details_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/customer_order_details.dart';
import '../../domain/orders/customer_order_summary.dart';
import '../../domain/orders/order_internal_note.dart';
import '../../domain/orders/order_timeline_event.dart';
import '../platform_ui_text.dart';
import 'order_widgets.dart';
import 'orders_ui_text.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _popScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(platformDataScopeProvider, (_, next) {
      if (!next.isAuthorized) _schedulePop();
    });
    final shortId = customerOrderDisplayId(widget.orderId);
    final scope = ref.watch(platformDataScopeProvider);
    if (!scope.isAuthorized) {
      _schedulePop();
      return _SessionBoundary(shortId: shortId);
    }

    final state = ref.watch(orderDetailsControllerProvider(widget.orderId));
    final controller = ref.read(
      orderDetailsControllerProvider(widget.orderId).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: Text('#$shortId')),
      body: SafeArea(
        child: switch (state.status) {
          OrderDetailsViewStatus.loading => const _Loading(),
          OrderDetailsViewStatus.data => _Content(
            details: state.details!,
            timeline: state.timeline,
            internalNotes: state.internalNotes,
          ),
          OrderDetailsViewStatus.offline => _Failure(
            key: const Key('order-details-offline'),
            icon: Icons.cloud_off_outlined,
            title: orderText(context, 'لا يوجد اتصال بالمنصة.'),
            message: platformDataFailureText(
              context,
              const PlatformFailure(PlatformFailureCode.networkUnavailable),
            ),
            onRetry: controller.retry,
          ),
          OrderDetailsViewStatus.notFound => _Failure(
            key: const Key('order-details-not-found'),
            icon: Icons.search_off_outlined,
            title: orderText(context, 'الطلب غير موجود.'),
            message: orderText(
              context,
              'تعذر العثور على هذا الطلب أو لم يعد متاحًا.',
            ),
            onRetry: controller.retry,
          ),
          OrderDetailsViewStatus.error => _Failure(
            key: const Key('order-details-error'),
            icon: Icons.error_outline,
            title: orderText(context, 'تعذر تحميل تفاصيل الطلب.'),
            message: platformDataFailureText(
              context,
              PlatformFailure(state.failureCode ?? PlatformFailureCode.unknown),
            ),
            onRetry: controller.retry,
          ),
        },
      ),
    );
  }

  void _schedulePop() {
    if (_popScheduled) return;
    _popScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }
}

class _SessionBoundary extends StatelessWidget {
  const _SessionBoundary({required this.shortId});

  final String shortId;

  @override
  Widget build(BuildContext context) {
    final message = orderText(context, 'انتهت جلسة المنصة.');
    return Scaffold(
      appBar: AppBar(title: Text('#$shortId')),
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: orderText(context, 'تحميل تفاصيل الطلب'),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.details,
    required this.timeline,
    required this.internalNotes,
  });

  final CustomerOrderDetails details;
  final List<OrderTimelineEvent> timeline;
  final List<OrderInternalNote> internalNotes;

  @override
  Widget build(BuildContext context) {
    final order = details.summary;
    final isFrench = AppTranslator.isFrench(context);
    final game = isFrench ? order.gameNameFrSnapshot : order.gameNameArSnapshot;
    final offer = isFrench
        ? order.offerNameFrSnapshot
        : order.offerNameArSnapshot;
    final unit = isFrench ? order.rewardUnitNameFr : order.rewardUnitNameAr;

    return ListView(
      key: const Key('order-details-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 32),
      children: [
        _Section(
          title: orderText(context, 'ملخص الطلب'),
          icon: Icons.receipt_long_outlined,
          children: [
            OrderField(
              icon: Icons.sports_esports_outlined,
              label: orderText(context, 'اللعبة'),
              value: game,
            ),
            OrderField(
              icon: Icons.local_offer_outlined,
              label: orderText(context, 'العرض'),
              value: offer,
            ),
            OrderField(
              icon: Icons.redeem_outlined,
              label: orderText(context, 'وحدة المكافأة'),
              value:
                  '${order.rewardQuantity} $unit '
                  '(${details.rewardUnitCodeSnapshot})',
            ),
          ],
        ),
        _Section(
          title: orderText(context, 'بيانات الزبون واللاعب'),
          icon: Icons.person_outline,
          children: [
            OrderField(
              icon: Icons.person_outline,
              label: orderText(context, 'الزبون'),
              value: order.customerName,
            ),
            OrderField(
              key: const Key('order-details-player-id'),
              icon: Icons.badge_outlined,
              label: orderText(context, 'معرّف اللاعب'),
              value: order.playerId,
              selectable: true,
              forceLtr: true,
            ),
            if (order.inGameName case final name?)
              OrderField(
                icon: Icons.videogame_asset_outlined,
                label: orderText(context, 'الاسم داخل اللعبة'),
                value: name,
              ),
          ],
        ),
        _Section(
          title: orderText(context, 'السعر والحالات'),
          icon: Icons.payments_outlined,
          children: [
            OrderField(
              icon: Icons.payments_outlined,
              label: orderText(context, 'السعر'),
              value: '${order.salePriceDzd} ${orderText(context, 'دج')}',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OrderStatusBadge(
                  text: orderStatusText(context, order.orderStatus),
                  icon: Icons.receipt_long_outlined,
                ),
                OrderStatusBadge(
                  text: paymentStatusText(context, order.paymentStatus),
                  icon: Icons.verified_outlined,
                ),
                OrderStatusBadge(
                  text: paymentMethodText(context, order.paymentMethod),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                OrderStatusBadge(
                  text: order.hasPaymentProof
                      ? orderText(context, 'يوجد إثبات دفع')
                      : orderText(context, 'لا يوجد إثبات دفع'),
                  icon: order.hasPaymentProof
                      ? Icons.attachment_outlined
                      : Icons.do_not_disturb_alt_outlined,
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: orderText(context, 'معلومات الاتصال'),
          icon: Icons.contact_mail_outlined,
          children: [
            OrderField(
              key: const Key('order-details-email'),
              icon: Icons.email_outlined,
              label: orderText(context, 'البريد الإلكتروني'),
              value: details.customerEmail,
              selectable: true,
              forceLtr: true,
            ),
            OrderField(
              key: const Key('order-details-phone'),
              icon: Icons.phone_outlined,
              label: orderText(context, 'رقم الهاتف'),
              value: details.customerPhone,
              selectable: true,
              forceLtr: true,
            ),
          ],
        ),
        if (details.publicStatusMessage case final message?)
          _Section(
            title: orderText(context, 'الرسالة العامة'),
            icon: Icons.chat_bubble_outline,
            children: [Text(message)],
          ),
        _Section(
          key: const Key('order-details-internal-notes'),
          title: orderText(context, 'الملاحظات الداخلية'),
          icon: Icons.lock_outline,
          children: internalNotes.isEmpty
              ? [Text(orderText(context, 'لا توجد ملاحظات داخلية.'))]
              : [
                  for (final note in internalNotes)
                    _InternalNoteLine(note: note),
                ],
        ),
        _Section(
          title: orderText(context, 'تواريخ الطلب'),
          icon: Icons.schedule_outlined,
          children: [
            _DateLine(
              label: orderText(context, 'وقت الإنشاء'),
              value: order.createdAt,
            ),
            _DateLine(
              label: orderText(context, 'آخر تحديث'),
              value: details.updatedAt,
            ),
            if (details.completedAt case final value?)
              _DateLine(
                label: orderText(context, 'وقت الاكتمال'),
                value: value,
              ),
            if (details.refundStartedAt case final value?)
              _DateLine(
                label: orderText(context, 'بدء الاسترداد'),
                value: value,
              ),
            if (details.refundedAt case final value?)
              _DateLine(
                label: orderText(context, 'وقت الاسترداد'),
                value: value,
              ),
          ],
        ),
        _Section(
          key: const Key('order-details-timeline'),
          title: orderText(context, 'التسلسل الزمني'),
          icon: Icons.timeline_outlined,
          children: timeline.isEmpty
              ? [Text(orderText(context, 'لا توجد أحداث عامة للطلب.'))]
              : [for (final event in timeline) _TimelineLine(event: event)],
        ),
      ],
    );
  }
}

class _InternalNoteLine extends StatelessWidget {
  const _InternalNoteLine({required this.note});

  final OrderInternalNote note;

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(context, note.createdAt);
    return Semantics(
      container: true,
      label: '${note.text}، $date',
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(note.text),
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Card(
        margin: const EdgeInsetsDirectional.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine({required this.label, required this.value});

  final String label;
  final DateTime value;

  @override
  Widget build(BuildContext context) {
    return OrderField(
      icon: Icons.schedule_outlined,
      label: label,
      value: _formatDate(context, value),
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.event});

  final OrderTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final title = timelineEventTypeText(context, event.eventType);
    final date = _formatDate(context, event.createdAt);
    return Semantics(
      container: true,
      label:
          '$title، ${orderStatusText(context, event.orderStatus)}، '
          '${paymentStatusText(context, event.paymentStatus)}، $date',
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(date),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OrderStatusBadge(
                  text: orderStatusText(context, event.orderStatus),
                  icon: Icons.receipt_long_outlined,
                ),
                OrderStatusBadge(
                  text: paymentStatusText(context, event.paymentStatus),
                  icon: Icons.verified_outlined,
                ),
              ],
            ),
            if (event.publicMessage case final message?) ...[
              const SizedBox(height: 6),
              Text(message),
            ],
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = orderText(context, 'إعادة المحاولة');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 96),
      children: [
        Semantics(
          liveRegion: true,
          label: '$title. $message',
          child: Column(
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          button: true,
          label: retry,
          child: FilledButton.icon(
            key: const Key('order-details-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retry),
          ),
        ),
      ],
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  return DateFormat.yMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hm().format(value.toLocal());
}
