import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translator.dart';
import '../../application/offers/offers_controller.dart';
import '../../application/offers/offers_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/common/platform_validation.dart';
import '../../domain/games/game.dart';
import '../../domain/offers/public_offer.dart';
import '../../domain/offers/public_offer_input.dart';
import 'offers_ui_text.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offersControllerProvider);
    final controller = ref.read(offersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(offerText(context, 'إدارة العروض العامة')),
        actions: [
          Semantics(
            button: true,
            label: offerText(context, 'تحديث العروض'),
            child: IconButton(
              key: const Key('offers-refresh-button'),
              tooltip: offerText(context, 'تحديث العروض'),
              onPressed: state.isRefreshing ? null : controller.refresh,
              icon: state.isRefreshing
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _OffersBody(
          state: state,
          onRefresh: controller.refresh,
          onEdit: (offer) => _openForm(context, offer),
          onPublishChanged: (offer, value) async {
            final result = await controller.setOfferPublished(
              offerId: offer.id,
              isPublished: value,
            );
            if (!context.mounted) {
              return;
            }
            _showMutationResult(context, result);
          },
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: offerText(context, 'إنشاء عرض'),
        child: FloatingActionButton.extended(
          key: const Key('offers-add-button'),
          onPressed: state.isSubmitting ? null : () => _openForm(context, null),
          icon: const Icon(Icons.add),
          label: Text(offerText(context, 'إنشاء عرض')),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, PublicOffer? offer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OfferFormScreen(offer: offer),
      ),
    );
  }
}

class _OffersBody extends StatelessWidget {
  const _OffersBody({
    required this.state,
    required this.onRefresh,
    required this.onEdit,
    required this.onPublishChanged,
  });

  final OffersState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<PublicOffer> onEdit;
  final void Function(PublicOffer offer, bool value) onPublishChanged;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case OffersViewStatus.loading:
        return Center(
          child: Semantics(
            label: offerText(context, 'جاري تحميل العروض'),
            child: const CircularProgressIndicator(),
          ),
        );
      case OffersViewStatus.empty:
        return _RefreshableMessage(
          key: const Key('offers-empty-state'),
          icon: Icons.campaign_outlined,
          title: offerText(context, 'لا توجد عروض عامة بعد.'),
          message: offerText(
            context,
            'أنشئ أول عرض، ثم انشره عندما تكون لعبته فعالة.',
          ),
          onRefresh: onRefresh,
        );
      case OffersViewStatus.offline:
        return _RefreshableMessage(
          key: const Key('offers-offline-state'),
          icon: Icons.cloud_off_outlined,
          title: offerText(context, 'لا يوجد اتصال بالمنصة.'),
          message: offerText(context, 'تحقق من الاتصال ثم أعد المحاولة.'),
          onRefresh: onRefresh,
          actionLabel: offerText(context, 'إعادة المحاولة'),
        );
      case OffersViewStatus.error:
        return _RefreshableMessage(
          key: const Key('offers-error-state'),
          icon: Icons.error_outline,
          title: _failureText(context, state.failureCode),
          message: offerText(
            context,
            'تعذر تحميل العروض بأمان. أعد المحاولة.',
          ),
          onRefresh: onRefresh,
          actionLabel: offerText(context, 'إعادة المحاولة'),
        );
      case OffersViewStatus.data:
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            key: const Key('offers-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
            children: [
              if (state.isStale)
                _StaleBanner(failureCode: state.failureCode),
              for (final offer in state.offers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OfferCard(
                    offer: offer,
                    isSubmitting: state.isSubmitting,
                    onEdit: () => onEdit(offer),
                    onPublishChanged: (value) =>
                        onPublishChanged(offer, value),
                  ),
                ),
            ],
          ),
        );
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isSubmitting,
    required this.onEdit,
    required this.onPublishChanged,
  });

  final PublicOffer offer;
  final bool isSubmitting;
  final VoidCallback onEdit;
  final ValueChanged<bool> onPublishChanged;

  @override
  Widget build(BuildContext context) {
    final isFrench = AppTranslator.isFrench(context);
    final offerName = isFrench ? offer.nameFr : offer.nameAr;
    final gameName = isFrench ? offer.gameNameFr : offer.gameNameAr;
    final rewardUnit = isFrench
        ? offer.rewardUnitNameFr
        : offer.rewardUnitNameAr;
    final statusText = offer.isPublished
        ? offerText(context, 'منشور')
        : offerText(context, 'مخفي');

    return Semantics(
      container: true,
      label: '${offerText(context, 'عرض')} $offerName، $statusText',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                offerName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(gameName),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.redeem_outlined, size: 18),
                    label: Text('${offer.rewardQuantity} $rewardUnit'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(offerText(context, '${offer.salePriceDzd} دج')),
                  ),
                  Chip(
                    avatar: Icon(
                      offer.isPublished
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    label: Text(statusText),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                key: Key('offer-publish-${offer.id}'),
                contentPadding: EdgeInsets.zero,
                value: offer.isPublished,
                onChanged: isSubmitting ? null : onPublishChanged,
                title: Text(offerText(context, 'نشر العرض')),
                subtitle: Text(
                  offer.isPublished
                      ? offerText(context, 'العرض ظاهر للزبائن.')
                      : offerText(context, 'العرض مخفي عن الزبائن.'),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  button: true,
                  label: '${offerText(context, 'تعديل العرض')} $offerName',
                  child: FilledButton.tonalIcon(
                    key: Key('offer-edit-${offer.id}'),
                    onPressed: isSubmitting ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(offerText(context, 'تعديل')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.failureCode});

  final PlatformFailureCode? failureCode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: offerText(context, 'البيانات المعروضة قديمة'),
      child: Card(
        key: const Key('offers-stale-banner'),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.history_toggle_off_outlined),
          title: Text(offerText(context, 'البيانات المعروضة قديمة')),
          subtitle: Text(_failureText(context, failureCode)),
        ),
      ),
    );
  }
}

