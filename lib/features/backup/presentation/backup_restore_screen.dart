import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/section_card.dart';
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
                const Text('ينشئ ملف JSON يتضمن المنتجات والباقات والعمليات والمخزون والإعدادات.'),
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
                const Text('يُتحقق من إصدار الملف وبنيته قبل استبدال البيانات الحالية.'),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('اختيار ملف JSON'),
                ),
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
                const Text('يحذف كل العمليات والتعديلات ويعيد الباقات والمنتج الافتراضيين.'),
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
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/game-credit-backup-$timestamp.json');
      await file.writeAsString(AppDatabase.encodeBackup(data), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية لمدير رصيد الألعاب',
      );
      _message('تم إنشاء النسخة بنجاح.');
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
    final confirmed = await _confirm(
      'استبدال البيانات الحالية؟',
      'سيتم استبدال جميع بيانات التطبيق بمحتوى النسخة المختارة بعد التحقق منها.',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final content = await File(path).readAsString();
      final payload = AppDatabase.decodeBackup(content);
      await ref.read(appRepositoryProvider).importBackup(payload);
      invalidateAppData(ref);
      _message('تم استيراد النسخة والتحقق منها.');
    } catch (error) {
      _message('لم يتم الاستيراد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await _confirm(
      'إعادة التهيئة؟',
      'سيتم حذف العمليات والمخزون والتعديلات نهائيًا من هذا الجهاز.',
    );
    if (!confirmed) return;
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

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
          ],
        ),
      ) ??
      false;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
