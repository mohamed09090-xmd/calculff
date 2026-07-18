import 'package:flutter/material.dart';

import '../../domain/common/platform_validation.dart';
import '../../domain/games/game.dart';
import '../../domain/games/game_input.dart';
import '../platform_ui_text.dart';

class GameEditorSheet extends StatefulWidget {
  const GameEditorSheet({super.key, this.game});

  final Game? game;

  @override
  State<GameEditorSheet> createState() => _GameEditorSheetState();
}

class _GameEditorSheetState extends State<GameEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _slugController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameFrController;
  late final TextEditingController _rewardCodeController;
  late final TextEditingController _rewardNameArController;
  late final TextEditingController _rewardNameFrController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;

  bool get _isEditing => widget.game != null;

  @override
  void initState() {
    super.initState();
    final game = widget.game;
    _slugController = TextEditingController(text: game?.slug ?? '');
    _nameArController = TextEditingController(text: game?.nameAr ?? '');
    _nameFrController = TextEditingController(text: game?.nameFr ?? '');
    _rewardCodeController = TextEditingController(
      text: game?.rewardUnitCode ?? '',
    );
    _rewardNameArController = TextEditingController(
      text: game?.rewardUnitNameAr ?? '',
    );
    _rewardNameFrController = TextEditingController(
      text: game?.rewardUnitNameFr ?? '',
    );
    _sortOrderController = TextEditingController(
      text: (game?.sortOrder ?? 0).toString(),
    );
    _isActive = game?.isActive ?? false;
  }

  @override
  void dispose() {
    _slugController.dispose();
    _nameArController.dispose();
    _nameFrController.dispose();
    _rewardCodeController.dispose();
    _rewardNameArController.dispose();
    _rewardNameFrController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  GameInput _input() {
    return GameInput(
      slug: _slugController.text,
      nameAr: _nameArController.text,
      nameFr: _nameFrController.text,
      rewardUnitCode: _rewardCodeController.text,
      rewardUnitNameAr: _rewardNameArController.text,
      rewardUnitNameFr: _rewardNameFrController.text,
      isActive: _isActive,
      sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? -1,
    );
  }

  String? _validateField(PlatformValidationField field) {
    for (final issue in _input().validate()) {
      if (issue.field == field) {
        return _validationIssueText(context, issue);
      }
    }
    return null;
  }

  String? _validateSortOrder(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return platformText(context, 'أدخل ترتيبًا صحيحًا يبدأ من صفر.');
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_input());
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'تعديل اللعبة' : 'إضافة لعبة';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    platformText(context, title),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('game-slug-field'),
                    controller: _slugController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: platformText(context, 'المعرّف النصي'),
                      helperText: platformText(
                        context,
                        'أحرف إنجليزية صغيرة وأرقام وشرطات فقط.',
                      ),
                    ),
                    validator: (_) =>
                        _validateField(PlatformValidationField.slug),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-name-ar-field'),
                    controller: _nameArController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: platformText(context, 'اسم اللعبة بالعربية'),
                    ),
                    validator: (_) =>
                        _validateField(PlatformValidationField.nameAr),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-name-fr-field'),
                    controller: _nameFrController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: platformText(context, 'اسم اللعبة بالفرنسية'),
                    ),
                    validator: (_) =>
                        _validateField(PlatformValidationField.nameFr),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-reward-code-field'),
                    controller: _rewardCodeController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: platformText(context, 'رمز وحدة المكافأة'),
                      helperText: platformText(
                        context,
                        'أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط.',
                      ),
                    ),
                    validator: (_) => _validateField(
                      PlatformValidationField.rewardUnitCode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-reward-name-ar-field'),
                    controller: _rewardNameArController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: platformText(
                        context,
                        'اسم وحدة المكافأة بالعربية',
                      ),
                    ),
                    validator: (_) => _validateField(
                      PlatformValidationField.rewardUnitNameAr,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-reward-name-fr-field'),
                    controller: _rewardNameFrController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: platformText(
                        context,
                        'اسم وحدة المكافأة بالفرنسية',
                      ),
                    ),
                    validator: (_) => _validateField(
                      PlatformValidationField.rewardUnitNameFr,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('game-sort-order-field'),
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: platformText(context, 'ترتيب العرض'),
                    ),
                    validator: _validateSortOrder,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    toggled: _isActive,
                    label: platformText(context, 'اللعبة فعّالة'),
                    child: SwitchListTile.adaptive(
                      key: const Key('game-active-field'),
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      title: Text(platformText(context, 'اللعبة فعّالة')),
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(platformText(context, 'إلغاء')),
                      ),
                      Semantics(
                        button: true,
                        label: platformText(context, 'حفظ اللعبة'),
                        child: FilledButton.icon(
                          key: const Key('save-game-button'),
                          onPressed: _submit,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(platformText(context, 'حفظ اللعبة')),
                        ),
                      ),
                    ],
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

String _validationIssueText(
  BuildContext context,
  PlatformValidationIssue issue,
) {
  final source = switch (issue.code) {
    PlatformValidationCode.required => 'هذا الحقل مطلوب.',
    PlatformValidationCode.tooShort => 'القيمة قصيرة جدًا.',
    PlatformValidationCode.tooLong => 'القيمة طويلة جدًا.',
    PlatformValidationCode.mustBeLowercase =>
      'استخدم أحرفًا إنجليزية صغيرة فقط.',
    PlatformValidationCode.invalidFormat => 'صيغة القيمة غير صحيحة.',
    PlatformValidationCode.mustBePositive => 'يجب أن تكون القيمة أكبر من صفر.',
    PlatformValidationCode.inactiveGame => 'اللعبة المحددة غير فعّالة.',
    PlatformValidationCode.containsControlCharacters =>
      'تحتوي القيمة على محارف غير مسموحة.',
    PlatformValidationCode.invalidRange => 'النطاق غير صحيح.',
  };
  return platformText(context, source);
}
