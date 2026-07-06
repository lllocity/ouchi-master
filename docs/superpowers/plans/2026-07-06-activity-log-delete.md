# きろく削除機能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 管理画面（SettingsView）に「今月のきろく」セクションを追加し、スワイプ→確認アラートでソフトデリートできるようにする。削除済みきろくはグレーアウト＋打ち消し線で表示する。

**Architecture:** `ActivityLogRowView` に `isDeleted` 引数を追加して削除済みスタイルを表現。`SettingsView.swift` に private struct `ActivityLogDeleteSection` を追加し、子ども別に今月のきろく（削除済み含む）を表示・削除できるようにする。

**Tech Stack:** Swift 5.9, SwiftUI, Core Data

## Global Constraints

- iOS 16.0 minimum — iOS 17+ APIs 使用禁止
- `onChange(of:)` は単一引数クロージャ形式のみ
- Core Data のソフトデリート：`ActivityLog.deletedAt = Date()` → `ctx.save()`
- DBスキーマ変更なし
- 既存の `ActivityLogRowView`, `formatLogDate` を再利用すること
- 日本語テキストは仕様書の表記を verbatim で使用すること

---

### 事前準備: feature ブランチ作成

- [ ] **Step 1: ブランチを作成する**

```bash
git -C /Users/lllocity/Projects/ouchi-master checkout -b feat/activity-log-delete
```

Expected: `Switched to a new branch 'feat/activity-log-delete'`

---

### Task 1: ActivityLogRowView に isDeleted スタイルを追加

**Files:**
- Modify: `swiftui/OuchiMaster/OuchiMaster/ActivityLogRowView.swift`

**Interfaces:**
- Produces: `ActivityLogRowView(log:categoryEmoji:childName:childColor:isDeleted:)` — `isDeleted: Bool = false` を新規引数として追加

- [ ] **Step 1: `ActivityLogRowView.swift` を編集する**

`var childColor: Color? = nil` の次の行に `var isDeleted: Bool = false` を追加し、`body` に削除済みスタイルを適用する。

完成後のファイル全体:

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
    var isDeleted: Bool = false

    var body: some View {
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
                    .strikethrough(isDeleted)
            }
            Spacer()
            let pts = log.points
            Text("\(pts >= 0 ? "+" : "")\(pts)P")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(pts < 0 ? Color.red : Color.green)
                .strikethrough(isDeleted)
            if let name = childName, let color = childColor {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 6)
        .opacity(isDeleted ? 0.4 : 1.0)
    }
}
```

- [ ] **Step 2: 既存の呼び出し元が壊れていないことを確認する**

`isDeleted` はデフォルト引数 `false` のため、`ChildPointPanelView` と `HistoryView` の既存呼び出しはそのまま動く。念のず確認:

```bash
grep -rn "ActivityLogRowView(" /Users/lllocity/Projects/ouchi-master/swiftui/OuchiMaster/OuchiMaster/
```

Expected: `ChildPointPanelView.swift`, `HistoryView.swift` に既存呼び出しが見える。引数に `isDeleted` がないことを確認（デフォルト値が使われる）。

- [ ] **Step 3: コミットする**

```bash
git -C /Users/lllocity/Projects/ouchi-master add swiftui/OuchiMaster/OuchiMaster/ActivityLogRowView.swift
git -C /Users/lllocity/Projects/ouchi-master commit -m "feat: add isDeleted styling to ActivityLogRowView"
```

---

### Task 2: SettingsView に今月のきろくセクションを追加

**Files:**
- Modify: `swiftui/OuchiMaster/OuchiMaster/SettingsView.swift`

**Interfaces:**
- Consumes: Task 1 の `ActivityLogRowView(log:categoryEmoji:isDeleted:)`, `formatLogDate(_:)` (ActivityLogRowView.swift に定義済み)
- Produces: `ActivityLogDeleteSection(child:)` — private struct

- [ ] **Step 1: `SettingsView.swift` に `ActivityLogDeleteSection` を追加する**

ファイル末尾（`ChildNameSheet` の定義の後）に以下を追加する:

```swift
// MARK: - 今月のきろく削除セクション
private struct ActivityLogDeleteSection: View {
    let child: Child

    @FetchRequest private var logs: FetchedResults<ActivityLog>
    @FetchRequest(sortDescriptors: []) private var templates: FetchedResults<ChoreTemplate>
    @Environment(\.managedObjectContext) private var ctx
    @State private var deletingLog: ActivityLog?

