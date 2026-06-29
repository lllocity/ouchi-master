import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'database/seed_data.dart';

/// アプリ全体で共有するDBインスタンス。起動時に1回だけ生成される。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  seedDatabase(db);
  ref.onDispose(db.close);
  return db;
});

/// 子ども一覧（リアルタイム）
final childrenProvider = StreamProvider<List<ChildrenData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.children).watch();
});

/// カテゴリ一覧（sortOrder 順）
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .watch();
});

/// カテゴリ別お手伝いテンプレート（isActive=true のみ）
final choreTemplatesByCategoryProvider =
    StreamProvider.family<List<ChoreTemplate>, int>((ref, categoryId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.choreTemplates)
        ..where((t) =>
            t.categoryId.equals(categoryId) & t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

/// 子ども別・当月ポイント合計（リアルタイム）
final currentMonthPointsProvider =
    StreamProvider.family<int, int>((ref, childId) {
  final db = ref.watch(databaseProvider);
  return db.activityLogsDao.watchCurrentMonthPoints(childId);
});

/// 子ども別・直近10件のきろく（リアルタイム）
final recentActivitiesProvider =
    StreamProvider.family<List<ActivityLog>, int>((ref, childId) {

  final db = ref.watch(databaseProvider);
  return db.activityLogsDao.watchRecentByChild(childId);
});
