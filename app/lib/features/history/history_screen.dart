import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

// 月ごとのサマリーデータクラス
class _MonthSummary {
  final int year, month;
  final Map<int, int> pointsByChildId;
  final List<ActivityLog> logs;
  _MonthSummary({
    required this.year,
    required this.month,
    required this.pointsByChildId,
    required this.logs,
  });
}

// 月次履歴プロバイダー（削除済みを除外・新しい月順）
final _historyProvider = FutureProvider<List<_MonthSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await (db.select(db.activityLogs)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.desc(l.recordedAt)]))
      .get();

  // 年月のユニークなセットを抽出
  final keys = <String>{};
  for (final l in logs) {
    keys.add('${l.recordedAt.year}-${l.recordedAt.month}');
  }

  return keys
      .toList()
      .map((k) {
        final parts = k.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final ml = logs
            .where((l) =>
                l.recordedAt.year == y && l.recordedAt.month == m)
            .toList();
        final byChild = <int, int>{};
        for (final l in ml) {
          byChild[l.childId] = (byChild[l.childId] ?? 0) + l.points;
        }
        return _MonthSummary(
            year: y, month: m, pointsByChildId: byChild, logs: ml);
      })
      .toList()
    ..sort((a, b) => a.year != b.year
        ? b.year.compareTo(a.year)
        : b.month.compareTo(a.month));
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(_historyProvider);
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('過去のきろく')),
      body: histAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return const Center(
              child: Text('まだきろくがありません',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }
          return childrenAsync.when(
            data: (children) {
              final childMap = {for (final c in children) c.id: c};
              return ListView.builder(
                itemCount: summaries.length,
                itemBuilder: (_, i) {
                  final s = summaries[i];
                  return _MonthTile(
                      summary: s, childMap: childMap);
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('エラー')),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final _MonthSummary summary;
  final Map<int, ChildrenData> childMap;
  const _MonthTile({required this.summary, required this.childMap});

  @override
  Widget build(BuildContext context) {
    // サブタイトル：「はる: 340P  あきら: 280P」
    final subtitle = summary.pointsByChildId.entries
        .map((e) => '${childMap[e.key]?.name ?? '?'}: ${e.value}P')
        .join('   ');

    return ExpansionTile(
      title: Text('${summary.year}年${summary.month}月',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 13)),
      children: summary.logs.map((log) {
        final neg = log.points < 0;
        final childName = childMap[log.childId]?.name ?? '?';
        final dt = log.recordedAt;
        return ListTile(
          dense: true,
          leading: SizedBox(
            width: 72,
            child: Text(
              '${dt.month}/${dt.day} ${dt.hour}時',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey),
            ),
          ),
          title: Text(log.choreName,
              style: const TextStyle(fontSize: 14)),
          trailing: Text(
            '${neg ? '' : '+'}${log.points}P  $childName',
            style: TextStyle(
                color: neg ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }
}
