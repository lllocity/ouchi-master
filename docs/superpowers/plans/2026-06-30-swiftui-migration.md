# おうちマスター SwiftUI Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter アプリ（app/）を Swift + SwiftUI のネイティブ iOS アプリに移行する。

**Architecture:** Core Data が Drift/SQLite を置き換え、`@FetchRequest` が Riverpod StreamProvider に相当するリアクティブクエリを提供する。新プロジェクトは `swiftui/OuchiMaster/` に作成し、既存の `app/`（Flutter）はそのまま残す。

**Tech Stack:** Swift 5.9, SwiftUI, iOS 16+, Core Data, ConfettiSwiftUI (SPM via GitHub)

## Global Constraints

- Minimum iOS deployment target: **16.0**（Core Data 使用。SwiftData は iOS 17 以上のため不採用）
- Language: Swift 5.9+
- UI framework: SwiftUI のみ（UIKit 不使用）
- `onChange(of:)` は iOS 16 互換の 1引数クロージャ形式 `{ newValue in }` を使う
- `withAnimation` は `.spring()` ショートハンドでなく `.spring(response:dampingFraction:)` を使う
- Flutter アプリの日本語テキストはすべて原文のまま保持する
- 新 Xcode プロジェクトの場所: `swiftui/OuchiMaster/`
- 既存 Flutter `app/` は一切変更しない
- データ移行は行わない（新規インストールとして扱う）

---

### Task 1: Xcode プロジェクト + Core Data スキーマ + シードデータ

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/OuchiMasterApp.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/Persistence.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/SeedData.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/Extensions/Color+Hex.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/OuchiMaster.xcdatamodeld` (Xcode GUI)

**Interfaces:**
- Produces: `PersistenceController.shared.container.viewContext`（全 View で使用）
- Produces: Core Data エンティティ `Child`, `Category`, `ChoreTemplate`, `ActivityLog`
- Produces: `seedIfNeeded(context:)` — アプリ起動時に1回だけ呼ぶ
- Produces: `Color(hex:)` イニシャライザ

- [ ] **Step 1: Xcode で新規プロジェクトを作成する**

Xcode → File → New → Project → iOS → App:
- Product Name: `OuchiMaster`
- Team: `V49MN6T826`
- Interface: SwiftUI
- Language: Swift
- **"Use Core Data" にチェック**（ボイラープレートが生成される。後で上書きする）
- "Include Tests" のチェックを外す
- 保存先: `/Users/lllocity/Projects/ouchi-master/swiftui/OuchiMaster/`

- [ ] **Step 2: Core Data モデルをXcodeのGUIで定義する**

`OuchiMaster.xcdatamodeld` を開き、以下の4エンティティを追加する（Editor → Add Entity）。
全属性の「Optional」チェックは外す（`deletedAt` だけ例外として Optional のまま残す）。
全エンティティの Codegen: **Class Definition**。

**Child エンティティ:**
| Attribute | Type |
|-----------|------|
| id | UUID |
| name | String |
| color | String |
| createdAt | Date |

**Category エンティティ:**
| Attribute | Type |
|-----------|------|
| id | UUID |
| name | String |
| emoji | String |
| sortOrder | Integer 32 |

**ChoreTemplate エンティティ:**
| Attribute | Type |
|-----------|------|
| id | UUID |
| name | String |
| points | Integer 32 |
| isActive | Boolean |
| sortOrder | Integer 32 |

Relationship: `category` → to-one Category（Delete Rule: Nullify）。Category 側の inverse: `templates`（to-many）。

**ActivityLog エンティティ:**
| Attribute | Type | Optional? |
|-----------|------|-----------|
| id | UUID | No |
| choreName | String | No |
| points | Integer 32 | No |
| recordedAt | Date | No |
| deletedAt | Date | **Yes** |

Relationship: `child` → to-one Child（Delete Rule: Nullify）。Child 側の inverse: `logs`（to-many）。

- [ ] **Step 3: ConfettiSwiftUI を SPM で追加する**

Xcode → File → Add Package Dependencies...
URL: `https://github.com/simibac/ConfettiSwiftUI`
Version: Up to Next Major from 1.0.0

- [ ] **Step 4: OuchiMasterApp.swift を書き換える**