    init(child: Child) {
        self.child = child
        let cal = Calendar.current
        let now = Date()
        let monthStart    = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart)!

        _logs = FetchRequest(
            sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
            predicate: NSPredicate(
                format: "child == %@ AND recordedAt >= %@ AND recordedAt < %@",
                child, monthStart as CVarArg, nextMonthStart as CVarArg
            )
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
            Text("今月のきろくはありません")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(logs) { log in
                let isDeleted = log.deletedAt != nil
                ActivityLogRowView(
                    log: log,
                    categoryEmoji: categoryEmojiMap[log.choreName ?? ""],
                    isDeleted: isDeleted
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isDeleted {
                        Button(role: .destructive) {
                            deletingLog = log
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .alert(
                deletingLog.map { "「\($0.choreName ?? "")」を削除しますか？" } ?? "",
                isPresented: Binding(
                    get: { deletingLog != nil },
                    set: { if !$0 { deletingLog = nil } }
                ),
                presenting: deletingLog
            ) { log in
                Button("キャンセル", role: .cancel) { deletingLog = nil }
                Button("削除する", role: .destructive) {
                    log.deletedAt = Date()
                    try? ctx.save()
                    deletingLog = nil
                }
            } message: { log in
                Text("\(child.name ?? "") の \(log.recordedAt.map { formatLogDate($0) } ?? "") のきろくを削除します。")
            }
        }
    }
}
```

- [ ] **Step 2: `SettingsView` の `List` に「今月のきろく」セクションを追加する**

`SettingsView.body` の `List` 内、`Section("お手伝い項目")` の後に以下を追加する:

```swift
ForEach(children) { child in
    Section {
        ActivityLogDeleteSection(child: child)
    } header: {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: child.color ?? "9B59B6"))
                .frame(width: 8, height: 8)
            Text("\(child.name ?? "") の今月のきろく")
        }
    }
}
```

- [ ] **Step 3: 動作を手動で確認する**

Xcode でビルドして設定画面を開く。確認事項:
1. 子ども別に「◯◯ の今月のきろく」セクションが表示される
2. 今月のきろくがある場合、カテゴリ絵文字・お手伝い名・日時・ポイントが表示される
3. 行を左スワイプ → 赤い「削除」ボタンが出る
4. 「削除」タップ → 確認アラートが表示される（タイトルにお手伝い名、メッセージに子ども名・日時）
5. 「削除する」タップ → 行がグレーアウト＋打ち消し線になる
6. 「削除する」後、ダッシュボードのポイント合計が減っていること
7. 削除済み行はスワイプしても「削除」ボタンが出ない

- [ ] **Step 4: コミットする**

```bash
git -C /Users/lllocity/Projects/ouchi-master add swiftui/OuchiMaster/OuchiMaster/SettingsView.swift
git -C /Users/lllocity/Projects/ouchi-master commit -m "feat: add current month log delete section to SettingsView"
```

---

### 事後作業: PR 作成

- [ ] **Step 1: ブランチをリモートに push する**

```bash
git -C /Users/lllocity/Projects/ouchi-master push -u origin feat/activity-log-delete
```

- [ ] **Step 2: PR を作成する**

```bash
gh pr create \
  --title "feat: 管理画面から今月のきろくを削除できる機能を追加" \
  --body "$(cat <<'EOF'
## Summary

- `ActivityLogRowView` に `isDeleted: Bool` 引数を追加（デフォルト `false`）し、削除済みスタイル（グレーアウト＋打ち消し線）を実装
- `SettingsView` に「◯◯ の今月のきろく」セクションを子ども別に追加
- スワイプ削除 → 確認アラート → ソフトデリート（`deletedAt = Date()`）
- 削除済みエントリはリストに残り視覚的に区別される

## Test plan

- [ ] 設定画面に子ども別の今月きろくセクションが表示される
- [ ] 行を左スワイプで「削除」ボタンが出る
- [ ] 確認アラートに正しいお手伝い名・子ども名・日時が表示される
- [ ] 「削除する」後、行がグレーアウト＋打ち消し線になる
- [ ] 削除後、ダッシュボードのポイント合計が正しく減る
- [ ] 削除済み行はスワイプ操作できない

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
