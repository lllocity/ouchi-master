# ouchi-master MVP 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter iPad アプリ ouchi-master MVP を構築する。子ども（はる・あきら）のお手伝いポイントをリアルタイムで記録・表示する家庭内ポイントシステム。

**Architecture:** シングルデバイス Flutter アプリ。全データを Drift（SQLite）でローカル保存。Riverpod で状態管理。ダッシュボード常時表示、3秒長押しでできたよモードへ切替。

**Tech Stack:** Flutter 3.19+, Dart 3.3+, drift 2.x, flutter_riverpod 2.x, confetti 0.7.x

## Global Constraints

- ターゲットプラットフォーム: iPadOS、横向き優先
- Flutter 最小バージョン: 3.19.0
- ユーザー向けテキストはすべて日本語
- activity_logs は物理削除禁止。ソフトデリート（`deleted_at`）のみ
- タイムスタンプ表示形式: `M/D H時`（例: `6/18 18時`）
- デフォルトお手伝いリストは設計書セクション8の通り（19項目）
- Flutter プロジェクトは `app/` サブディレクトリに作成

---

### Task 1: Flutter プロジェクト作成と依存関係設定

**Files:**
- Create: `app/` (Flutter プロジェクトルート)
- Modify: `app/pubspec.yaml`

**Interfaces:**
- Produces: 依存関係が揃った起動可能な Flutter プロジェクト

- [ ] **Step 1: Flutter プロジェクト作成**

```bash
cd /Users/lllocity/Projects/ouchi-master
flutter create app --project-name ouchi_master --platforms ios
```

期待出力: `All done! ... Your application code is in app/lib/main.dart`

- [ ] **Step 2: pubspec.yaml の dependencies を置き換え**

`app/pubspec.yaml` の `dependencies:` と `dev_dependencies:` セクションを以下で置き換える:

```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.20.0
  sqlite3_flutter_libs: ^0.5.4
  path_provider: ^2.1.3
  path: ^1.9.0
  flutter_riverpod: ^2.5.1
  confetti: ^0.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.20.0
  build_runner: ^2.4.9
```

- [ ] **Step 3: 依存関係インストール**

```bash
cd app
flutter pub get
```

期待: エラーなしで解決される

- [ ] **Step 4: 起動確認**

```bash
flutter run
```

期待: デフォルトの Flutter カウンターアプリが起動する

- [ ] **Step 5: コミット**

```bash
cd ..
git add app/
git commit -m "feat: scaffold Flutter project with dependencies"
```

---

### Task 2: Drift データベーススキーマ定義

**Files:**
- Create: `app/lib/core/database/app_database.dart`
- Create (generated): `app/lib/core/database/app_database.g.dart`
- Create: `app/test/core/database/app_database_test.dart`

**Interfaces:**
- Produces:
  - `AppDatabase` クラス（`_$AppDatabase` を継承）
  - テーブルデータクラス: `Child`, `Category`, `ChoreTemplate`, `ActivityLog`
  - Companion クラス: `ChildrenCompanion`, `CategoriesCompanion`, `ChoreTemplatesCompanion`, `ActivityLogsCompanion`
  - `openAppDatabase()` ファクトリ関数

- [ ] **Step 1: 失敗するテストを書く**

`app/test/core/database/app_database_test.dart` を作成:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouchi_master/core/database/app_database.dart';

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
```

- [ ] **Step 2: テスト実行 → 失敗を確認**

```bash
cd app
flutter test test/core/database/app_database_test.dart
```

期待: FAIL — `app_database.dart` が存在しないため

- [ ] **Step 3: データベーススキーマを作成**

`app/lib/core/database/app_database.dart` を作成:

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Children extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get sortOrder => integer()();
}

class ChoreTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get name => text()();
  IntColumn get points => integer()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer()();
}

class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId => integer().references(Children, #id)();
  TextColumn get choreName => text()();
  IntColumn get points => integer()();
  DateTimeColumn get recordedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Children, Categories, ChoreTemplates, ActivityLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

AppDatabase openAppDatabase() => AppDatabase(_openConnection());

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ouchi_master.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 4: Drift コード生成**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

期待: `app/lib/core/database/app_database.g.dart` が生成される

- [ ] **Step 5: テスト実行 → 全パスを確認**

```bash
flutter test test/core/database/app_database_test.dart
```

期待: 3 tests passed

- [ ] **Step 6: コミット**

```bash
cd ..
git add app/lib/core/ app/test/core/
git commit -m "feat: add Drift database schema"
```

---

### Task 3: シードデータ（デフォルトお手伝いマスター）

**Files:**
- Create: `app/lib/core/database/seed_data.dart`
- Modify: `app/test/core/database/app_database_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 2)
- Produces: `Future<void> seedDatabase(AppDatabase db)` — 冪等なシード関数

