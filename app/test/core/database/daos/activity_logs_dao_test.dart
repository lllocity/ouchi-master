import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouchi_master/core/database/app_database.dart';
import 'package:ouchi_master/core/database/seed_data.dart';

void main() {
  late AppDatabase db;
  late int childId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDatabase(db);
    childId = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'テスト', color: '#FF0000'),
    );
  });

  tearDown(() async => db.close());

  test('ログがない場合、当月ポイントは0', () async {
    final points =
        await db.activityLogsDao.watchCurrentMonthPoints(childId).first;
    expect(points, equals(0));
  });

  test('当月ポイントが正しく合計される', () async {
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'テスト', points: 30));
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'テスト2', points: 20));
    final points =
        await db.activityLogsDao.watchCurrentMonthPoints(childId).first;
    expect(points, equals(50));
  });

  test('ソフトデリートしたログはポイント集計から除外される', () async {
    final logId = await db.activityLogsDao.insertLog(
      ActivityLogsCompanion.insert(
          childId: childId, choreName: 'テスト', points: 30),
    );
    await db.activityLogsDao.softDelete(logId);
    final points =
        await db.activityLogsDao.watchCurrentMonthPoints(childId).first;
    expect(points, equals(0));
  });

  test('watchRecentByChild は削除済みログを除外する', () async {
    final logId = await db.activityLogsDao.insertLog(
      ActivityLogsCompanion.insert(
          childId: childId, choreName: '削除対象', points: 10),
    );
    await db.activityLogsDao.insertLog(
      ActivityLogsCompanion.insert(
          childId: childId, choreName: '残るログ', points: 20),
    );
    await db.activityLogsDao.softDelete(logId);
    final logs =
        await db.activityLogsDao.watchRecentByChild(childId).first;
    expect(logs.length, equals(1));
    expect(logs.first.choreName, equals('残るログ'));
  });
}
