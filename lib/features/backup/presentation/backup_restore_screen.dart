import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


import '../../../core/localization/app_translator.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../../shared/models/backup_preview.dart';
import '../../../shared/providers/app_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: AppStrings.backup,
      body: ListView(
        children: [
          SectionCard(
            title: 'تصدير نسخة',
            icon: Icons.upload_file_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ينشئ ملف JSON يتضمن العملاء والمنتجات والباقات والعمليات والمخزون والإعدادات.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('إنشاء ومشاركة النسخة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'استيراد نسخة',
            icon: Icons.download_for_offline_outlined,
            accent: Theme.of(context).colorScheme.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يُفحص الملف وتُعرض محتوياته أولًا. لا تُستبدل البيانات إلا بعد التحقق والتأكيد.',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('اختيار وفحص ملف JSON'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'ضمانات الاستعادة',
            icon: Icons.verified_user_outlined,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• التحقق من نوع الملف وإصدار قاعدة البيانات.'),
                SizedBox(height: 6),
                Text('• دعم النسخ القديمة وتحويل أسماء العملاء تلقائيًا.'),
                SizedBox(height: 6),
                Text('• تنفيذ الاستيراد داخل معاملة واحدة قابلة للتراجع عند الخطأ.'),
                SizedBox(height: 6),
                Text('• عدم حذف البيانات الحالية إذا كان الملف تالفًا.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'إعادة البيانات الافتراضية',
            icon: Icons.restart_alt,
            accent: Theme.of(context).colorScheme.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يحذف كل العملاء والعمليات والتعديلات ويعيد الباقات والمنتج الافتراضيين.',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reset,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('مسح وإعادة التهيئة'),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(appRepositoryProvider).exportBackup();
      final preview = AppDatabase.inspectBackup(data);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());
      final file = File(
        '${directory.path}/game-credit-backup-v${preview.version}-$timestamp.json',
      );
      await file.writeAsString(AppDatabase.encodeBackup(data), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: AppTranslator.translate(context, 'نسخة احتياطية لمدير رصيد الألعاب'),
        text: '${preview.transactionCount} عملية • '
            '${preview.customerCount} عميل',
      );
      _message('تم إنشاء نسخة تحتوي على ${preview.transactionCount} عملية.');
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    Map<String, Object?> payload;
    BackupPreview preview;
    try {
      final content = await File(path).readAsString();
      payload = AppDatabase.decodeBackup(content);
      preview = AppDatabase.inspectBackup(payload);
    } catch (error) {
      _message('الملف غير صالح: $error');
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmImport(preview);
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).importBackup(payload);
      invalidateAppData(ref);
      _message(
        'تم استيراد ${preview.transactionCount} عملية و'
        '${preview.customerCount} عميل بنجاح.',
      );
    } catch (error) {
      _message('لم يتم الاستيراد، وبقيت بياناتك الحالية كما هي: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await _confirm(
      'إعادة التهيئة؟',
      'سيتم حذف العملاء والعمليات والمخزون والتعديلات نهائيًا من هذا الجهاز.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).resetToDefaults();
      invalidateAppData(ref);
      _message('أُعيدت البيانات الافتراضية.');
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmImport(BackupPreview preview) async {
    final exportedAt = preview.exportedAt == null
        ? 'غير متوفر'
        : DateFormat('dd/MM/yyyy HH:mm').format(preview.exportedAt!);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('مراجعة النسخة قبل الاستيراد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(label: 'إصدار النسخة', value: '${preview.version}'),
                  _PreviewRow(label: 'تاريخ التصدير', value: exportedAt),
                  _PreviewRow(label: 'العملاء', value: '${preview.customerCount}'),
                  _PreviewRow(
                    label: 'العمليات',
                    value: '${preview.transactionCount}',
                  ),
                  _PreviewRow(label: 'المنتجات', value: '${preview.productCount}'),
                  _PreviewRow(label: 'الباقات', value: '${preview.packageCount}'),
                  _PreviewRow(
                    label: 'رزم المخزون',
                    value: '${preview.inventoryLotCount}',
                  ),
                  if (preview.isLegacy) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'هذه نسخة قديمة متوافقة. سيحوّل التطبيق أسماء العملاء إلى سجلات عملاء تلقائيًا.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'بعد التأكيد ستُستبدل كل البيانات الحالية بهذه النسخة.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استيراد النسخة'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