```swift
import SwiftUI

@main
struct OuchiMasterApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

struct ContentRootView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var seeded = false

    var body: some View {
        DashboardView()
            .task {
                guard !seeded else { return }
                seedIfNeeded(context: ctx)
                seeded = true
            }
    }
}
```

- [ ] **Step 5: Persistence.swift を書く**

```swift
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "OuchiMaster")
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data failed to load: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
```

- [ ] **Step 6: SeedData.swift を書く**

```swift
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
```

- [ ] **Step 7: Extensions/Color+Hex.swift を書く**

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt64(h, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8)  & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 8: ビルドして起動確認**

Xcode で Cmd+R（シミュレータで実行）。期待: 白い画面でクラッシュなし。コンソールにエラーなし。

```
git add swiftui/
git commit -m "chore: scaffold SwiftUI project with Core Data schema and seed data"
```

---

### Task 2: ダッシュボード画面

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/Dashboard/DashboardView.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/Dashboard/ChildPointPanelView.swift`

**Interfaces:**
- Consumes: Task 1 の `PersistenceController`, `Color(hex:)`, `Child`, `ActivityLog`
- Produces: `DashboardView`（`ContentRootView` から使用）
- Produces: `ChildPointPanelView(child:)`（`DashboardView` から使用）
- Produces: `Notification.Name.showPointToast`（Task 3 の ChoreListView が post する）

- [ ] **Step 1: DashboardView.swift を書く**

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt)],
        animation: .default
    ) private var children: FetchedResults<Child>

    @State private var isPressing = false
    @State private var showChoreEntry = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var toastChildName = ""
    @State private var toastChoreName = ""
    @State private var toastPoints: Int32 = 0
    @State private var showToast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    headerView
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(children) { child in
                            ChildPointPanelView(child: child)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }

                if isPressing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            Text("そのまま持ちつづけて…")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }

                if showToast {
                    VStack {
                        PointToastView(
                            childName: toastChildName,
                            choreName: toastChoreName,
                            points: toastPoints
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 80)
                    .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .onLongPressGesture(minimumDuration: 3, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.2)) { isPressing = pressing }
            }) {
                isPressing = false
                showChoreEntry = true
            }
            .fullScreenCover(isPresented: $showChoreEntry) {
                ChoreEntryView()
            }
            .navigationDestination(isPresented: $showHistory) { HistoryView() }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .onReceive(NotificationCenter.default.publisher(for: .showPointToast)) { note in
                toastChildName = note.userInfo?["childName"] as? String ?? ""
                toastChoreName = note.userInfo?["choreName"] as? String ?? ""
                toastPoints    = note.userInfo?["points"]    as? Int32 ?? 0
                withAnimation(.easeIn(duration: 0.3)) { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) { showToast = false }
                }
            }
        }
    }

    var headerView: some View {
        let month = Calendar.current.component(.month, from: Date())
        return HStack(alignment: .center) {
            Text("🏠 おうちマスター")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(month)月")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color(hex: "FF6B6B"), Color(hex: "FFB347")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
        )
        .shadow(color: Color(hex: "FF6B6B").opacity(0.3), radius: 12, y: 4)
        // Safe area top padding を手動で追加（ignoresSafeArea + カスタムヘッダーのため）
        .padding(.top, UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 44
        )
    }
}

// MARK: - Toast view
struct PointToastView: View {
    let childName: String
    let choreName: String
    let points: Int32

    var body: some View {
        VStack(spacing: 4) {
            Text(childName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(choreName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text("\(points >= 0 ? "+" : "")\(points)P")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(points < 0 ? Color.red.opacity(0.9) : Color.yellow)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }
}

// MARK: - Notification name
extension Notification.Name {
    static let showPointToast = Notification.Name("showPointToast")
}
```

- [ ] **Step 2: ChildPointPanelView.swift を書く**

