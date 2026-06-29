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
    expect(cats.first.name, equals('ごはん'));
  });

  test('currentMonthPointsProvider が初期状態で0を返す', () async {
    final childId = await db.into(db.children).insert(
      ChildrenCompanion.insert(name: 'はる', color: '#FF6B6B'),
    );

    final points =
        await container.read(currentMonthPointsProvider(childId).future);
    expect(points, equals(0));
  });

  test('choreTemplatesByCategoryProvider がごはんカテゴリの6項目を返す', () async {
    final cats = await container.read(categoriesProvider.future);
    final gohan = cats.firstWhere((c) => c.name == 'ごはん');
    final templates = await container
        .read(choreTemplatesByCategoryProvider(gohan.id).future);
    expect(templates.length, equals(6));
  });
}