- [ ] **Step 1: シードテストを追加**

`app/test/core/database/app_database_test.dart` に追記（既存 `main()` 内):

```dart
// ファイル先頭に追加:
import 'package:ouchi_master/core/database/seed_data.dart';

// main() 内の既存テストの後に追加:
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
```

- [ ] **Step 2: テスト実行 → 失敗を確認**

```bash
cd app
flutter test test/core/database/app_database_test.dart
```

期待: FAIL — `seed_data.dart` が存在しないため

- [ ] **Step 3: seed_data.dart を作成**

`app/lib/core/database/seed_data.dart` を作成:

```dart
import 'package:drift/drift.dart';
import 'app_database.dart';

Future<void> seedDatabase(AppDatabase db) async {
  final existing = await db.select(db.categories).get();
  if (existing.isNotEmpty) return;

  const categoryData = [
    (name: 'ごはん',   emoji: '🍚', order: 0),
    (name: 'せんたく', emoji: '👕', order: 1),
    (name: 'そうじ',   emoji: '🧹', order: 2),
    (name: 'その他',   emoji: '📦', order: 3),
    (name: 'げんてん', emoji: '👎', order: 4),
  ];

  final ids = <String, int>{};
  for (final c in categoryData) {
    ids[c.name] = await db.into(db.categories).insert(
      CategoriesCompanion.insert(
          name: c.name, emoji: c.emoji, sortOrder: c.order),
    );
  }

  final templates = [
    (cat: 'ごはん',   name: 'ごはんをつくる',                    pts: 200, ord: 0),
    (cat: 'ごはん',   name: 'てつだう',                          pts: 50,  ord: 1),
    (cat: 'ごはん',   name: 'ごはんよそい',                      pts: 10,  ord: 2),
    (cat: 'ごはん',   name: 'カトラリー準備（はし・スプーン・おちゃわん）', pts: 10, ord: 3),
    (cat: 'ごはん',   name: 'テーブルふき',                      pts: 10,  ord: 4),
    (cat: 'ごはん',   name: 'おさらあらい',                      pts: 30,  ord: 5),
    (cat: 'せんたく', name: 'ほす',                              pts: 20,  ord: 0),
    (cat: 'せんたく', name: 'たたむ',                            pts: 20,  ord: 1),
    (cat: 'そうじ',   name: 'トイレそうじ',                      pts: 50,  ord: 0),
    (cat: 'そうじ',   name: 'クイックルワイパー 1F',              pts: 20,  ord: 1),
    (cat: 'そうじ',   name: 'クイックルワイパー 2F',              pts: 20,  ord: 2),
    (cat: 'そうじ',   name: 'クイックルワイパー 3F',              pts: 20,  ord: 3),
    (cat: 'そうじ',   name: 'ゆかふき 1F',                      pts: 50,  ord: 4),
    (cat: 'そうじ',   name: 'ゆかふき 2F',                      pts: 50,  ord: 5),
    (cat: 'そうじ',   name: 'ゆかふき 3F',                      pts: 50,  ord: 6),
    (cat: 'そうじ',   name: 'おふろそうじ',                      pts: 100, ord: 7),
    (cat: 'その他',   name: 'ゆうびん受け取り',                  pts: 10,  ord: 0),
    (cat: 'げんてん', name: '本だしっぱなし',                    pts: -10, ord: 0),
    (cat: 'げんてん', name: 'おもちゃだしっぱなし',              pts: -10, ord: 1),
  ];

  for (final t in templates) {
    await db.into(db.choreTemplates).insert(
      ChoreTemplatesCompanion.insert(
        categoryId: ids[t.cat]!,
        name: t.name,
        points: t.pts,
        sortOrder: t.ord,
      ),
    );
  }
}
```

- [ ] **Step 4: テスト実行 → 全パスを確認**

```bash
flutter test test/core/database/app_database_test.dart
```

期待: 6 tests passed

- [ ] **Step 5: コミット**

```bash
cd ..
git add app/lib/core/database/seed_data.dart app/test/
git commit -m "feat: add seed data with 19 default chore templates"
```

---

### Task 4: ActivityLogsDao（ポイント集計・ソフトデリート）

