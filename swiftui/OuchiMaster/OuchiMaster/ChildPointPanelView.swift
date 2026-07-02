import SwiftUI
import CoreData
import ConfettiSwiftUI

struct ChildPointPanelView: View {
    let child: Child

    @FetchRequest private var currentMonthLogs: FetchedResults<ActivityLog>
    @FetchRequest private var lastMonthLogs:    FetchedResults<ActivityLog>
    @FetchRequest(sortDescriptors: []) private var templates: FetchedResults<ChoreTemplate>
    @State private var confettiCounter = 0
    @State private var prevPoints: Int? = nil

    private var categoryEmojiMap: [String: String] {
        Dictionary(
            templates.compactMap { t -> (String, String)? in
                guard let name = t.name, let emoji = t.category?.emoji else { return nil }
                return (name, emoji)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    init(child: Child) {
        self.child = child
        let cal = Calendar.current
        let now = Date()
        let monthStart  = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let lastStart   = cal.date(byAdding: .month, value: -1, to: monthStart)!

        let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart)!
        _currentMonthLogs = FetchRequest(
            sortDescriptors: [SortDescriptor(\.recordedAt, order: .reverse)],
            predicate: NSPredicate(
                format: "child == %@ AND deletedAt == nil AND recordedAt >= %@ AND recordedAt < %@",
                child, monthStart as CVarArg, nextMonthStart as CVarArg
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
                // ポイントエリアを白い内側カードで包む
                VStack(spacing: 0) {
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
                        .confettiCannon(trigger: $confettiCounter, colors: [
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
                }
                .padding(16)
                .background(Color(.systemBackground).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // きろくエリア
                Text("今月のきろく")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(childColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                ForEach(currentMonthLogs) { log in
                    ActivityLogRowView(
                        log: log,
                        categoryEmoji: categoryEmojiMap[log.choreName ?? ""]
                    )
                    Divider()
                }
            }
            .padding(12)
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

}
