import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/setup/setup_screen.dart';

class OuchiMasterApp extends ConsumerWidget {
  const OuchiMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ouchi-master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF6B9FFF)),
        useMaterial3: true,
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    return childrenAsync.when(
      data: (children) =>
          children.isEmpty ? const SetupScreen() : const DashboardScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('エラー: $e'))),
    );
  }
}
