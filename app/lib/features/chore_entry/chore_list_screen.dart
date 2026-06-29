import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class ChoreListScreen extends ConsumerWidget {
  final ChildrenData child;
  final Category category;
  const ChoreListScreen(
      {super.key, required this.child, required this.category});

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, ChoreTemplate t) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${child.name} が ${t.name}'),
        content: Text(
          '${t.points > 0 ? '+' : ''}${t.points}P',
          style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: t.points < 0 ? Colors.red : Colors.green),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('できた！', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.activityLogsDao.insertLog(
        ActivityLogsCompanion.insert(
          childId: child.id,
          choreName: t.name,
          points: t.points,
        ),
      );
      // ダッシュボードまで全部戻る
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync =
        ref.watch(choreTemplatesByCategoryProvider(category.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.emoji} ${category.name}  ／  ${child.name}'),
      ),
      body: templatesAsync.when(
        data: (templates) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          itemBuilder: (ctx, i) {
            final t = templates[i];
            final neg = t.points < 0;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 8),
                title: Text(t.name,
                    style: const TextStyle(fontSize: 20)),
                trailing: Text(
                  '${neg ? '' : '+'}${t.points}P',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: neg ? Colors.red : Colors.green),
                ),
                onTap: () => _confirm(ctx, ref, t),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
