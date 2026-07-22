import SwiftUI
import Charts

private let dashboardGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let dashboardDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let dashboardBackground = Color(red: 244/255, green: 248/255, blue: 247/255)
private let dashboardGradient = LinearGradient(colors: [dashboardDark, dashboardGreen], startPoint: .topLeading, endPoint: .bottomTrailing)

private struct SalesPoint: Identifiable {
    let id = UUID()
    let hour: String
    let amount: Double
}

private let dashboardSales: [SalesPoint] = [
    .init(hour: "08", amount: 35), .init(hour: "10", amount: 82),
    .init(hour: "12", amount: 145), .init(hour: "14", amount: 210),
    .init(hour: "16", amount: 128), .init(hour: "18", amount: 176),
    .init(hour: "20", amount: 94)
]

struct DashboardPremiumView: View {
    @EnvironmentObject private var store: DemoAppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                turnoverCard
                metrics
                salesChart
                shiftCard
                quickActions
                latestReceipts
                alerts
            }
            .padding()
        }
        .background(dashboardBackground)
        .navigationTitle("Главная")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dashboardGradient)
                .frame(width: 52, height: 52)
                .overlay(Text("ТД").font(.headline.bold()).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("Добрый день, Далер").font(.headline)
                Text("UZBEGIM CAFE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Label("Онлайн", systemImage: "circle.fill").font(.caption2).foregroundStyle(dashboardGreen)
            }
            Spacer()
            Button(action: {}) { Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(dashboardDark) }
        }
        .premiumCard()
    }

    private var turnoverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Оборот сегодня").font(.subheadline.bold()); Spacer(); Image(systemName: "chart.line.uptrend.xyaxis") }
            Text("680 000 UZS").font(.system(size: 34, weight: .bold, design: .rounded))
            Label("+12% относительно вчера", systemImage: "arrow.up.right").font(.caption.bold())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(dashboardGradient, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: dashboardDark.opacity(0.18), radius: 18, y: 10)
    }

    private var metrics: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            PremiumMetric(title: "Продаж", value: "9", icon: "receipt.fill")
            PremiumMetric(title: "Средний чек", value: "75 556", icon: "sum")
            PremiumMetric(title: "Наличные", value: "600 000", icon: "banknote.fill")
            PremiumMetric(title: "Карты", value: "80 000", icon: "creditcard.fill")
        }
    }

    private var salesChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Продажи по часам").font(.headline); Spacer(); Text("тыс. UZS").font(.caption).foregroundStyle(.secondary) }
            Chart(dashboardSales) {
                AreaMark(x: .value("Час", $0.hour), y: .value("Продажи", $0.amount))
                    .foregroundStyle(dashboardGreen.opacity(0.14))
                LineMark(x: .value("Час", $0.hour), y: .value("Продажи", $0.amount))
                    .foregroundStyle(dashboardGreen)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Час", $0.hour), y: .value("Продажи", $0.amount))
                    .foregroundStyle(dashboardDark)
            }
            .frame(height: 190)
        }
        .premiumCard()
    }

    private var shiftCard: some View {
        HStack(spacing: 14) {
            Image(systemName: store.shiftOpen ? "lock.open.fill" : "lock.fill")
                .font(.title2).foregroundStyle(store.shiftOpen ? dashboardGreen : .red)
                .frame(width: 48, height: 48)
                .background((store.shiftOpen ? dashboardGreen : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(store.shiftOpen ? "Смена открыта" : "Смена закрыта").font(.headline)
                Text("08:00 · Кассир Тахиров Далер").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink { DemoShiftView() } label: { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
        }
        .premiumCard()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые действия").font(.title3.bold())
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                NavigationLink { DemoAnalyticsView() } label: { PremiumAction(title: "Аналитика", icon: "chart.bar.fill") }
                NavigationLink { DemoShiftView() } label: { PremiumAction(title: "X / Z", icon: "doc.text.fill") }
                NavigationLink { DemoReceiptsView() } label: { PremiumAction(title: "Чеки", icon: "receipt") }
                NavigationLink { DemoInventoryView() } label: { PremiumAction(title: "Склад", icon: "shippingbox.fill") }
                NavigationLink { DemoWaitersView() } label: { PremiumAction(title: "Сотрудники", icon: "person.2.fill") }
                NavigationLink { DemoKitchenView() } label: { PremiumAction(title: "Кухня", icon: "fork.knife") }
            }
        }
    }

    private var latestReceipts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Последние продажи").font(.title3.bold()); Spacer(); NavigationLink("Все чеки") { DemoReceiptsView() }.font(.caption.bold()).foregroundStyle(dashboardGreen) }
            ForEach(store.receipts.prefix(3)) { receipt in
                NavigationLink { DemoReceiptDetailView(receipt: receipt) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(receipt.number).font(.headline); Text(receipt.table).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) { Text(receipt.amount.formatted(.number.grouping(.automatic)) + " UZS").font(.subheadline.bold()).foregroundStyle(dashboardDark); Text(receipt.payment).font(.caption).foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                if receipt.id != store.receipts.prefix(3).last?.id { Divider() }
            }
        }
        .premiumCard()
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Требует внимания").font(.title3.bold())
            AlertRow(icon: "exclamationmark.triangle.fill", title: "Низкий остаток", subtitle: "Red Bull — 2 шт.", tint: .orange)
            AlertRow(icon: "arrow.uturn.backward.circle.fill", title: "Возврат выполнен", subtitle: "Чек #1536 · 250 000 UZS", tint: .red)
        }
        .premiumCard()
    }
}

private struct PremiumMetric: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(dashboardGreen)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(dashboardDark)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .premiumCard()
    }
}

private struct PremiumAction: View {
    let title: String; let icon: String
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.title3).foregroundStyle(dashboardGreen)
            Text(title).font(.caption.bold()).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .premiumCard()
    }
}

private struct AlertRow: View {
    let icon: String; let title: String; let subtitle: String; let tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 36, height: 36).background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.bold()); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }
    }
}

private extension View {
    func premiumCard() -> some View {
        padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: dashboardDark.opacity(0.06), radius: 12, y: 6)
    }
}
