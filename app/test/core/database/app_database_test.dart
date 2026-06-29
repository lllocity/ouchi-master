import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouchi_master/core/database/app_database.dart';
import 'package:ouchi_master/core/database/seed_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('データベースが開きスキーマバージョンが1である', () {
    expect(db.schemaVersion, equals(1));
  });

  test('子どもを挿入・取得できる', () async {
    final id = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'はる', color: '#FF6B6B'),
    );
    final child = await (db.select(db.children)
          ..where((c) => c.id.equals(id)))
        .getSingle();
    expect(child.name, equals('はる'));
    expect(child.color, equals('#FF6B6B'));
  });

  test('シードが5カテゴリを挿入する', () async {
    await seedDatabase(db);
    final cats = await db.select(db.categories).get();
    expect(cats.length, equals(5));
    expect(cats.map((c) => c.name),
        containsAll(['ごはん', 'せんたく', 'そうじ', 'その他', 'げんてん']));
  });

  test('シードが19件のお手伝いテンプレートを挿入する', () async {
    await seedDatabase(db);
    final templates = await db.select(db.choreTemplates).get();
    expect(templates.length, equals(19));
  });

  test('シードは冪等 — 2回呼んでも重複しない', () async {
    await seedDatabase(db);
    await seedDatabase(db);
    final cats = await db.select(db.categories).get();
    expect(cats.length, equals(5));
  });

  test('アクティビティログを挿入・取得できる', () async {
    final childId = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'あきら', color: '#4ECDC4'),
    );
    final logId = await db.into(db.activityLogs).insert(
      ActivityLogsCompanion.insert(
        childId: childId,
        choreName: 'おさらあらい',
        points: 30,
      ),
    );
    final log = await (db.select(db.activityLogs)
          ..where((l) => l.id.equals(logId)))
        .getSingle();
    expect(log.choreName, equals('おさらあらい'));
    expect(log.points, equals(30));
    expect(log.deletedAt, isNull);
  });
}
