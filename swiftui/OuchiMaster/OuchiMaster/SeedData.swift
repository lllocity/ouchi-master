import CoreData

func seedIfNeeded(context: NSManagedObjectContext) {
    let req = Category.fetchRequest()
    guard (try? context.count(for: req)) == 0 else { return }

    let categoryData: [(name: String, emoji: String, order: Int32)] = [
        ("ごはん",   "🍚", 0),
        ("せんたく", "👕", 1),
        ("そうじ",   "🧹", 2),
        ("その他",   "📦", 3),
        ("げんてん", "👎", 4),
    ]

    var categories: [String: Category] = [:]
    for data in categoryData {
        let cat = Category(context: context)
        cat.id = UUID()
        cat.name = data.name
        cat.emoji = data.emoji
        cat.sortOrder = data.order
        categories[data.name] = cat
    }

    let templates: [(cat: String, name: String, pts: Int32, ord: Int32)] = [
        ("ごはん",   "ごはんをつくる",                            200, 0),
        ("ごはん",   "てつだう",                                   50, 1),
        ("ごはん",   "ごはんよそい",                               10, 2),
        ("ごはん",   "カトラリー準備（はし・スプーン・おちゃわん）",  10, 3),
        ("ごはん",   "テーブルふき",                               10, 4),
        ("ごはん",   "おさらあらい",                               30, 5),
        ("せんたく", "ほす",                                       20, 0),
        ("せんたく", "たたむ",                                     20, 1),
        ("そうじ",   "トイレそうじ",                               50, 0),
        ("そうじ",   "クイックルワイパー 1F",                      20, 1),
        ("そうじ",   "クイックルワイパー 2F",                      20, 2),
        ("そうじ",   "クイックルワイパー 3F",                      20, 3),
        ("そうじ",   "ゆかふき 1F",                                50, 4),
        ("そうじ",   "ゆかふき 2F",                                50, 5),
        ("そうじ",   "ゆかふき 3F",                                50, 6),
        ("そうじ",   "おふろそうじ",                              100, 7),
        ("その他",   "ゆうびん受け取り",                           10, 0),
        ("げんてん", "本だしっぱなし",                            -10, 0),
        ("げんてん", "おもちゃだしっぱなし",                      -10, 1),
    ]

    for t in templates {
        let tmpl = ChoreTemplate(context: context)
        tmpl.id = UUID()
        tmpl.name = t.name
        tmpl.points = t.pts
        tmpl.isActive = true
        tmpl.sortOrder = t.ord
        tmpl.category = categories[t.cat]
    }

    try? context.save()
}
