import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';

class ActivityLogList extends ConsumerWidget {
  final List<ActivityLog> logs;
  const ActivityLogList({super.key, required this.logs});

  String _fmt(DateTime dt) => '${dt.month}/${dt.day} ${dt.hour}時';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('まだきろくがありません',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    return Column(
      children: logs.map((log) {
        final neg = log.points < 0;
        return Dismissible(
          key: ValueKey(log.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('きろくを取り消しますか？'),
              content: Text(
                  '${log.choreName}  ${neg ? '' : '+'}${log.points}P'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('キャンセル')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('取り消す',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          onDismissed: (_) async {
            await ref
                .read(databaseProvider)
                .activityLogsDao
                .softDelete(log.id);
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 12),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(_fmt(log.recordedAt),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(log.choreName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                Text(
                  '${neg ? '' : '+'}${log.points}P',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: neg ? Colors.red : Colors.green),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