**Files:**
- Create: `app/lib/core/database/daos/activity_logs_dao.dart`
- Create: `app/lib/core/database/daos/activity_logs_dao.g.dart` (generated)
- Modify: `app/lib/core/database/app_database.dart`
- Create: `app/test/core/database/daos/activity_logs_dao_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ActivityLogs` テーブル (Task 2)
- Produces:
  - `ActivityLogsDao`:
    - `Future<int> insertLog(ActivityLogsCompanion log)`
    - `Stream<int> watchCurrentMonthPoints(int childId)`
    - `Stream<List<ActivityLog>> watchRecentByChild(int childId, {int limit = 10})`
    - `Future<void> softDelete(int logId)`
    - `Stream<List<ActivityLog>> watchAllByChild(int childId)`
  - `AppDatabase.activityLogsDao` ゲッター

- [ ] **Step 1: DAO テストを書く**

`app/test/core/database/daos/activity_logs_dao_test.dart` を作成:

```dart
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
    final points = await db.activityLogsDao
        .watchCurrentMonthPoints(childId)
        .first;
    expect(points, equals(0));
  });

  test('当月ポイントが正しく合計される', () async {
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'テスト', points: 30));
    await db.activityLogsDao.insertLog(ActivityLogsCompanion.insert(
        childId: childId, choreName: 'テスト2', points: 20));
    final points = await db.activityLogsDao
        .watchCurrentMonthPoints(childId)
        .first;
    expect(points, equals(50));
  });

  test('ソフトデリートしたログはポイント集計から除外される', () async {
    final logId = await db.activityLogsDao.insertLog(
      ActivityLogsCompanion.insert(
          childId: childId, choreName: 'テスト', points: 30),
    );
    await db.activityLogsDao.softDelete(logId);
    final points = await db.activityLogsDao
        .watchCurrentMonthPoints(childId)
        .first;
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
```

- [ ] **Step 2: テスト実行 → 失敗を確認**

```bash
cd app
flutter test test/core/database/daos/activity_logs_dao_test.dart
```

期待: FAIL — `activityLogsDao` が存在しないため

- [ ] **Step 3: ActivityLogsDao を作成**

`app/lib/core/database/daos/activity_logs_dao.dart` を作成:

```dart
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
              activityLogs.recordedAt
                  .isBiggerOrEqualValue(monthStart) &
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
```

- [ ] **Step 4: AppDatabase に DAO を登録**

`app/lib/core/database/app_database.dart` を修正 — 先頭の import と class 内に追加:

```dart
// 既存の import の後に追加:
import 'daos/activity_logs_dao.dart';

// AppDatabase クラス内に追加:
late final activityLogsDao = ActivityLogsDao(this);
```

- [ ] **Step 5: コード再生成**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: テスト実行 → 全パスを確認**

```bash
flutter test test/core/database/daos/activity_logs_dao_test.dart
```

期待: 4 tests passed

- [ ] **Step 7: コミット**

```bash
cd ..
git add app/lib/core/database/ app/test/core/database/
git commit -m "feat: add ActivityLogsDao with soft delete and stream-based points"
```

---

### Task 5: Riverpod プロバイダー

**Files:**
- Create: `app/lib/core/providers.dart`
- Create: `app/test/core/providers_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ActivityLogsDao`, `seedDatabase` (Tasks 2-4)
- Produces:
  - `databaseProvider` → `AppDatabase`
  - `childrenProvider` → `AsyncValue<List<Child>>`
  - `categoriesProvider` → `AsyncValue<List<Category>>`
  - `choreTemplatesByCategoryProvider(int categoryId)` → `AsyncValue<List<ChoreTemplate>>`
  - `currentMonthPointsProvider(int childId)` → `AsyncValue<int>`
  - `recentActivitiesProvider(int childId)` → `AsyncValue<List<ActivityLog>>`

- [ ] **Step 1: プロバイダーテストを書く**