```swift
import SwiftUI
import ConfettiSwiftUI

struct ChildPointPanelView: View {
    let child: Child

    @FetchRequest private var currentMonthLogs: FetchedResults<ActivityLog>
    @FetchRequest private var lastMonthLogs:    FetchedResults<ActivityLog>
    @State private var confettiCounter = 0
    @State private var prevPoints: Int? = nil

    init(child: Child) {
        self.child = child
        let cal = Calendar.current
        let now = Date()
        let monthStart  = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let lastStart   = cal.date(byAdding: .month, value: -1, to: monthStart)!

        _currentMonthLogs = FetchRequest(
            sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
            predicate: NSPredicate(
                format: "child == %@ AND deletedAt == nil AND recordedAt >= %@",
                child, monthStart as CVarArg
            )
        )
        _lastMonthLogs = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(
                format: "child == %@ AND deletedAt == nil AND recordedAt >= %@ AND recordedAt < %@",
                child, lastStart as CVarArg, monthStart as CVarArg
            )
        )
    }

    var childColor: Color { Color(hex: child.color ?? "9B59B6") }
    var currentPoints: Int { currentMonthLogs.reduce(0) { $0 + Int($1.points) } }
    var lastMonthPoints: Int { lastMonthLogs.reduce(0) { $0 + Int($1.points) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(child.name ?? "")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                Text("\(currentPoints)")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(childColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPoints)
                    .confettiCannon(counter: $confettiCounter, colors: [
                        .pink, .orange, .yellow, .green, .blue, .purple
                    ])

                Text("今月のごうけい")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                if lastMonthPoints > 0 {
                    Text("先月は \(lastMonthPoints)P だったよ！おつかれさま 🎉")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(childColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }

                Divider().padding(.vertical, 12)

                Text("📋 今月のきろく")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.bottom, 4)

                ForEach(currentMonthLogs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.choreName ?? "")
                                .font(.system(size: 14))
                            Text(log.recordedAt.map { formatDate($0) } ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        let pts = log.points
                        Text("\(pts >= 0 ? "+" : "")\(pts)P")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(pts < 0 ? Color.red : Color.green)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            .padding(16)
        }
        .background(childColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(childColor, lineWidth: 2)
        )
        .padding(8)
        .onAppear { prevPoints = currentPoints }
        .onChange(of: currentPoints) { newValue in
            if let prev = prevPoints, newValue > prev {
                confettiCounter += 1
            }
            prevPoints = newValue
        }
    }

    func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        let m = cal.component(.month,  from: date)
        let d = cal.component(.day,    from: date)
        let h = cal.component(.hour,   from: date)
        return "\(m)/\(d) \(h)時"
    }
}
```

- [ ] **Step 3: ビルドして確認**

Cmd+R。期待:
- グラデーションヘッダーに「🏠 おうちマスター」と月が表示される
- 子どもがいないので空のパネルエリアが表示される
- 画面を3秒長押し → 「そのまま持ちつづけて…」オーバーレイが表示される
- 長押し完了 → ChoreEntryView が開く（Task 3 実装前なのでクラッシュする場合は Task 3 のダミー View を先に用意する）

```
git add swiftui/
git commit -m "feat: add Dashboard screen with gradient header and child point panels"
```

---

### Task 3: ChoreEntry フロー（お手伝い記録）

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/ChoreEntry/ChoreEntryView.swift`
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/ChoreEntry/ChoreListView.swift`

**Interfaces:**
- Consumes: `Child`, `Category`, `ChoreTemplate`, `ActivityLog` エンティティ
- Consumes: `Notification.Name.showPointToast`（DashboardView が受信）
- Produces: `ChoreEntryView`（DashboardView の `.fullScreenCover` で表示）
- Produces: `ChoreListDestination: Hashable`（NavigationPath の型パラメータ）

- [ ] **Step 1: ChoreEntryView.swift を書く**

