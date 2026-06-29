import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

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

final _historyProvider = FutureProvider<List<_MonthSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await (db.select(db.activityLogs)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.desc(l.recordedAt)]))
      .get();

  final keys = <String>{};
  for (final l in logs) {
    keys.add('${l.recordedAt.year}-${l.recordedAt.month}');
  }

  return keys.toList().map((k) {
    final parts = k.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final ml = logs
        .where((l) => l.recordedAt.year == y && l.recordedAt.month == m)
        .toList();
    final byChild = <int, int>{};
    for (final l in ml) {
      byChild[l.childId] = (byChild[l.childId] ?? 0) + l.points;
    }
    return _MonthSummary(
        year: y, month: m, pointsByChildId: byChild, logs: ml);
  }).toList()
    ..sort((a, b) =>
        a.year != b.year ? b.year.compareTo(a.year) : b.month.compareTo(a.month));
});

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(_historyProvider);
    final childrenAsync = ref.watch(childrenProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          // ── ダッシュボードと同じグラデーションヘッダー ──
          Container(
            padding: EdgeInsets.fromLTRB(8, topPadding + 8, 8, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33FF6B6B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text('過去のきろく',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          // ── 本体 ──────────────────────────────────────
          Expanded(
            child: histAsync.when(
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
                      padding: const EdgeInsets.all(16),
                      itemCount: summaries.length,
                      itemBuilder: (_, i) =>
                          _MonthCard(summary: summaries[i], childMap: childMap),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('エラー')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final _MonthSummary summary;
  final Map<int, ChildrenData> childMap;
  const _MonthCard({required this.summary, required this.childMap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${summary.year}年${summary.month}月',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            children: summary.pointsByChildId.entries.map((e) {
              final child = childMap[e.key];
              final color = child != null
                  ? _hexToColor(child.color)
                  : Colors.grey;
              return Text(
                '${child?.name ?? '?'}: ${e.value}P',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color),
              );
            }).toList(),
          ),
        ),
        children: [
          const Divider(height: 1),
          ...summary.logs.map((log) {
            final neg = log.points < 0;
            final child = childMap[log.childId];
            final childColor = child != null
                ? _hexToColor(child.color)
                : Colors.grey;
            final dt = log.recordedAt;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      '${dt.month}/${dt.day} ${dt.hour}時',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: Text(log.choreName,
                        style: const TextStyle(fontSize: 15)),
                  ),
                  Text(
                    '${neg ? '' : '+'}${log.points}P',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: neg ? Colors.red : Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    child?.name ?? '?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: childColor),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