`app/test/core/providers_test.dart` を作成:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ouchi_master/core/database/app_database.dart';
import 'package:ouchi_master/core/database/seed_data.dart';
import 'package:ouchi_master/core/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDatabase(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('categoriesProvider が5カテゴリを返す', () async {
    final cats = await container.read(categoriesProvider.future);
    expect(cats.length, equals(5));
  });

  test('currentMonthPointsProvider が初期状態で0を返す', () async {
    final childId = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'はる', color: '#FF6B6B'),
    );
    final points =
        await container.read(currentMonthPointsProvider(childId).future);
    expect(points, equals(0));
  });
}
```

- [ ] **Step 2: テスト実行 → 失敗を確認**

```bash
cd app
flutter test test/core/providers_test.dart
```

期待: FAIL

- [ ] **Step 3: providers.dart を作成**

`app/lib/core/providers.dart` を作成:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'database/seed_data.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  seedDatabase(db);
  ref.onDispose(db.close);
  return db;
});

final childrenProvider = StreamProvider<List<Child>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.children).watch();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .watch();
});

final choreTemplatesByCategoryProvider =
    StreamProvider.family<List<ChoreTemplate>, int>((ref, categoryId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.choreTemplates)
        ..where((t) =>
            t.categoryId.equals(categoryId) & t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

final currentMonthPointsProvider =
    StreamProvider.family<int, int>((ref, childId) {
  final db = ref.watch(databaseProvider);
  return db.activityLogsDao.watchCurrentMonthPoints(childId);
});

final recentActivitiesProvider =
    StreamProvider.family<List<ActivityLog>, int>((ref, childId) {
  final db = ref.watch(databaseProvider);
  return db.activityLogsDao.watchRecentByChild(childId);
});
```

- [ ] **Step 4: テスト実行 → 全パスを確認**

```bash
flutter test test/core/providers_test.dart
```

期待: 2 tests passed

- [ ] **Step 5: コミット**

```bash
cd ..
git add app/lib/core/providers.dart app/test/core/providers_test.dart
git commit -m "feat: add Riverpod providers for database streams"
```

---

### Task 6: アプリシェル・ルーティング・初期セットアップ画面

**Files:**
- Modify: `app/lib/main.dart`
- Create: `app/lib/app.dart`
- Create: `app/lib/features/setup/setup_screen.dart`
- Create: `app/lib/features/dashboard/dashboard_screen.dart` (スタブ)
- Create: `app/lib/features/chore_entry/chore_entry_screen.dart` (スタブ)

**Interfaces:**
- Consumes: `databaseProvider`, `childrenProvider` (Task 5)
- Produces: 子どもが0人ならセットアップ画面、いればダッシュボードを表示するアプリ

- [ ] **Step 1: main.dart を置き換え**

`app/lib/main.dart` を以下で置き換え:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: OuchiMasterApp()));
}
```

- [ ] **Step 2: app.dart を作成**

`app/lib/app.dart` を作成:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/setup/setup_screen.dart';

class OuchiMasterApp extends ConsumerWidget {
  const OuchiMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ouchi-master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF6B9FFF)),
        useMaterial3: true,
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    return childrenAsync.when(
      data: (children) =>
          children.isEmpty ? const SetupScreen() : const DashboardScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('エラー: $e'))),
    );
  }
}
```

- [ ] **Step 3: セットアップ画面を作成**

`app/lib/features/setup/setup_screen.dart` を作成:

```dart
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏠 ouchi-master',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const Text('はじめに家族を登録します',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16)),
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.into(db.children).insert(
                  ChildrenCompanion.insert(
                      name: 'はる', color: '#FF6B6B'),
                );
                await db.into(db.children).insert(
                  ChildrenCompanion.insert(
                      name: 'あきら', color: '#4ECDC4'),
                );
              },
              child: const Text('はると あきらを 登録する',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: ダッシュボードとできたよモードのスタブを作成**

`app/lib/features/dashboard/dashboard_screen.dart` を作成:

```dart
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('ダッシュボード（準備中）')),
    );
  }
}
```

`app/lib/features/chore_entry/chore_entry_screen.dart` を作成:

```dart
import 'package:flutter/material.dart';

class ChoreEntryScreen extends StatelessWidget {
  const ChoreEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('できたよモード')),
      body: const Center(child: Text('（準備中）')),
    );
  }
}
```

- [ ] **Step 5: アプリ起動・セットアップフローを確認**

```bash
cd app
flutter run
```

期待: セットアップ画面が表示される → 「登録する」ボタンをタップ → 「ダッシュボード（準備中）」が表示される

- [ ] **Step 6: コミット**

```bash
cd ..
git add app/lib/
git commit -m "feat: add app shell with setup flow and stub screens"
```

---

### Task 7: ダッシュボード画面

**Files:**
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`
- Create: `app/lib/features/dashboard/widgets/child_point_panel.dart`
- Create: `app/lib/features/dashboard/widgets/activity_log_list.dart`

**Interfaces:**
- Consumes:
  - `childrenProvider` → `List<Child>`
  - `currentMonthPointsProvider(childId)` → `int`
  - `recentActivitiesProvider(childId)` → `List<ActivityLog>`
- Produces: 実データ表示のダッシュボード。3秒長押しで `ChoreEntryScreen` へ遷移

- [ ] **Step 1: ActivityLogList ウィジェットを作成**