```swift
import SwiftUI

private let categoryColors: [String: Color] = [
    "ごはん":   Color(hex: "FF8C69"),
    "せんたく": Color(hex: "64B5F6"),
    "そうじ":   Color(hex: "81C784"),
    "その他":   Color(hex: "BA68C8"),
    "げんてん": Color(hex: "EF9A9A"),
]

struct ChoreEntryView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt)]) private var children: FetchedResults<Child>
    @FetchRequest(sortDescriptors: [SortDescriptor(\.sortOrder)]) private var categories: FetchedResults<Category>

    @State private var selectedChild: Child?
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("だれが？")
                        .font(.system(size: 26, weight: .bold))
                        .padding(.bottom, 20)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                        ForEach(children) { child in
                            let color    = Color(hex: child.color ?? "9B59B6")
                            let selected = selectedChild?.objectID == child.objectID
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    selectedChild = child
                                }
                            } label: {
                                Text(child.name ?? "")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(selected ? .white : color)
                                    .frame(width: 160, height: 80)
                                    .background(selected ? color : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(color, lineWidth: 3)
                                    )
                                    .shadow(
                                        color: selected ? color.opacity(0.4) : .clear,
                                        radius: 12, y: 4
                                    )
                            }
                        }
                    }

                    if let child = selectedChild {
                        Text("なにした？")
                            .font(.system(size: 26, weight: .bold))
                            .padding(.top, 40)
                            .padding(.bottom, 20)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                            ForEach(categories) { category in
                                let color = categoryColors[category.name ?? ""] ?? Color(hex: "90CAF9")
                                Button {
                                    navPath.append(ChoreListDestination(child: child, category: category))
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(category.emoji ?? "")
                                            .font(.system(size: 32))
                                        Text(category.name ?? "")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 160, height: 100)
                                    .background(color)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }
            .navigationTitle("できたよモード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                    }
                }
            }
            .navigationDestination(for: ChoreListDestination.self) { dest in
                ChoreListView(
                    child: dest.child,
                    category: dest.category,
                    onDone: { dismiss() }
                )
            }
        }
    }
}

struct ChoreListDestination: Hashable {
    let child: Child
    let category: Category

    func hash(into hasher: inout Hasher) {
        hasher.combine(child.objectID)
        hasher.combine(category.objectID)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.child.objectID == rhs.child.objectID &&
        lhs.category.objectID == rhs.category.objectID
    }
}
```

- [ ] **Step 2: ChoreListView.swift を書く**

```swift
import SwiftUI

struct ChoreListView: View {
    let child: Child
    let category: Category
    let onDone: () -> Void

    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest private var templates: FetchedResults<ChoreTemplate>
    @State private var confirmTemplate: ChoreTemplate?

    init(child: Child, category: Category, onDone: @escaping () -> Void) {
        self.child    = child
        self.category = category
        self.onDone   = onDone
        _templates = FetchRequest(
            sortDescriptors: [SortDescriptor(\.sortOrder)],
            predicate: NSPredicate(
                format: "category == %@ AND isActive == YES", category
            )
        )
    }

    var body: some View {
        List(templates) { template in
            Button {
                confirmTemplate = template
            } label: {
                HStack {
                    Text(template.name ?? "")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                    Spacer()
                    let pts = template.points
                    Text("\(pts >= 0 ? "+" : "")\(pts)P")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(pts < 0 ? .red : .green)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
        }
        .navigationTitle(
            "\(category.emoji ?? "") \(category.name ?? "")  ／  \(child.name ?? "")"
        )
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            confirmTemplate.map {
                "\(child.name ?? "") が \($0.name ?? "")"
            } ?? "",
            isPresented: Binding(
                get: { confirmTemplate != nil },
                set: { if !$0 { confirmTemplate = nil } }
            ),
            presenting: confirmTemplate
        ) { template in
            Button("やめる", role: .cancel) { confirmTemplate = nil }
            Button("できた！") { record(template: template) }
        } message: { template in
            let pts = template.points
            Text("\(pts >= 0 ? "+" : "")\(pts)P")
                .font(.system(size: 40, weight: .bold))
        }
    }

    private func record(template: ChoreTemplate) {
        let log = ActivityLog(context: ctx)
        log.id = UUID()
        log.choreName   = template.name
        log.points      = template.points
        log.recordedAt  = Date()
        log.child       = child
        try? ctx.save()

        confirmTemplate = nil
        onDone()

        NotificationCenter.default.post(
            name: .showPointToast,
            object: nil,
            userInfo: [
                "childName": child.name  ?? "",
                "choreName": template.name ?? "",
                "points":    template.points,
            ]
        )
    }
}
```

- [ ] **Step 3: ビルドしてフロー全体を確認**

