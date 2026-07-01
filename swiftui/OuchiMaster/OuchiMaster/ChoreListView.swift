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
        log.id         = UUID()
        log.choreName  = template.name
        log.points     = template.points
        log.recordedAt = Date()
        log.child      = child
        try? ctx.save()

        confirmTemplate = nil
        onDone()

        NotificationCenter.default.post(
            name: .showPointToast,
            object: nil,
            userInfo: [
                "childName": child.name    ?? "",
                "choreName": template.name ?? "",
                "points":    template.points,
            ]
        )
    }
}