class _RefreshableMessage extends StatelessWidget {
  const _RefreshableMessage({
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
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 104),
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
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: actionLabel,
              child: FilledButton.icon(
                key: const Key('offers-retry-button'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({super.key, this.offer});

  final PublicOffer? offer;

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameArController;
  late final TextEditingController _nameFrController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _sortOrderController;
  String? _selectedGameId;
  late bool _isPublished;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    _nameArController = TextEditingController(text: offer?.nameAr ?? '');
    _nameFrController = TextEditingController(text: offer?.nameFr ?? '');
    _quantityController = TextEditingController(
      text: offer == null ? '' : '${offer.rewardQuantity}',
    );
    _priceController = TextEditingController(
      text: offer == null ? '' : '${offer.salePriceDzd}',
    );
    _sortOrderController = TextEditingController(
      text: '${offer?.sortOrder ?? 0}',
    );
    _selectedGameId = offer?.gameId;
    _isPublished = offer?.isPublished ?? false;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameFrController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offersControllerProvider);
    final selectedGame = _findGame(state.games, _selectedGameId);
    final isEditing = widget.offer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          offerText(context, isEditing ? 'تعديل العرض' : 'إنشاء عرض'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('offer-form-scroll-view'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              DropdownButtonFormField<String>(
                key: const Key('offer-game-field'),
                initialValue: _selectedGameId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: offerText(context, 'اللعبة'),
                  prefixIcon: const Icon(Icons.sports_esports_outlined),
                ),
                items: [
                  for (final game in state.games)
                    DropdownMenuItem<String>(
                      value: game.id,
                      child: Text(
                        _gameName(context, game) +
                            (game.isActive
                                ? ''
                                : ' — ${offerText(context, 'غير فعالة')}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedGameId = value;
                          _submissionError = null;
                        });
                      },
                validator: (value) => value == null || value.isEmpty
                    ? offerText(context, 'اختيار اللعبة مطلوب.')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('offer-name-ar-field'),
                controller: _nameArController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: offerText(context, 'اسم العرض بالعربية'),
                ),
                validator: (value) => _requiredNameError(context, value),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('offer-name-fr-field'),
                controller: _nameFrController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: offerText(context, 'اسم العرض بالفرنسية'),
                ),
                validator: (value) => _requiredNameError(context, value),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('offer-quantity-field'),
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: offerText(context, 'كمية المكافأة'),
                  suffixText: selectedGame == null
                      ? null
                      : _rewardUnit(context, selectedGame),
                ),
                validator: (value) => _positiveIntegerError(context, value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('offer-price-field'),
                controller: _priceController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: offerText(context, 'سعر البيع بالدينار'),
                  suffixText: offerText(context, 'دج'),
                ),
                validator: (value) => _positiveIntegerError(context, value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('offer-sort-order-field'),
                controller: _sortOrderController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: offerText(context, 'ترتيب العرض'),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 0) {
                    return offerText(context, 'أدخل صفرًا أو رقمًا موجبًا.');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                key: const Key('offer-published-field'),
                contentPadding: EdgeInsets.zero,
                value: _isPublished,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() {
                        _isPublished = value;
                        _submissionError = null;
                      }),
                title: Text(offerText(context, 'نشر العرض')),
                subtitle: Text(
                  selectedGame != null && !selectedGame.isActive
                      ? offerText(
                          context,
                          'لا يمكن نشر عرض تابع للعبة غير فعالة.',
                        )
                      : offerText(
                          context,
                          'يمكن حفظ العرض مخفيًا ثم نشره لاحقًا.',
                        ),
                ),
              ),
              if (_submissionError != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _submissionError!,
                    key: const Key('offer-form-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: offerText(context, 'حفظ العرض'),
                child: FilledButton.icon(
                  key: const Key('offer-submit-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(offerText(context, 'حفظ العرض')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final input = PublicOfferInput(
      gameId: _selectedGameId ?? '',
      nameAr: _nameArController.text,
      nameFr: _nameFrController.text,
      rewardQuantity: int.parse(_quantityController.text),
      salePriceDzd: int.parse(_priceController.text),
      isPublished: _isPublished,
      sortOrder: int.parse(_sortOrderController.text),
    );
    final controller = ref.read(offersControllerProvider.notifier);
    final result = widget.offer == null
        ? await controller.createOffer(input)
        : await controller.updateOffer(
            offerId: widget.offer!.id,
            input: input,
          );
    if (!mounted) {
      return;
    }

    if (result.isSuccess) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSubmitting = false;
      _submissionError = _mutationErrorText(context, result);
    });
  }
}

String? _requiredNameError(BuildContext context, String? value) {
  if (value == null || value.trim().isEmpty) {
    return offerText(context, 'الاسم مطلوب');
  }
  return null;
}

String? _positiveIntegerError(BuildContext context, String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed <= 0) {
    return offerText(context, 'أدخل رقمًا أكبر من صفر');
  }
  return null;
}

