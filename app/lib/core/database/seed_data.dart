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
    (cat: 'ごはん',   name: 'ごはんをつくる',                         pts: 200, ord: 0),
    (cat: 'ごはん',   name: 'てつだう',                               pts: 50,  ord: 1),
    (cat: 'ごはん',   name: 'ごはんよそい',                           pts: 10,  ord: 2),
    (cat: 'ごはん',   name: 'カトラリー準備（はし・スプーン・おちゃわん）', pts: 10,  ord: 3),
    (cat: 'ごはん',   name: 'テーブルふき',                           pts: 10,  ord: 4),
    (cat: 'ごはん',   name: 'おさらあらい',                           pts: 30,  ord: 5),
    (cat: 'せんたく', name: 'ほす',                                   pts: 20,  ord: 0),
    (cat: 'せんたく', name: 'たたむ',                                 pts: 20,  ord: 1),
    (cat: 'そうじ',   name: 'トイレそうじ',                           pts: 50,  ord: 0),
    (cat: 'そうじ',   name: 'クイックルワイパー 1F',                  pts: 20,  ord: 1),
    (cat: 'そうじ',   name: 'クイックルワイパー 2F',                  pts: 20,  ord: 2),
    (cat: 'そうじ',   name: 'クイックルワイパー 3F',                  pts: 20,  ord: 3),
    (cat: 'そうじ',   name: 'ゆかふき 1F',                           pts: 50,  ord: 4),
    (cat: 'そうじ',   name: 'ゆかふき 2F',                           pts: 50,  ord: 5),
    (cat: 'そうじ',   name: 'ゆかふき 3F',                           pts: 50,  ord: 6),
    (cat: 'そうじ',   name: 'おふろそうじ',                          pts: 100, ord: 7),
    (cat: 'その他',   name: 'ゆうびん受け取り',                      pts: 10,  ord: 0),
    (cat: 'げんてん', name: '本だしっぱなし',                        pts: -10, ord: 0),
    (cat: 'げんてん', name: 'おもちゃだしっぱなし',                  pts: -10, ord: 1),
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
