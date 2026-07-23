import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_translator.dart';
import '../../application/common/platform_common_providers.dart';
import '../../application/orders/order_details_controller.dart';
import '../../application/orders/order_details_providers.dart';
import '../../application/orders/order_actions_controller.dart';
import '../../application/orders/order_payment_proof_provider.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/customer_order_details.dart';
import '../../domain/orders/customer_order_summary.dart';
import '../../domain/orders/order_internal_note.dart';
import '../../domain/orders/order_enums.dart';
import '../../domain/orders/order_payment_proof.dart';
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
    final internalNotes = state.status == OrderDetailsViewStatus.data
        ? ref.watch(orderInternalNotesProvider(widget.orderId))
        : const AsyncLoading<List<OrderInternalNote>>();
    final controller = ref.read(
      orderDetailsControllerProvider(widget.orderId).notifier,
    );
    final actionState = ref.watch(
      orderActionsControllerProvider(widget.orderId),
    );
    return Scaffold(
      appBar: AppBar(title: Text('#$shortId')),
      body: SafeArea(
        child: switch (state.status) {
          OrderDetailsViewStatus.loading => const _Loading(),
          OrderDetailsViewStatus.data => _Content(
            details: state.details!,
            timeline: state.timeline,
            internalNotes: internalNotes,
            actionState: actionState,
            onRetryInternalNotes: () =>
                ref.invalidate(orderInternalNotesProvider(widget.orderId)),
            onViewPaymentProof: () => _showPaymentProof(context),
            onAccept: () => _confirmAction(accept: true),
            onReject: () => _confirmAction(accept: false),
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

  Future<void> _showPaymentProof(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PaymentProofDialog(orderId: widget.orderId),
    );
  }

  Future<void> _confirmAction({required bool accept}) async {
    final title = orderText(context, accept ? 'قبول الطلب' : 'رفض الطلب');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          orderText(
            context,
            accept
                ? 'سيتم تأكيد الدفع ونقل الطلب إلى قيد التنفيذ.'
                : 'سيتم رفض الطلب وتحديث حالة الدفع بأمان.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(orderText(context, 'إلغاء')),
          ),
          FilledButton(
            key: Key(accept ? 'confirm-accept-order' : 'confirm-reject-order'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final controller = ref.read(
      orderActionsControllerProvider(widget.orderId).notifier,
    );
    final succeeded = accept
        ? await controller.accept(
            publicMessage: orderText(context, 'تم قبول الطلب وبدأ تنفيذه.'),
          )
        : await controller.reject(
            publicMessage: orderText(context, 'تم رفض الطلب بعد المراجعة.'),
          );
    if (!mounted) return;
    final actionState = ref.read(
      orderActionsControllerProvider(widget.orderId),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? orderText(context, 'تم تحديث الطلب بنجاح.')
              : platformDataFailureText(
                  context,
                  PlatformFailure(
                    actionState.failureCode ?? PlatformFailureCode.unknown,
                  ),
                ),
        ),
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
    required this.actionState,
    required this.onRetryInternalNotes,
    required this.onViewPaymentProof,
    required this.onAccept,
    required this.onReject,
  });

  final CustomerOrderDetails details;
  final List<OrderTimelineEvent> timeline;
  final AsyncValue<List<OrderInternalNote>> internalNotes;
  final OrderActionState actionState;
  final VoidCallback onRetryInternalNotes;
  final VoidCallback onViewPaymentProof;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final order = details.summary;
    final isFrench = AppTranslator.isFrench(context);
    final game = isFrench ? order.gameNameFrSnapshot : order.gameNameArSnapshot;
    final offer = isFrench
        ? order.offerNameFrSnapshot
        : order.offerNameArSnapshot;
    final unit = isFrench ? order.rewardUnitNameFr : order.rewardUnitNameAr;
    final isFinal = const <OrderStatus>{
      OrderStatus.completed,
      OrderStatus.rejected,
      OrderStatus.cancelled,
    }.contains(order.orderStatus);
    final canAccept =
        !isFinal &&
        order.orderStatus != OrderStatus.processing &&
        order.paymentStatus != PaymentStatus.proofRejected &&
        order.paymentStatus != PaymentStatus.refundPending &&
        order.paymentStatus != PaymentStatus.refunded &&
        (order.paymentMethod == PaymentMethod.cash || order.hasPaymentProof);
    final canReject = !isFinal;

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
        if (order.hasPaymentProof)
          _Section(
            key: const Key('order-details-payment-proof'),
            title: orderText(context, 'إثبات الدفع'),
            icon: Icons.attachment_outlined,
            children: [
              Text(
                orderText(context, 'الإثبات خاص ويُفتح برابط مؤقت لمدة قصيرة.'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('view-payment-proof'),
                onPressed: actionState.isSubmitting ? null : onViewPaymentProof,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(orderText(context, 'عرض إثبات الدفع')),
              ),
            ],
          ),
        if (canAccept || canReject)
          _Section(
            key: const Key('order-details-actions'),
            title: orderText(context, 'إجراءات الطلب'),
            icon: Icons.rule_outlined,
            children: [
              if (actionState.isSubmitting)
                Semantics(
                  liveRegion: true,
                  label: orderText(context, 'جارٍ تحديث الطلب'),
                  child: const LinearProgressIndicator(),
                ),
              if (actionState.isSubmitting) const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canAccept)
                    FilledButton.icon(
                      key: const Key('accept-order'),
                      onPressed: actionState.isSubmitting ? null : onAccept,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(orderText(context, 'قبول وبدء التنفيذ')),
                    ),
                  if (canReject)
                    OutlinedButton.icon(
                      key: const Key('reject-order'),
                      onPressed: actionState.isSubmitting ? null : onReject,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(orderText(context, 'رفض الطلب')),
                    ),
                ],
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
        _InternalNotesSection(
          notes: internalNotes,
          onRetry: onRetryInternalNotes,
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

class _PaymentProofDialog extends ConsumerWidget {
  const _PaymentProofDialog({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proof = ref.watch(orderPaymentProofProvider(orderId));
    return AlertDialog(
      title: Text(orderText(context, 'إثبات الدفع')),
      content: SizedBox(
        width: 520,
        height: 520,
        child: proof.when(
          loading: () => Semantics(
            liveRegion: true,
            label: orderText(context, 'تحميل إثبات الدفع'),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _PaymentProofFailure(
            onRetry: () => ref.invalidate(orderPaymentProofProvider(orderId)),
          ),
          data: (value) {
            if (value == null) {
              return Center(
                child: Text(orderText(context, 'لا يوجد إثبات دفع متاح.')),
              );
            }
            return switch (value.kind) {
              OrderPaymentProofKind.image => InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.network(
                  value.uri.toString(),
                  key: const Key('payment-proof-image'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _PaymentProofFailure(
                    onRetry: () =>
                        ref.invalidate(orderPaymentProofProvider(orderId)),
                  ),
                ),
              ),
              OrderPaymentProofKind.pdf => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      orderText(
                        context,
                        'إثبات الدفع ملف PDF. افتحه بواسطة عارض آمن على جهازك.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('open-payment-proof-pdf'),
                      onPressed: () => Share.shareUri(value.uri),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(orderText(context, 'فتح ملف PDF')),
                    ),
                  ],
                ),
              ),
            };
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(orderText(context, 'إغلاق')),
        ),
      ],
    );
  }
}

class _PaymentProofFailure extends StatelessWidget {
  const _PaymentProofFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 56),
          const SizedBox(height: 12),
          Text(
            orderText(context, 'تعذر عرض إثبات الدفع.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('payment-proof-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(orderText(context, 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }
}

class _InternalNotesSection extends StatelessWidget {
  const _InternalNotesSection({required this.notes, required this.onRetry});

  final AsyncValue<List<OrderInternalNote>> notes;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Section(
      key: const Key('order-details-internal-notes'),
      title: orderText(context, 'الملاحظات الداخلية'),
      icon: Icons.lock_outline,
      children: switch (notes) {
        AsyncData(:final value) when value.isEmpty => [
          Text(orderText(context, 'لا توجد ملاحظات داخلية.')),
        ],
        AsyncData(:final value) => [
          for (final note in value) _InternalNoteLine(note: note),
        ],
        AsyncError() => [
          Text(orderText(context, 'تعذر تحميل الملاحظات الداخلية.')),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('order-details-internal-notes-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(orderText(context, 'إعادة المحاولة')),
            ),
          ),
        ],
        _ => [
          Semantics(
            liveRegion: true,
            label: orderText(context, 'تحميل الملاحظات الداخلية'),
            child: const Align(
              alignment: AlignmentDirectional.centerStart,
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      },
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
      child: ExcludeSemantics(
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
