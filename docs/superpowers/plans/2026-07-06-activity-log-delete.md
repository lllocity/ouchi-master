# ActivityLog 個別削除機能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 管理画面（SettingsView）から個別のお手伝いきろくをソフトデリート（論理削除）できるようにする。誤登録のロールバックが目的。

**Architecture:** `ActivityLog.deletedAt`（DBスキーマに既存）を論理削除フラグとして使用。ダッシュボード・履歴画面のポイント計算・表示は既に `deletedAt == nil` でフィルタ済みのため変更不要。管理画面では専用の `ActivityLogAdminView` を新規作成し、`SettingsView` の NavigationLink からプッシュする。管理画面上では削除済みきろくも表示し（グレーアウト＋打ち消し線）、左スワイプで削除・復元を操作できる。

**Tech Stack:** Swift 5.9, SwiftUI, Core Data, `@FetchRequest`, `swipeActions`

## Global Constraints

- DBスキーマ変更禁止（`.xcdatamodeld` ファイルは触らない）
- `ActivityLog.deletedAt` (Date?, 既存フィールド) を論理削除フラグとして使用（nil=有効、Date=削除済み）
- 削除操作は `SettingsView` → `ActivityLogAdminView` の遷移先でのみ提供
- `ChildPointPanelView.swift`・`HistoryView.swift`・`DashboardView.swift` は変更しない（既に `deletedAt == nil` フィルタ済み）
- iOS 16.0 minimum — iOS 17+ APIs 使用禁止
- `onChange(of:)` は単一引数クロージャ形式のみ

---

## 変更・作成ファイル一覧

| 操作 | ファイル | 内容 |
|---|---|---|
| Modify | `swiftui/OuchiMaster/OuchiMaster/ActivityLogRowView.swift` | `log.deletedAt` を見て削除済みスタイル（グレーアウト・打ち消し線）を自動適用 |
| Create | `swiftui/OuchiMaster/OuchiMaster/ActivityLogAdminView.swift` | 全きろく一覧（削除済み含む）・スワイプ削除/復元UI |
| Modify | `swiftui/OuchiMaster/OuchiMaster/SettingsView.swift` | `ActivityLogAdminView` への `NavigationLink` を追加 |

**変更しないファイル（既に対応済み）:**
- `ChildPointPanelView.swift` — `deletedAt == nil` でポイント計算フィルタ済み
- `HistoryView.swift` — `deletedAt == nil` で表示フィルタ済み

---

## 既存コードの再利用ポイント

- `ActivityLogRowView` — 削除済みスタイルを追加して継続使用
- `CategoryToggleSection` のパターン — `init(child:)` 内で `@FetchRequest` を初期化するパターンを踏襲
- `SettingsView` の `ctx.save()` パターン — `try? ctx.save()` をそのまま使用

---

### 事前準備: feature ブランチ作成

- [ ] **Step 1: ブランチを作成する**

```bash
git -C /Users/lllocity/Projects/ouchi-master checkout -b feat/activity-log-delete
```

Expected: `Switched to a new branch 'feat/activity-log-delete'`

---

### Task 1: ActivityLogRowView に削除済みスタイルを追加

**Files:**
- Modify: `swiftui/OuchiMaster/OuchiMaster/ActivityLogRowView.swift`

**Interfaces:**
- Produces: `ActivityLogRowView(log:categoryEmoji:childName:childColor:)` — シグネチャ変更なし。`log.deletedAt != nil` のとき自動的に削除済みスタイルを適用する

- [ ] **Step 1: `ActivityLogRowView.swift` の `body` を編集する**

`body` の `HStack` に `.opacity` モディファイアを追加し、`Text(log.choreName ?? "")` に `.strikethrough(log.deletedAt != nil)` を追加する。また、削除済みのとき「削除済み」バッジをポイント表示の代わりに表示する。

ファイル全体を以下に置き換える:

```swift
import SwiftUI
import CoreData

func formatLogDate(_ date: Date) -> String {
    let cal = Calendar.current
    let m = cal.component(.month, from: date)
    let d = cal.component(.day,   from: date)
    let h = cal.component(.hour,  from: date)
    return "\(m)/\(d) \(h)時"
}

struct ActivityLogRowView: View {
    let log: ActivityLog
    let categoryEmoji: String?
    var childName: String? = nil
    var childColor: Color? = nil

    var body: some View {
        let isDeleted = log.deletedAt != nil
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if let emoji = categoryEmoji {
                        Text(emoji).font(.system(size: 16))
                    }
                    Text(log.choreName ?? "")
                        .font(.system(size: 17))
                        .strikethrough(isDeleted)
                }
                Text(log.recordedAt.map { formatLogDate($0) } ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isDeleted {
                Text("削除済み")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.6))
                    .clipShape(Capsule())
            } else {
                let pts = log.points
                Text("\(pts >= 0 ? "+" : "")\(pts)P")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(pts < 0 ? Color.red : Color.green)
            }
            if let name = childName, let color = childColor {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 6)
        .opacity(isDeleted ? 0.45 : 1.0)
    }
}
```

- [ ] **Step 2: 既存呼び出し元が壊れていないことを確認する**

シグネチャ変更なし（引数追加なし）のため既存呼び出しはそのまま動く。念のず確認:

