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
