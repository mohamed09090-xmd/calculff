import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/games/games_controller.dart';
import '../../application/games/games_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/games/game.dart';
import '../../domain/games/game_input.dart';
import '../platform_ui_text.dart';
import 'game_editor_sheet.dart';

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Game? game,
  }) async {
    final input = await showModalBottomSheet<GameInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => GameEditorSheet(game: game),
    );
    if (input == null || !context.mounted) {
      return;
    }

    final controller = ref.read(gamesControllerProvider.notifier);
    final failure = game == null
        ? await controller.createGame(input)
        : await controller.updateGame(gameId: game.id, input: input);
    if (!context.mounted) {
      return;
    }
    _showActionResult(context, failure, isEditing: game != null);
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    Game game,
    bool isActive,
  ) async {
    final failure = await ref
        .read(gamesControllerProvider.notifier)
        .setGameActive(gameId: game.id, isActive: isActive);
    if (!context.mounted) {
      return;
    }
    _showActionResult(context, failure, activeState: isActive);
  }

  void _showActionResult(
    BuildContext context,
    PlatformFailure? failure, {
    bool isEditing = false,
    bool? activeState,
  }) {
    final String message;
    if (failure != null) {
      message = platformDataFailureText(context, failure);
    } else if (activeState != null) {
      message = activeState
          ? platformText(context, 'تم تفعيل اللعبة.')
          : platformText(context, 'تم تعطيل اللعبة.');
    } else {
      message = isEditing
          ? platformText(context, 'تم تحديث اللعبة.')
          : platformText(context, 'تمت إضافة اللعبة.');
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamesControllerProvider);
    final controller = ref.read(gamesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Semantics(
        button: true,
        label: platformText(context, 'إضافة لعبة'),
        child: FloatingActionButton.extended(
          key: const Key('add-game-button'),
          onPressed: state.isSubmitting
              ? null
              : () => _openEditor(context, ref),
          icon: const Icon(Icons.add),
          label: Text(platformText(context, 'إضافة لعبة')),
        ),
      ),
      body: RefreshIndicator(
        key: const Key('games-refresh-indicator'),
        onRefresh: controller.refresh,
        child: ListView(
          key: const Key('games-list-view'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            _GamesHeader(
              isRefreshing: state.isRefreshing,
              onRefresh: controller.refresh,
            ),
            const SizedBox(height: 16),
            if (state.hasStaleData)
              _StaleDataBanner(failure: state.loadFailure!),
            if (state.hasStaleData) const SizedBox(height: 12),
            if (state.status == GamesLoadStatus.loading && state.games.isEmpty)
              const _GamesLoadingState()
            else if (state.games.isEmpty &&
                state.status == GamesLoadStatus.offline)
              _GamesFailureState(
                icon: Icons.cloud_off_outlined,
                title: platformText(context, 'لا يوجد اتصال بالمنصة.'),
                message: platformDataFailureText(
                  context,
                  state.loadFailure ??
                      const PlatformFailure(
                        PlatformFailureCode.networkUnavailable,
                      ),
                ),
                onRetry: controller.refresh,
              )
            else if (state.games.isEmpty &&
                state.status == GamesLoadStatus.error)
              _GamesFailureState(
                icon: Icons.error_outline,
                title: platformText(context, 'تعذر تحميل الألعاب.'),
                message: platformDataFailureText(
                  context,
                  state.loadFailure ??
                      const PlatformFailure(PlatformFailureCode.unknown),
                ),
                onRetry: controller.refresh,
              )
            else if (state.isEmpty)
              _GamesEmptyState(
                onAdd: state.isSubmitting
                    ? null
                    : () => _openEditor(context, ref),
              )
            else
              for (final game in state.games) ...[
                _GameCard(
                  game: game,
                  isBusy: state.isSubmitting,
                  onEdit: () => _openEditor(context, ref, game: game),
                  onActiveChanged: (value) =>
                      _setActive(context, ref, game, value),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _GamesHeader extends StatelessWidget {
  const _GamesHeader({required this.isRefreshing, required this.onRefresh});

  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                platformText(context, 'إدارة الألعاب'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                platformText(
                  context,
                  'أضف الألعاب وعدّل بياناتها أو فعّلها وعطّلها.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: platformText(context, 'تحديث الألعاب'),
          child: IconButton.filledTonal(
            key: const Key('refresh-games-button'),
            tooltip: platformText(context, 'تحديث الألعاب'),
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}

class _GamesLoadingState extends StatelessWidget {
  const _GamesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: platformText(context, 'جارٍ تحميل الألعاب.'),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _GamesFailureState extends StatelessWidget {
  const _GamesFailureState({
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: platformText(context, 'إعادة المحاولة'),
                  child: FilledButton.tonalIcon(
                    key: const Key('games-retry-button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(platformText(context, 'إعادة المحاولة')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GamesEmptyState extends StatelessWidget {
  const _GamesEmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.sports_esports_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  platformText(context, 'لا توجد ألعاب بعد.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  platformText(
                    context,
                    'أضف أول لعبة لبدء إدارة العروض لاحقًا.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('empty-add-game-button'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(platformText(context, 'إضافة أول لعبة')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaleDataBanner extends StatelessWidget {
  const _StaleDataBanner({required this.failure});

  final PlatformFailure failure;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: platformText(context, 'البيانات المعروضة قديمة.'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history_toggle_off_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${platformText(context, 'البيانات المعروضة قديمة.')} '
                  '${platformDataFailureText(context, failure)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.isBusy,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final Game game;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    final primaryName = isFrench ? game.nameFr : game.nameAr;
    final secondaryName = isFrench ? game.nameAr : game.nameFr;
    final rewardName = isFrench ? game.rewardUnitNameFr : game.rewardUnitNameAr;
    final toggleLabel = game.isActive
        ? platformText(context, 'تعطيل اللعبة')
        : platformText(context, 'تفعيل اللعبة');

    return Semantics(
      container: true,
      label: '${platformText(context, 'لعبة')} $primaryName',
      child: Card(
        key: Key('game-card-${game.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(secondaryName),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      game.isActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      game.isActive
                          ? platformText(context, 'فعّالة')
                          : platformText(context, 'معطّلة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.link,
                    label:
                        '${platformText(context, 'المعرّف النصي')}: ${game.slug}',
                  ),
                  _InfoChip(
                    icon: Icons.stars_outlined,
                    label: '$rewardName (${game.rewardUnitCode})',
                  ),
                  _InfoChip(
                    icon: Icons.sort,
                    label:
                        '${platformText(context, 'ترتيب العرض')}: ${game.sortOrder}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Semantics(
                    button: true,
                    label:
                        '${platformText(context, 'تعديل اللعبة')} $primaryName',
                    child: OutlinedButton.icon(
                      key: Key('edit-game-${game.id}'),
                      onPressed: isBusy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(platformText(context, 'تعديل')),
                    ),
                  ),
                  Semantics(
                    toggled: game.isActive,
                    label: '$toggleLabel $primaryName',
                    child: Switch.adaptive(
                      key: Key('toggle-game-${game.id}'),
                      value: game.isActive,
                      onChanged: isBusy ? null : onActiveChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
