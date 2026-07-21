import SwiftUI

struct PremiumAppEntryView: View {
    @StateObject private var store = DemoAppStore()
    @StateObject private var services = AppServices.live

    var body: some View {
        Group {
            if store.signedIn {
                PremiumRootView()
            } else {
                ProductionLoginView()
            }
        }
        .environmentObject(store)
        .environmentObject(services)
        .animation(.easeInOut(duration: 0.25), value: store.signedIn)
        .task(id: store.signedIn) {
            guard store.signedIn else { return }
            await services.refreshAll()
        }
    }
}

struct PremiumRootView: View {
    var body: some View {
        TabView {
            NavigationStack { LiveDashboardView() }
                .tabItem { Label("Главная", systemImage: "house.fill") }
            NavigationStack { AnalyticsPremiumView() }
                .tabItem { Label("Аналитика", systemImage: "chart.bar.fill") }
            NavigationStack { RestaurantFloorView() }
                .tabItem { Label("Столы", systemImage: "square.grid.3x3.fill") }
            NavigationStack { KitchenDisplayView() }
                .tabItem { Label("Кухня", systemImage: "frying.pan.fill") }
            NavigationStack { ShiftPremiumView() }
                .tabItem { Label("Смена", systemImage: "lock.open.fill") }
            NavigationStack { ReceiptsPremiumView() }
                .tabItem { Label("Чеки", systemImage: "doc.text.fill") }
            NavigationStack { InventoryPremiumView() }
                .tabItem { Label("Склад", systemImage: "shippingbox.fill") }
            NavigationStack { MorePremiumView() }
                .tabItem { Label("Ещё", systemImage: "square.grid.2x2.fill") }
        }
        .tint(Color(red: 6/255, green: 133/255, blue: 98/255))
    }
}
