import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/app_providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(initializationProvider);
    return Scaffold(
      body: Center(
        child: initialization.when(
          data: (_) => const _ReadyRedirect(),
          loading: () => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stacked_line_chart, size: 64),
              SizedBox(height: 18),
              Text(AppStrings.appName, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 54),
                const SizedBox(height: 16),
                const Text('تعذر تهيئة قاعدة البيانات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(initializationProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyRedirect extends StatefulWidget {
  const _ReadyRedirect();

  @override
  State<_ReadyRedirect> createState() => _ReadyRedirectState();
}

class _ReadyRedirectState extends State<_ReadyRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}
