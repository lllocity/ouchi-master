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
                    ChildRow(
                        child: child,
                        onEdit: { editingChild = child },
                        onDelete: { deletingChild = child }
                    )
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

// MARK: - 子ども行
private struct ChildRow: View {
    let child: Child
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
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
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
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