1. Settings から子どもを1人追加（Task 5 の前にここだけ先に動かしたい場合は、Core Data のデバッグで直接挿入するか Task 5 を先に実装する）
2. ダッシュボードを3秒長押し → ChoreEntry が開く
3. 子どもをタップ（選択色が変わる）
4. カテゴリが表示される → 「ごはん」をタップ
5. ChoreList（ごはんをつくる 200P など）が表示される
6. 項目をタップ → 確認アラートが出る
7. 「できた！」→ モーダルが閉じ、ダッシュボードにトーストが表示される
8. 子どもパネルのポイントが増え、紙吹雪が降る

```
git add swiftui/
git commit -m "feat: add ChoreEntry flow with confirmation dialog, log recording, and point toast"
```

---

### Task 4: 履歴画面

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/History/HistoryView.swift`

**Interfaces:**
- Consumes: `ActivityLog`, `Child` エンティティ
- Produces: `HistoryView`（DashboardView から push）

- [ ] **Step 1: HistoryView.swift を書く**

```swift
import SwiftUI

private struct MonthKey: Identifiable, Comparable {
    let year: Int
    let month: Int
    var id: String { "\(year)-\(month)" }
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }
}

struct HistoryView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
        predicate: NSPredicate(format: "deletedAt == nil")
    ) private var logs: FetchedResults<ActivityLog>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt)]
    ) private var children: FetchedResults<Child>

    var groupedByMonth: [(key: MonthKey, logs: [ActivityLog])] {
        let cal = Calendar.current
        var groups: [String: (key: MonthKey, logs: [ActivityLog])] = [:]
        for log in logs {
            guard let date = log.recordedAt else { continue }
            let y = cal.component(.year,  from: date)
            let m = cal.component(.month, from: date)
            let key = MonthKey(year: y, month: m)
            groups[key.id, default: (key: key, logs: [])].logs.append(log)
        }
        return groups.values.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if logs.isEmpty {
                Text("まだきろくがありません")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(groupedByMonth, id: \.key.id) { group in
                            MonthCard(
                                year: group.key.year,
                                month: group.key.month,
                                logs: group.logs,
                                children: Array(children)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("過去のきろく")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MonthCard: View {
    let year: Int
    let month: Int
    let logs: [ActivityLog]
    let children: [Child]
    @State private var expanded = false

    var childMap: [NSManagedObjectID: Child] {
        Dictionary(uniqueKeysWithValues: children.map { ($0.objectID, $0) })
    }

    var pointsByChild: [(child: Child?, points: Int)] {
        var byID: [NSManagedObjectID: Int] = [:]
        for log in logs {
            if let oid = log.child?.objectID {
                byID[oid, default: 0] += Int(log.points)
            }
        }
        return byID.map { (child: childMap[$0.key], points: $0.value) }
            .sorted { ($0.child?.name ?? "") < ($1.child?.name ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー（タップで開閉）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text("\(year)年\(month)月")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    ForEach(pointsByChild, id: \.child?.objectID) { entry in
                        let color = Color(hex: entry.child?.color ?? "888888")
                        Text("\(entry.child?.name ?? "?"): \(entry.points)P")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // 展開時のきろく一覧
            if expanded {
                Divider().padding(.horizontal, 16)
                ForEach(logs) { log in
                    let neg   = log.points < 0
                    let child = log.child.flatMap { childMap[$0.objectID] }
                    let color = Color(hex: child?.color ?? "888888")
                    HStack {
                        Text(log.recordedAt.map { formatDate($0) } ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(log.choreName ?? "")
                            .font(.system(size: 15))
                        Spacer()
                        Text("\(neg ? "" : "+")\(log.points)P")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(neg ? .red : .green)
                        Text(child?.name ?? "?")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Divider().padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day,   from: date)
        let h = cal.component(.hour,  from: date)
        return "\(m)/\(d) \(h)時"
    }
}
```

- [ ] **Step 2: ビルドして確認**

1. ダッシュボードのヘッダーから時計アイコンをタップ → 履歴画面に遷移
2. きろくなし: 「まだきろくがありません」が表示される
3. Task 3 でいくつかきろくを入れた後に再確認 → 月ごとのカードが表示され、タップで展開できる

```
git add swiftui/
git commit -m "feat: add History screen with monthly grouped log cards"
```

---

### Task 5: 設定画面

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/Views/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `Child`, `Category`, `ChoreTemplate` エンティティ
- Produces: `SettingsView`（DashboardView から push）

- [ ] **Step 1: SettingsView.swift を書く**

```swift
import SwiftUI

private let childColorPalette = ["#E74C3C", "#3498DB", "#2ECC71", "#9B59B6"]

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt)]) private var children: FetchedResults<Child>
    @FetchRequest(sortDescriptors: [SortDescriptor(\.sortOrder)]) private var categories: FetchedResults<Category>

    @State private var showAddChild = false
    @State private var editingChild: Child?
    @State private var deletingChild: Child?

    var body: some View {
        List {
            Section("子ども") {
                ForEach(children) { child in
                    HStack {
                        Circle()
                            .fill(Color(hex: child.color ?? "9B59B6"))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(child.name?.prefix(1) ?? "?"))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        Text(child.name ?? "")
                        Spacer()
                        Button { editingChild = child } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        Button { deletingChild = child } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if children.count < 4 {
                    Button {
                        showAddChild = true
                    } label: {
                        Label("子どもを追加", systemImage: "plus")
                    }
                } else {
                    Text("上限は4人までです")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("お手伝い項目") {
                ForEach(categories) { category in
                    CategoryToggleSection(category: category)
                }
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showAddChild) {
            ChildNameSheet(title: "子どもを追加") { name in
                let child = Child(context: ctx)
                child.id        = UUID()
                child.name      = name
                child.color     = childColorPalette[children.count % childColorPalette.count]
                child.createdAt = Date()
                try? ctx.save()
            }
        }
        .sheet(item: $editingChild) { child in
            ChildNameSheet(title: "名前を変更", initialName: child.name ?? "") { name in
                child.name = name
                try? ctx.save()
            }
        }
        .alert(
            "削除しますか？",
            isPresented: Binding(
                get: { deletingChild != nil },
                set: { if !$0 { deletingChild = nil } }
            ),
            presenting: deletingChild
        ) { child in
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                // ソフトデリート: きろくを論理削除してから子どもを削除
                let req = ActivityLog.fetchRequest()
                req.predicate = NSPredicate(format: "child == %@", child)
                if let logs = try? ctx.fetch(req) {
                    logs.forEach { $0.deletedAt = Date() }
                }
                ctx.delete(child)
                try? ctx.save()
                deletingChild = nil
            }
        } message: { child in
            Text("\(child.name ?? "") のきろくもすべて削除されます。")
        }
    }
}

// MARK: - カテゴリごとのトグルセクション
private struct CategoryToggleSection: View {
    let category: Category
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest private var templates: FetchedResults<ChoreTemplate>

    init(category: Category) {
        self.category = category
        _templates = FetchRequest(
            sortDescriptors: [SortDescriptor(\.sortOrder)],
            predicate: NSPredicate(format: "category == %@", category)
        )
    }

    var body: some View {
        DisclosureGroup("\(category.emoji ?? "") \(category.name ?? "")") {
            ForEach(templates) { template in
                Toggle(isOn: Binding(
                    get: { template.isActive },
                    set: { val in
                        template.isActive = val
                        try? ctx.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name ?? "")
                        let pts = template.points
                        Text("\(pts >= 0 ? "+" : "")\(pts)P")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 子ども名入力シート（追加・編集共用）
private struct ChildNameSheet: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(title: String, initialName: String = "", onSave: @escaping (String) -> Void) {
        self.title       = title
        self.initialName = initialName
        self.onSave      = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名前を入力", text: $name)
                    .autocorrectionDisabled()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 2: アプリ全体の動作を確認する**

1. ダッシュボードの歯車アイコン → 設定画面
2. 「子どもを追加」→ 名前を入力して保存 → ダッシュボードに子どもパネルが追加される
3. 2人目を追加 → パネルが横に並ぶ
4. 名前の編集・削除が動作する
5. お手伝い項目のトグルをオフ → ChoreEntry フローでその項目が消える
6. ダッシュボードに戻って長押し → ChoreEntry → 子どもを選択 → カテゴリ → お手伝い → 確認 → トースト + 紙吹雪
7. 履歴画面でそのきろくが表示される

- [ ] **Step 3: 最終コミット**

```
git add swiftui/
git commit -m "feat: add Settings screen with children CRUD and chore template toggles"
```