```bash
grep -rn "ActivityLogRowView(" /Users/lllocity/Projects/ouchi-master/swiftui/OuchiMaster/OuchiMaster/
```

Expected: `ChildPointPanelView.swift`・`HistoryView.swift` の呼び出し行が表示される。

- [ ] **Step 3: コミットする**

```bash
git -C /Users/lllocity/Projects/ouchi-master add swiftui/OuchiMaster/OuchiMaster/ActivityLogRowView.swift
git -C /Users/lllocity/Projects/ouchi-master commit -m "feat: show deleted state automatically in ActivityLogRowView"
```

---

### Task 2: ActivityLogAdminView を新規作成

**Files:**
- Create: `swiftui/OuchiMaster/OuchiMaster/ActivityLogAdminView.swift`

**Interfaces:**
- Consumes: Task 1 の `ActivityLogRowView`（削除済みスタイル対応済み）
- Produces: `ActivityLogAdminView` — `NavigationStack` 内から `navigationDestination` でプッシュ可能な View

- [ ] **Step 1: `ActivityLogAdminView.swift` を新規作成する**

```swift
import SwiftUI
import CoreData

struct ActivityLogAdminView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt)]) private var children: FetchedResults<Child>

    var body: some View {
        List {
            ForEach(children) { child in
                Section {
                    ChildLogAdminSection(child: child)
                } header: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: child.color ?? "9B59B6"))
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text(String(child.name?.prefix(1) ?? "?"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        Text(child.name ?? "")
                    }
                }
            }
        }
        .navigationTitle("きろくの管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 子どもごとのきろくセクション

private struct ChildLogAdminSection: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest private var logs: FetchedResults<ActivityLog>
    @FetchRequest(sortDescriptors: []) private var templates: FetchedResults<ChoreTemplate>

    init(child: Child) {
        _logs = FetchRequest(
            sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
            predicate: NSPredicate(format: "child == %@", child)
        )
    }

    private var categoryEmojiMap: [String: String] {
        Dictionary(
            templates.compactMap { t -> (String, String)? in
                guard let name = t.name, let emoji = t.category?.emoji else { return nil }
                return (name, emoji)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        if logs.isEmpty {
            Text("きろくがありません")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(logs) { log in
                ActivityLogRowView(
                    log: log,
                    categoryEmoji: categoryEmojiMap[log.choreName ?? ""]
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if log.deletedAt == nil {
                        Button(role: .destructive) {
                            log.deletedAt = Date()
                            try? ctx.save()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } else {
                        Button {
                            log.deletedAt = nil
                            try? ctx.save()
                        } label: {
                            Label("元に戻す", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: ビルドエラーがないことを確認する**

Xcode でビルドするか、以下を実行:

```bash
xcodebuild -project /Users/lllocity/Projects/ouchi-master/swiftui/OuchiMaster/OuchiMaster.xcodeproj \
  -scheme OuchiMaster build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミットする**

```bash
git -C /Users/lllocity/Projects/ouchi-master add swiftui/OuchiMaster/OuchiMaster/ActivityLogAdminView.swift
git -C /Users/lllocity/Projects/ouchi-master commit -m "feat: add ActivityLogAdminView for per-log soft delete and restore"
```

---

### Task 3: SettingsView に ActivityLogAdminView へのナビゲーションを追加

**Files:**
- Modify: `swiftui/OuchiMaster/OuchiMaster/SettingsView.swift`

**Interfaces:**
- Consumes: Task 2 の `ActivityLogAdminView`

- [ ] **Step 1: `SettingsView` の `List` に「きろくの管理」セクションを追加する**

`Section("お手伝い項目") { ... }` の閉じ `}` の直後に以下を追加する:

```swift
Section("きろくの管理") {
    NavigationLink("きろくを削除・復元する") {
        ActivityLogAdminView()
    }
}
```

- [ ] **Step 2: ビルドエラーがないことを確認する**

```bash
xcodebuild -project /Users/lllocity/Projects/ouchi-master/swiftui/OuchiMaster/OuchiMaster.xcodeproj \
  -scheme OuchiMaster build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミットする**

```bash
git -C /Users/lllocity/Projects/ouchi-master add swiftui/OuchiMaster/OuchiMaster/SettingsView.swift
git -C /Users/lllocity/Projects/ouchi-master commit -m "feat: add ActivityLogAdminView navigation link in SettingsView"
```

---

## 動作確認手順

1. シミュレータでアプリを起動
2. ダッシュボードの歯車アイコン → SettingsView を開く
3. 「きろくの管理」→「きろくを削除・復元する」をタップ
4. 子どもごとに全きろくが新しい順に表示されることを確認
5. 有効なきろく行を左スワイプ → 赤い「削除」ボタンが表示される
6. 「削除」をタップ → 行がグレーアウト＋打ち消し線＋「削除済み」バッジに変わる
7. 削除済み行を左スワイプ → 青い「元に戻す」ボタンが表示される
8. 「元に戻す」をタップ → 通常表示に戻る
9. ダッシュボードに戻り、削除したきろくのポイントが除外されていることを確認
10. 履歴画面を開き、削除したきろくが表示されないことを確認
