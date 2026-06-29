import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouchi_master/core/database/app_database.dart';
import 'package:ouchi_master/core/database/seed_data.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDatabase(db);
  });

  tearDown(() async => db.close());

  test('子どもを4人まで登録できる', () async {
    for (final name in ['はる', 'あきら', 'ゆみ', 'ゆうすけ']) {
      await db.into(db.children).insert(
        ChildrenCompanion.insert(name: name, color: '#FF0000'),
      );
    }
    final children = await db.select(db.children).get();
    expect(children.length, equals(4));
  });

  test('子どもを削除するとDBから消える', () async {
    final id = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'はる', color: '#FF6B6B'),
    );
    await (db.delete(db.children)..where((c) => c.id.equals(id))).go();
    final children = await db.select(db.children).get();
    expect(children, isEmpty);
  });

  test('子どもを削除するとそのきろくがソフトデリートされる', () async {
    final childId = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'はる', color: '#FF6B6B'),
    );
    // きろくを2件追加
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'おさらあらい', points: 30));
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'テーブルふき', points: 10));

    // 子どもを削除（きろくをソフトデリートしてから子どもを削除）
    await (db.update(db.activityLogs)
          ..where((l) => l.childId.equals(childId)))
        .write(ActivityLogsCompanion(deletedAt: Value(DateTime.now())));
    await (db.delete(db.children)
          ..where((c) => c.id.equals(childId)))
        .go();

    // 当月ポイントは0になっている
    final points = await db.activityLogsDao
        .watchCurrentMonthPoints(childId)
        .first;
    expect(points, equals(0));

    // きろくはソフトデリート済み（物理的にはDB上に残る）
    final allLogs = await db.select(db.activityLogs).get();
    expect(allLogs.length, equals(2));
    expect(allLogs.every((l) => l.deletedAt != null), isTrue);
  });
}
