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
        let cal = Calendar.current
        let now = Date()
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
        _logs = FetchRequest(
            sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
            predicate: NSPredicate(
                format: "child == %@ AND recordedAt >= %@",
                child, lastMonthStart as CVarArg
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
                        Button {
                            log.deletedAt = Date()
                            try? ctx.save()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .tint(.red)
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