`app/lib/features/dashboard/widgets/activity_log_list.dart` を作成:

```dart
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

class ActivityLogList extends StatelessWidget {
  final List<ActivityLog> logs;
  const ActivityLogList({super.key, required this.logs});

  String _fmt(DateTime dt) => '${dt.month}/${dt.day} ${dt.hour}時';

  @override
  Widget build(BuildContext context) {
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(_fmt(log.recordedAt),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
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
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: ChildPointPanel ウィジェットを作成**

`app/lib/features/dashboard/widgets/child_point_panel.dart` を作成:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import 'activity_log_list.dart';

class ChildPointPanel extends ConsumerWidget {
  final Child child;
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
        color: _color.withOpacity(0.08),
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
            data: (p) => Text('★ $p P ★',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: _color)),
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
```

- [ ] **Step 3: ダッシュボード画面を実装**

`app/lib/features/dashboard/dashboard_screen.dart` を置き換え:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../chore_entry/chore_entry_screen.dart';
import 'widgets/child_point_panel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _pressing = false;

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _pressing = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (!_pressing || !mounted) return;
      setState(() => _pressing = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ChoreEntryScreen(),
        ),
      );
    });
  }

  void _cancelPress() => setState(() => _pressing = false);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      body: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: (_) => _cancelPress(),
        onLongPressCancel: _cancelPress,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(now),
                Expanded(
                  child: childrenAsync.when(
                    data: (children) => Row(
                      children: children
                          .map((c) =>
                              Expanded(child: ChildPointPanel(child: c)))
                          .toList(),
                    ),
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('エラー: $e')),
                  ),
                ),
              ],
            ),
            if (_pressing)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(
                      child: Text('そのまま持ちつづけて…',
                          style: TextStyle(
                              color: Colors.white, fontSize: 20)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime now) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('🏠 ouchi-master',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${now.year}年${now.month}月',
              style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: アプリ起動・ダッシュボードを確認**

```bash
cd app
flutter run
```

期待:
- はる・あきらのパネルが横に並んで表示される
- 両者 0P、「まだきろくがありません」
- 3秒長押し → 「できたよモード（準備中）」へ遷移

- [ ] **Step 5: コミット**

```bash
cd ..
git add app/lib/features/dashboard/
git commit -m "feat: add dashboard with child panels and long-press gesture"
```

---

### Task 8: できたよモード — 子ども選択・カテゴリ選択・お手伝いリスト・確定

**Files:**
- Modify: `app/lib/features/chore_entry/chore_entry_screen.dart`
- Create: `app/lib/features/chore_entry/chore_list_screen.dart`

**Interfaces:**
- Consumes:
  - `childrenProvider` → `List<Child>`
  - `categoriesProvider` → `List<Category>`
  - `choreTemplatesByCategoryProvider(categoryId)` → `List<ChoreTemplate>`
  - `databaseProvider` (ログ挿入に使用)
- Produces: 子ども選択 → カテゴリ → お手伝い選択 → 確認ダイアログ → ダッシュボードに戻る、の全フロー

- [ ] **Step 1: ChoreEntryScreen（子ども・カテゴリ選択）を実装**

`app/lib/features/chore_entry/chore_entry_screen.dart` を置き換え:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'chore_list_screen.dart';

class ChoreEntryScreen extends ConsumerStatefulWidget {
  const ChoreEntryScreen({super.key});

  @override
  ConsumerState<ChoreEntryScreen> createState() =>
      _ChoreEntryScreenState();
}

class _ChoreEntryScreenState extends ConsumerState<ChoreEntryScreen> {
  Child? _selectedChild;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('できたよモード'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('だれが？',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            childrenAsync.when(
              data: (children) => Wrap(
                spacing: 12,
                children: children.map((c) {
                  final selected = _selectedChild?.id == c.id;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          selected ? Colors.blue : null,
                      foregroundColor:
                          selected ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 16),
                    ),
                    onPressed: () =>
                        setState(() => _selectedChild = c),
                    child: Text(c.name,
                        style: const TextStyle(fontSize: 22)),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('エラー'),
            ),
            if (_selectedChild != null) ...[
              const SizedBox(height: 32),
              const Text('なにした？',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: categories.map((cat) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChoreListScreen(
                            child: _selectedChild!,
                            category: cat,
                          ),
                        ),
                      ),
                      child: Text('${cat.emoji} ${cat.name}',
                          style: const TextStyle(fontSize: 20)),
                    );
                  }).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('エラー'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ChoreListScreen（お手伝い一覧・確認）を作成**

`app/lib/features/chore_entry/chore_list_screen.dart` を作成:

```dart
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class ChoreListScreen extends ConsumerWidget {
  final Child child;
  final Category category;
  const ChoreListScreen(
      {super.key, required this.child, required this.category});

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, ChoreTemplate t) async {
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
    if (confirmed == true && context.mounted) {
      final db = ref.read(databaseProvider);
      await db.activityLogsDao.insertLog(
        ActivityLogsCompanion.insert(
          childId: child.id,
          choreName: t.name,
          points: t.points,
        ),
      );
      // ルートまで戻る（ダッシュボードへ）
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync =
        ref.watch(choreTemplatesByCategoryProvider(category.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.emoji} ${category.name} — ${child.name}'),
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
```

- [ ] **Step 3: 全フローを実機で確認**

```bash
cd app
flutter run
```

期待:
1. 長押し3秒 → できたよモード
2. 子どもを選ぶ → カテゴリが出る
3. カテゴリタップ → お手伝いリスト
4. 項目タップ → 確認ダイアログ
5. 「できた！」 → ダッシュボードに戻る
6. ポイントが即座に更新されている

- [ ] **Step 4: コミット**

```bash
cd ..
git add app/lib/features/chore_entry/
git commit -m "feat: complete chore entry flow with point recording"
```

---

### Task 9: アニメーション演出（カウントアップ・紙吹雪・トースト）

**Files:**
- Create: `app/lib/shared/widgets/animated_point_counter.dart`
- Create: `app/lib/shared/widgets/point_toast.dart`
- Modify: `app/lib/features/dashboard/widgets/child_point_panel.dart`

**Interfaces:**
- Consumes:
  - `currentMonthPointsProvider(childId)` — ストリームが更新されたときにアニメーションを起動
  - `confetti` パッケージ
- Produces:
  - `AnimatedPointCounter({required int points, TextStyle? style})` — ぬるっとカウントアップするウィジェット
  - `showPointToast(BuildContext, {childName, choreName, points})` — 画面上部に3秒表示されるトースト
  - `ChildPointPanel` に紙吹雪エフェクト追加済み

- [ ] **Step 1: AnimatedPointCounter を作成**

`app/lib/shared/widgets/animated_point_counter.dart` を作成:

```dart
import 'package:flutter/material.dart';

class AnimatedPointCounter extends StatefulWidget {
  final int points;
  final TextStyle? style;
  const AnimatedPointCounter(
      {super.key, required this.points, this.style});

  @override
  State<AnimatedPointCounter> createState() =>
      _AnimatedPointCounterState();
}

class _AnimatedPointCounterState extends State<AnimatedPointCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.points;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(AnimatedPointCounter old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) {
      _from = old.points;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final cur =
            (_from + _anim.value * (widget.points - _from)).round();
        return Text('★ $cur P ★', style: widget.style);
      },
    );
  }
}
```

- [ ] **Step 2: PointToast を作成**

`app/lib/shared/widgets/point_toast.dart` を作成:

```dart
import 'package:flutter/material.dart';

void showPointToast(
  BuildContext context, {
  required String childName,
  required String choreName,
  required int points,
}) {
  final pos = points >= 0;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          color: pos ? const Color(0xFF43A047) : const Color(0xFFE53935),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Text(
              '$childName  ${pos ? '+' : ''}${points}P  $choreName${pos ? ' 🎉' : ''}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  Future.delayed(const Duration(seconds: 3), entry.remove);
}
```

- [ ] **Step 3: ChildPointPanel に紙吹雪とアニメーションを追加**

`app/lib/features/dashboard/widgets/child_point_panel.dart` を置き換え:

```dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/animated_point_counter.dart';
import 'activity_log_list.dart';

class ChildPointPanel extends ConsumerStatefulWidget {
  final Child child;
  const ChildPointPanel({super.key, required this.child});

  @override
  ConsumerState<ChildPointPanel> createState() =>
      _ChildPointPanelState();
}

class _ChildPointPanelState extends ConsumerState<ChildPointPanel> {
  late final ConfettiController _confetti;
  int? _prevPoints;

  Color get _color {
    final h = widget.child.color.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync =
        ref.watch(currentMonthPointsProvider(widget.child.id));
    final logsAsync =
        ref.watch(recentActivitiesProvider(widget.child.id));

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _color, width: 2),
          ),
          child: Column(
            children: [
              Text(widget.child.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              pointsAsync.when(
                data: (pts) {
                  if (_prevPoints != null &&
                      pts > _prevPoints! &&
                      mounted) {
                    _confetti.play();
                  }
                  _prevPoints = pts;
                  return AnimatedPointCounter(
                    points: pts,
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: _color),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('エラー'),
              ),
              const Text('今月の合計',
                  style:
                      TextStyle(color: Colors.grey, fontSize: 12)),
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
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirection: 3.14 / 2,
          emissionFrequency: 0.25,
          numberOfParticles: 18,
          gravity: 0.3,
          colors: const [
            Colors.pink, Colors.orange, Colors.yellow,
            Colors.green, Colors.blue, Colors.purple,
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: ChoreListScreen からトーストを呼ぶ**

`app/lib/features/chore_entry/chore_list_screen.dart` の `_confirm` メソッド内、`insertLog` の後に追記:

```dart
// 既存 import の後に追加:
import '../../shared/widgets/point_toast.dart';

// insertLog の直後（Navigator.popUntil の前）に追加:
if (context.mounted) {
  showPointToast(
    context,
    childName: child.name,
    choreName: t.name,
    points: t.points,
  );
}
```

- [ ] **Step 5: アニメーションを実機で確認**

```bash
cd app
flutter run
```

期待:
- ポイント記録後、該当パネルの数字が0.6秒かけてカウントアップ
- 紙吹雪が降る（加点時のみ）
- 画面上部にトーストが3秒表示される

- [ ] **Step 6: コミット**

```bash
cd ..
git add app/lib/
git commit -m "feat: add animated counter, confetti, and point toast"
```

---

### Task 10: きろくの削除（ソフトデリートUI）

**Files:**
- Modify: `app/lib/features/dashboard/widgets/activity_log_list.dart`

**Interfaces:**
- Consumes: `ActivityLogsDao.softDelete(int logId)`, `databaseProvider`
- Produces: ログ行を左スワイプで削除できる `ActivityLogList`（確認ダイアログ付き）

- [ ] **Step 1: ActivityLogList をスワイプ削除対応に更新**

`app/lib/features/dashboard/widgets/activity_log_list.dart` を置き換え:

```dart
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
```

- [ ] **Step 2: 動作確認**

```bash
cd app
flutter run
```

期待: ダッシュボードのきろく行を左スワイプ → 赤い削除ボタン表示 → 確認ダイアログ → 「取り消す」でポイントが即座に減る

- [ ] **Step 3: コミット**

```bash
cd ..
git add app/lib/features/dashboard/widgets/activity_log_list.dart
git commit -m "feat: add swipe-to-delete on activity log with soft delete"
```

---

### Task 11: 設定画面

**Files:**
- Create: `app/lib/features/settings/settings_screen.dart`
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`

**Interfaces:**
- Consumes: `categoriesProvider`, `choreTemplatesByCategoryProvider`, `databaseProvider`
- Produces: お手伝い項目のON/OFF切替ができる設定画面。ダッシュボードから歯車アイコンでアクセス。

- [ ] **Step 1: 設定画面を作成**

`app/lib/features/settings/settings_screen.dart` を作成:

```dart
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: categoriesAsync.when(
        data: (cats) => ListView(
          children: [
            const ListTile(
              title: Text('お手伝い項目',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...cats.map((cat) => _CategorySection(category: cat)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('エラー')),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final Category category;
  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // isActive に関わらず全テンプレートを表示するため直接DBを参照
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<ChoreTemplate>>(
      stream: (db.select(db.choreTemplates)
            ..where((t) => t.categoryId.equals(category.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch(),
      builder: (context, snap) {
        final templates = snap.data ?? [];
        return ExpansionTile(
          title: Text('${category.emoji} ${category.name}'),
          children: templates
              .map((t) => SwitchListTile(
                    title: Text(t.name),
                    subtitle: Text(
                        '${t.points > 0 ? '+' : ''}${t.points}P'),
                    value: t.isActive,
                    onChanged: (val) async {
                      await (db.update(db.choreTemplates)
                            ..where((r) => r.id.equals(t.id)))
                          .write(ChoreTemplatesCompanion(
                              isActive: Value(val)));
                    },
                  ))
              .toList(),
        );
      },
    );
  }
}
```

- [ ] **Step 2: ダッシュボードに歯車ボタンを追加**

`dashboard_screen.dart` の `_buildHeader` メソッドを更新:

```dart
// 先頭の import に追加:
import '../settings/settings_screen.dart';

// _buildHeader の Row の末尾に追加（Spacer の後):
IconButton(
  icon: const Icon(Icons.settings_outlined),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  ),
),
```

- [ ] **Step 3: 動作確認**

```bash
cd app
flutter run
```

期待: 歯車アイコン → 設定画面 → カテゴリを展開 → スイッチでON/OFF → できたよモードの項目一覧に即時反映

- [ ] **Step 4: コミット**

```bash
cd ..
git add app/lib/features/settings/ app/lib/features/dashboard/
git commit -m "feat: add settings screen with chore template toggles"
```

---

### Task 12: 月次履歴画面

**Files:**
- Create: `app/lib/features/history/history_screen.dart`
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`

**Interfaces:**
- Consumes: `databaseProvider`, `ActivityLogs` テーブル、`Children` テーブル
- Produces: 月別ポイントサマリー一覧。タップで詳細ログを展開する履歴画面。ダッシュボードから時計アイコンでアクセス。

- [ ] **Step 1: 履歴画面を作成**

`app/lib/features/history/history_screen.dart` を作成:

```dart
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

class _MonthSummary {
  final int year, month;
  final Map<int, int> pointsByChildId;
  final List<ActivityLog> logs;
  _MonthSummary(
      {required this.year,
      required this.month,
      required this.pointsByChildId,
      required this.logs});
}

final _historyProvider =
    FutureProvider<List<_MonthSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await (db.select(db.activityLogs)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([(l) => OrderingTerm.desc(l.recordedAt)]))
      .get();

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
    ..sort((a, b) => b.year != a.year
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
            return const Center(child: Text('まだきろくがありません'));
          }
          return childrenAsync.when(
            data: (children) {
              final childMap = {for (final c in children) c.id: c};
              return ListView.builder(
                itemCount: summaries.length,
                itemBuilder: (_, i) {
                  final s = summaries[i];
                  final subtitle = s.pointsByChildId.entries
                      .map((e) =>
                          '${childMap[e.key]?.name ?? '?'}: ${e.value}P')
                      .join('  ');
                  return ExpansionTile(
                    title: Text('${s.year}年${s.month}月',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    subtitle: Text(subtitle),
                    children: s.logs.map((log) {
                      final neg = log.points < 0;
                      return ListTile(
                        dense: true,
                        leading: Text(
                          '${log.recordedAt.month}/${log.recordedAt.day} ${log.recordedAt.hour}時',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        title: Text(log.choreName),
                        trailing: Text(
                          '${neg ? '' : '+'}${log.points}P  ${childMap[log.childId]?.name ?? '?'}',
                          style: TextStyle(
                              color: neg
                                  ? Colors.red
                                  : Colors.green),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('エラー')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: ダッシュボードに履歴ボタンを追加**

`dashboard_screen.dart` の `_buildHeader` の歯車アイコンの前に追加:

```dart
// 先頭の import に追加:
import '../history/history_screen.dart';

// 歯車アイコンの前に追加:
IconButton(
  icon: const Icon(Icons.history),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HistoryScreen()),
  ),
),
```

- [ ] **Step 3: 動作確認**

```bash
cd app
flutter run
```

期待: 時計アイコン → 履歴画面 → 月別サマリー表示 → タップで詳細ログ展開（タイムスタンプ・きろく名・P数・誰の）

- [ ] **Step 4: コミット**

```bash
cd ..
git add app/lib/features/history/ app/lib/features/dashboard/
git commit -m "feat: add monthly history screen"
```

---

## スペックカバレッジ確認

| 設計書要件 | 対応タスク |
|-----------|----------|
| 子ども2名（はる・あきら） | Task 6 セットアップ画面 |
| ダッシュボード常時表示 | Task 7 |
| 長押し3秒でできたよモード | Task 7 |
| カテゴリ絞り込み → お手伝い選択 | Task 8 |
| ポイント加算・減点記録 | Task 8 |
| リアルタイム反映（ストリーム） | Task 4, 5 |
| カウントアップアニメーション | Task 9 |
| 紙吹雪エフェクト（加点時のみ） | Task 9 |
| トースト通知 | Task 9 |
| 直近のきろくタイムライン | Task 7 |
| タイムスタンプ `M/D H時` 形式 | Task 7 |
| 誤入力の取り消し（ソフトデリート） | Task 10 |
| お手伝いマスターのデフォルト19項目 | Task 3 |
| お手伝い項目のON/OFF管理 | Task 11 |
| 月次リセット（UI概念、データ保持） | Task 4, 5 |
| 月次履歴・過去の振り返り | Task 12 |
| Drift SQLite ローカル保存 | Task 2 |
| Riverpod 状態管理 | Task 5 |
| Flutter iPad 横向き | Task 6 |
