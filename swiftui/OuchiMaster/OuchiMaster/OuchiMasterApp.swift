import SwiftUI

@main
struct OuchiMasterApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

struct ContentRootView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var seeded = false

    var body: some View {
        DashboardView()
            .task {
                guard !seeded else { return }
                seedIfNeeded(context: ctx)
                seeded = true
            }
    }
}
