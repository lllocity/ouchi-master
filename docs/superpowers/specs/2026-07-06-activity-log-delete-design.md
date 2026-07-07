# きろく削除機能 設計書

## 概要

管理画面（SettingsView）から今月の登録済みお手伝いきろくを削除できる機能を追加する。誤登録の回避が目的。削除はソフトデリート（`deletedAt` に日時をセット）で行い、削除済みエントリも視覚的に区別した上で一覧に残す。

## 背景・要件

- **対象:** 今月分のきろくのみ
- **操作者:** 親（管理者）が設定画面から操作する
- **削除方式:** 物理削除ではなくソフトデリート（既存の `ActivityLog.deletedAt` を利用）
- **削除の可視化:** 削除済みエントリもリストに残し、グレーアウト＋打ち消し線で表示。DBスキーマ変更なし
- **UX:** スワイプ（左）→「削除」ボタン → 確認アラート の2段階

## UI 設計

### SettingsView への追加

既存の `List` に第3セクション「今月のきろく」を追加する。

```
設定
├── 子ども
├── お手伝い項目
└── 今月のきろく
    ├── [子ども名（例: はる）]
    │   ├── 👕 たたむ  +20P  7/2 9時          ← 通常行（削除可）
    │   └── ~~🧹 クイックルワイパー~~  削除済み  ← 削除済み行（操作不可）
    └── [子ども名（例: あきら）]
        └── 🍚 ごはんをつくる  +200P  7/1 13時
```

### 削除フロー

1. 行を左スワイプ → 赤い「削除」ボタンが出現
2. タップ → 確認アラート表示
   - タイトル: `「{お手伝い名}」を削除しますか？`
   - メッセージ: `{子ども名} の {M/D H時} のきろくを削除します。`
   - ボタン: 「キャンセル」「削除する」（destructive）
3. 「削除する」タップ → `log.deletedAt = Date()` → `ctx.save()`

### 削除済み行の見た目

- テキスト全体に打ち消し線（`.strikethrough()`）
- 全体をグレーアウト（`.opacity(0.4)`）
- スワイプ操作は無効（`.swipeActions {}` を空にするか条件分岐）

## コンポーネント設計

### 新規: `ActivityLogDeleteSection`（SettingsView.swift 内 private struct）

`SettingsView` の `List` 内に置く Section コンポーネント。

- **@FetchRequest:** 今月の全きろく（deletedAt の有無問わず）を子ども別・日時降順で取得
- **子ども別グループ化:** children の FetchedResults をループし、各子どもの今月きろくを `NSPredicate` でフィルタリング

### `ActivityLogRowView` の拡張

既存の `ActivityLogRowView` に `isDeleted: Bool = false` 引数を追加する。

```swift
struct ActivityLogRowView: View {
    let log: ActivityLog
    let categoryEmoji: String?
    var childName: String? = nil
    var childColor: Color? = nil
    var isDeleted: Bool = false   // ← 追加
    ...
}
```

`isDeleted == true` のとき:
- `.strikethrough(true)` を適用
- `.opacity(0.4)` を適用

## データアクセス

### FetchRequest（今月の全きろく、削除済み含む）

```swift
FetchRequest(
    sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
    predicate: NSPredicate(
        format: "child == %@ AND recordedAt >= %@ AND recordedAt < %@",
        child, monthStart as CVarArg, nextMonthStart as CVarArg
    )
)
// deletedAt == nil の条件を外すことで削除済みも含む
```

### ソフトデリート

```swift
log.deletedAt = Date()
try? ctx.save()
```

## 影響範囲

- **変更:** `SettingsView.swift`（新セクション追加）、`ActivityLogRowView.swift`（`isDeleted` 引数追加）
- **変更なし:** `ChildPointPanelView`・`HistoryView`（既に `deletedAt == nil` でフィルタしているため自動で非表示になる）
- **DB変更:** なし

## 非対応（スコープ外）

- 過去月のきろくの削除
- ダッシュボードからの削除
- 削除の取り消し（Undo）
