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
