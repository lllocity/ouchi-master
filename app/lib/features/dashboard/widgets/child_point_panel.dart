import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import 'activity_log_list.dart';

class ChildPointPanel extends ConsumerWidget {
  final ChildrenData child;
  const ChildPointPanel({super.key, required this.child});

  Color get _color {
    final h = child.color.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(currentMonthPointsProvider(child.id));
    final logsAsync = ref.watch(recentActivitiesProvider(child.id));

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color, width: 2),
      ),
      child: Column(
        children: [
          Text(child.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          pointsAsync.when(
            data: (pts) => Text(
              '★ $pts P ★',
              style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: _color),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('エラー'),
          ),
          const Text('今月の合計',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const Divider(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('📋 直近のきろく',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          logsAsync.when(
            data: (logs) => ActivityLogList(logs: logs),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('エラー'),
          ),
        ],
      ),
    );
  }
}
