import 'package:drift/drift.dart';
import '../app_database.dart';

part 'activity_logs_dao.g.dart';

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogsDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogsDaoMixin {
  ActivityLogsDao(super.db);

  Future<int> insertLog(ActivityLogsCompanion log) =>
      into(activityLogs).insert(log);

  Stream<int> watchCurrentMonthPoints(int childId) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return (selectOnly(activityLogs)
          ..addColumns([activityLogs.points.sum()])
          ..where(activityLogs.childId.equals(childId) &
              activityLogs.recordedAt.isBiggerOrEqualValue(monthStart) &
              activityLogs.deletedAt.isNull()))
        .watchSingle()
        .map((row) => row.read(activityLogs.points.sum()) ?? 0);
  }

  Stream<List<ActivityLog>> watchRecentByChild(int childId,
      {int limit = 10}) {
    return (select(activityLogs)
          ..where((l) =>
              l.childId.equals(childId) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Stream<List<ActivityLog>> watchAllByChild(int childId) {
    return (select(activityLogs)
          ..where((l) =>
              l.childId.equals(childId) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.recordedAt)]))
        .watch();
  }

  Future<void> softDelete(int logId) async {
    await (update(activityLogs)..where((l) => l.id.equals(logId)))
        .write(ActivityLogsCompanion(
            deletedAt: Value(DateTime.now())));
  }
}