Game? _findGame(List<Game> games, String? gameId) {
  if (gameId == null) {
    return null;
  }
  for (final game in games) {
    if (game.id == gameId) {
      return game;
    }
  }
  return null;
}

String _gameName(BuildContext context, Game game) {
  return AppTranslator.isFrench(context) ? game.nameFr : game.nameAr;
}

String _rewardUnit(BuildContext context, Game game) {
  return AppTranslator.isFrench(context)
      ? game.rewardUnitNameFr
      : game.rewardUnitNameAr;
}

String _failureText(BuildContext context, PlatformFailureCode? code) {
  final source = switch (code) {
    PlatformFailureCode.networkUnavailable => 'لا يوجد اتصال بالمنصة.',
    PlatformFailureCode.sessionExpired => 'انتهت الجلسة.',
    PlatformFailureCode.unauthorized => 'الحساب غير مخول لإدارة المنصة.',
    PlatformFailureCode.notFound => 'العرض غير موجود.',
    PlatformFailureCode.validation => 'تحقق من بيانات العرض.',
    PlatformFailureCode.malformedResponse => 'استجابة المنصة غير صالحة.',
    PlatformFailureCode.temporarilyUnavailable => 'المنصة غير متاحة مؤقتًا.',
    PlatformFailureCode.duplicateSlug ||
    PlatformFailureCode.dependencyExists ||
    PlatformFailureCode.unknown ||
    null => 'حدث خطأ آمن. أعد المحاولة.',
  };
  return offerText(context, source);
}

String _mutationErrorText(
  BuildContext context,
  OffersMutationResult result,
) {
  if (result.status == OffersMutationStatus.busy) {
    return offerText(context, 'عملية حفظ العرض قيد التنفيذ.');
  }
  if (result.status == OffersMutationStatus.validationFailure) {
    if (result.validationIssues.any(
      (issue) =>
          issue.field == PlatformValidationField.selectedGameIsActive &&
          issue.code == PlatformValidationCode.inactiveGame,
    )) {
      return offerText(
        context,
        'لا يمكن نشر عرض تابع للعبة غير فعالة.',
      );
    }
    if (result.validationIssues.any(
      (issue) => issue.field == PlatformValidationField.gameId,
    )) {
      return offerText(context, 'اختيار اللعبة مطلوب.');
    }
    return offerText(context, 'تحقق من بيانات العرض.');
  }
  return _failureText(context, result.failureCode);
}

void _showMutationResult(
  BuildContext context,
  OffersMutationResult result,
) {
  if (result.isSuccess) {
    final message = result.refreshFailureCode == null
        ? offerText(context, 'تم تحديث حالة النشر.')
        : offerText(
            context,
            'تم الحفظ، لكن تعذر تحديث القائمة. البيانات المعروضة قديمة.',
          );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_mutationErrorText(context, result))),
  );
}
