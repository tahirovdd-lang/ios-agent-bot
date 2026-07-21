import SwiftUI

struct PremiumAppEntryView: View {
    @StateObject private var store = DemoAppStore()

    var body: some View {
        Group {
            if store.signedIn {
                PremiumRootView()
            } else {
                ProductionLoginView()
            }
        }
        .environmentObject(store)
        .animation(.easeInOut(duration: 0.25), value: store.signedIn)
    }
}

struct PremiumRootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardPremiumView() }
                .tabItem { Label("Главная", systemImage: "house.fill") }
            NavigationStack { DemoAnalyticsView() }
                .tabItem { Label("Аналитика", systemImage: "chart.bar.fill") }
            NavigationStack { DemoShiftView() }
                .tabItem { Label("Смена", systemImage: "lock.open.fill") }
            NavigationStack { DemoReceiptsView() }
                .tabItem { Label("Чеки", systemImage: "doc.text.fill") }
            NavigationStack { DemoMoreView() }
                .tabItem { Label("Ещё", systemImage: "square.grid.2x2.fill") }
        }
        .tint(Color(red: 6/255, green: 133/255, blue: 98/255))
    }
}
