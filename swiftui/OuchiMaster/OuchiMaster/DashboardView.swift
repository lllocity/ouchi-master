import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt)],
        animation: .default
    ) private var children: FetchedResults<Child>

    @State private var isPressing = false
    @State private var showChoreEntry = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var toastChildName = ""
    @State private var toastChoreName = ""
    @State private var toastPoints: Int32 = 0
    @State private var showToast = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    headerView
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(children) { child in
                            ChildPointPanelView(child: child)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }

                if isPressing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            Text("そのまま持ちつづけて…")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }

                if showToast {
                    VStack {
                        PointToastView(
                            childName: toastChildName,
                            choreName: toastChoreName,
                            points: toastPoints
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 80)
                    .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .onLongPressGesture(minimumDuration: 3, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.2)) { isPressing = pressing }
            }) {
                isPressing = false
                showChoreEntry = true
            }
            .fullScreenCover(isPresented: $showChoreEntry) {
                ChoreEntryView()
            }
            .navigationDestination(isPresented: $showHistory) { HistoryView() }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .onReceive(NotificationCenter.default.publisher(for: .showPointToast)) { note in
                toastChildName = note.userInfo?["childName"] as? String ?? ""
                toastChoreName = note.userInfo?["choreName"] as? String ?? ""
                toastPoints    = note.userInfo?["points"]    as? Int32 ?? 0
                withAnimation(.easeIn(duration: 0.3)) { showToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) { showToast = false }
                }
            }
        }
    }

    var headerView: some View {
        let month = Calendar.current.component(.month, from: Date())
        return HStack(alignment: .center) {
            Text("🏠 おうちマスター")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(month)月")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .padding(8)
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color(hex: "FF6B6B"), Color(hex: "FFB347")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24
            )
        )
        .shadow(color: Color(hex: "FF6B6B").opacity(0.3), radius: 12, y: 4)
        // Safe area top padding added manually (ignoresSafeArea + custom header)
        .padding(.top, UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.safeAreaInsets.top }
            .first ?? 44
        )
    }
}

// MARK: - Toast view
struct PointToastView: View {
    let childName: String
    let choreName: String
    let points: Int32

    var body: some View {
        VStack(spacing: 4) {
            Text(childName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(choreName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text("\(points >= 0 ? "+" : "")\(points)P")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(points < 0 ? Color.red.opacity(0.9) : Color.yellow)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }
}
