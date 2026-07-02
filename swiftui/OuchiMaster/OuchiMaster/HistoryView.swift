import SwiftUI
import CoreData

struct MonthKey: Identifiable, Comparable {
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

    private var groupedByMonth: [(key: MonthKey, logs: [ActivityLog])] {
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
                    Text("\(year, format: .number.grouping(.never))年\(month)月")
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
            .buttonStyle(.plain)

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
