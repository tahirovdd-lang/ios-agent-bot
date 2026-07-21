import SwiftUI
import Charts

// MARK: - Brand

enum CaseoneTheme {
    static let emerald = Color(red: 6/255, green: 133/255, blue: 98/255)   // #068562
    static let deepTeal = Color(red: 1/255, green: 63/255, blue: 74/255)    // #013F4A
    static let background = Color(red: 244/255, green: 248/255, blue: 247/255)
    static let card = Color.white
    static let muted = Color.secondary
    static let gradient = LinearGradient(
        colors: [deepTeal, emerald],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Models

struct DashboardSnapshot {
    let organization = "UZBEGIM CAFE"
    let manager = "Тахиров Далер Хайдарович"
    let revenue = 680_000
    let receiptCount = 9
    let averageReceipt = 75_556
    let service = 0
    let cash = 600_000
    let cards = 80_000
    let shiftOpenedAt = "08:00"
}

struct HourSale: Identifiable {
    let id = UUID()
    let hour: String
    let amount: Double
}

struct ReceiptItem: Identifiable {
    let id = UUID()
    let number: String
    let table: String
    let waiter: String
    let payment: String
    let amount: Int
    let time: String
}

private let demoHours: [HourSale] = [
    .init(hour: "00", amount: 20_000),
    .init(hour: "01", amount: 130_000),
    .init(hour: "12", amount: 300_000),
    .init(hour: "13", amount: 60_000),
    .init(hour: "16", amount: 80_000),
    .init(hour: "19", amount: 45_000),
    .init(hour: "20", amount: 45_000)
]

private let demoReceipts: [ReceiptItem] = [
    .init(number: "#1542", table: "Стол 1 · Основной зал", waiter: "Тахиров Далер", payment: "Наличные", amount: 20_000, time: "Сегодня, 00:33"),
    .init(number: "#1541", table: "Стол 1 · Основной зал", waiter: "Тахиров Далер", payment: "Наличные", amount: 60_000, time: "Вчера, 13:27"),
    .init(number: "#1540", table: "Стол 3 · Основной зал", waiter: "System Admin", payment: "Uzcard", amount: 100_000, time: "03.07, 12:03")
]

// MARK: - Root

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Главная", systemImage: "house.fill") }

            NavigationStack { AnalyticsView() }
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }

            NavigationStack { ShiftView() }
                .tabItem { Label("Смена", systemImage: "clock.arrow.circlepath") }

            NavigationStack { ReceiptsView() }
                .tabItem { Label("Чеки", systemImage: "doc.text.fill") }

            NavigationStack { MoreView() }
                .tabItem { Label("Ещё", systemImage: "square.grid.2x2.fill") }
        }
        .tint(CaseoneTheme.emerald)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    private let snapshot = DashboardSnapshot()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                welcomeHeader
                revenueHero
                metricGrid
                quickActions
                recentReceipts
            }
            .padding()
        }
        .background(CaseoneTheme.background)
        .navigationTitle("CaseonePOS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var welcomeHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(CaseoneTheme.gradient)
                Text("ТД").font(.headline).bold().foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("Добро пожаловать!").font(.headline)
                Text(snapshot.manager).font(.subheadline).bold()
                Text(snapshot.organization).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bell.fill")
                .foregroundStyle(CaseoneTheme.emerald)
        }
        .cardStyle()
    }

    private var revenueHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Оборот сегодня", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline).bold()
                Spacer()
                Text("Смена открыта")
                    .font(.caption).bold()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            Text(snapshot.revenue.uzs)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Обновлено только что")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CaseoneTheme.gradient, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: CaseoneTheme.deepTeal.opacity(0.22), radius: 18, y: 10)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            MetricCard(title: "Продаж", value: "\(snapshot.receiptCount)", icon: "receipt")
            MetricCard(title: "Средний чек", value: snapshot.averageReceipt.uzs, icon: "sum")
            MetricCard(title: "Наличные", value: snapshot.cash.uzs, icon: "banknote")
            MetricCard(title: "Карты", value: snapshot.cards.uzs, icon: "creditcard")
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрый доступ").font(.title3).bold()
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                ActionTile(title: "Аналитика", icon: "chart.pie.fill")
                ActionTile(title: "X / Z", icon: "doc.badge.gearshape")
                ActionTile(title: "Склад", icon: "shippingbox.fill")
                ActionTile(title: "Официанты", icon: "person.2.fill")
                ActionTile(title: "Кухня", icon: "fork.knife")
                ActionTile(title: "Настройки", icon: "gearshape.fill")
            }
        }
    }

    private var recentReceipts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние продажи").font(.title3).bold()
            ForEach(demoReceipts.prefix(2)) { receipt in
                ReceiptRow(receipt: receipt)
            }
        }
    }
}

// MARK: - Analytics

struct AnalyticsView: View {
    private let snapshot = DashboardSnapshot()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PeriodPicker()
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    MetricCard(title: "Оборот", value: snapshot.revenue.uzs, icon: "banknote.fill")
                    MetricCard(title: "Средний чек", value: snapshot.averageReceipt.uzs, icon: "chart.bar.doc.horizontal")
                }
                hourlyChart
                paymentBreakdown
                waiterBreakdown
            }
            .padding()
        }
        .background(CaseoneTheme.background)
        .navigationTitle("Аналитика")
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Продажи по часам").font(.headline)
            Chart(demoHours) { item in
                BarMark(x: .value("Час", item.hour), y: .value("Сумма", item.amount))
                    .foregroundStyle(CaseoneTheme.gradient)
                    .cornerRadius(6)
            }
            .frame(height: 220)
        }
        .cardStyle()
    }

    private var paymentBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("По типам оплаты").font(.headline)
            ProgressMetric(title: "Наличные", value: 600_000, total: 680_000)
            ProgressMetric(title: "Uzcard", value: 80_000, total: 680_000)
            ProgressMetric(title: "Humo", value: 0, total: 680_000)
        }
        .cardStyle()
    }

    private var waiterBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("По официантам").font(.headline)
            ProgressMetric(title: "Тахиров Далер", value: 510_000, total: 680_000)
            ProgressMetric(title: "System Admin", value: 170_000, total: 680_000)
        }
        .cardStyle()
    }
}

// MARK: - Shift

struct ShiftView: View {
    private let snapshot = DashboardSnapshot()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Смена открыта", systemImage: "lock.open.fill")
                            .font(.headline)
                        Spacer()
                        Circle().fill(.green).frame(width: 10, height: 10)
                    }
                    Text("Кассир: \(snapshot.manager)").font(.subheadline)
                    Text("Открыта сегодня в \(snapshot.shiftOpenedAt)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .cardStyle()

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    MetricCard(title: "Чеков", value: "\(snapshot.receiptCount)", icon: "receipt.fill")
                    MetricCard(title: "Итого", value: snapshot.revenue.uzs, icon: "sum")
                    MetricCard(title: "Наличные", value: snapshot.cash.uzs, icon: "banknote")
                    MetricCard(title: "Карты", value: snapshot.cards.uzs, icon: "creditcard")
                }

                VStack(spacing: 12) {
                    Button("Сформировать X-отчёт") { }
                        .buttonStyle(BrandButtonStyle())
                    Button("Z-отчёт и закрыть смену", role: .destructive) { }
                        .buttonStyle(DangerButtonStyle())
                }
            }
            .padding()
        }
        .background(CaseoneTheme.background)
        .navigationTitle("X / Z отчёты")
    }
}

// MARK: - Receipts

struct ReceiptsView: View {
    @State private var search = ""

    var filtered: [ReceiptItem] {
        guard !search.isEmpty else { return demoReceipts }
        return demoReceipts.filter { $0.number.localizedCaseInsensitiveContains(search) || $0.table.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered) { receipt in
            ReceiptRow(receipt: receipt)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CaseoneTheme.background)
        .searchable(text: $search, prompt: "Номер чека или стол")
        .navigationTitle("История чеков")
    }
}

// MARK: - More

struct MoreView: View {
    var body: some View {
        List {
            Section("Управление") {
                Label("Склад и остатки", systemImage: "shippingbox.fill")
                Label("Официанты", systemImage: "person.2.fill")
                Label("Популярные блюда", systemImage: "fork.knife.circle.fill")
                Label("Уведомления", systemImage: "bell.badge.fill")
            }
            Section("Безопасность") {
                Label("Вход по Face ID", systemImage: "faceid")
                Label("PIN для закрытия смены", systemImage: "lock.fill")
            }
            Section("Система") {
                Label("Подключение к API", systemImage: "network")
                Label("Настройки", systemImage: "gearshape.fill")
            }
        }
        .tint(CaseoneTheme.emerald)
        .navigationTitle("Ещё")
    }
}

// MARK: - Components

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(CaseoneTheme.emerald)
                .padding(10)
                .background(CaseoneTheme.emerald.opacity(0.1), in: Circle())
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .cardStyle()
    }
}

struct ActionTile: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(CaseoneTheme.emerald)
            Text(title).font(.caption).bold().multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct ReceiptRow: View {
    let receipt: ReceiptItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(CaseoneTheme.emerald)
                .padding(10)
                .background(CaseoneTheme.emerald.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("\(receipt.number) · \(receipt.table)").font(.subheadline).bold()
                Text("\(receipt.waiter) · \(receipt.payment)").font(.caption).foregroundStyle(.secondary)
                Text(receipt.time).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(receipt.amount.uzs).font(.subheadline).bold().foregroundStyle(CaseoneTheme.deepTeal)
        }
        .cardStyle()
    }
}

struct ProgressMetric: View {
    let title: String
    let value: Int
    let total: Int

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(value.uzs).font(.subheadline).bold().foregroundStyle(CaseoneTheme.deepTeal)
            }
            ProgressView(value: Double(value), total: Double(max(total, 1)))
                .tint(CaseoneTheme.emerald)
        }
    }
}

struct PeriodPicker: View {
    @State private var selected = "Сегодня"
    private let periods = ["Сегодня", "Неделя", "Месяц"]

    var body: some View {
        Picker("Период", selection: $selected) {
            ForEach(periods, id: \.self) { Text($0) }
        }
        .pickerStyle(.segmented)
    }
}

struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(CaseoneTheme.gradient, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(CaseoneTheme.card, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.045), radius: 12, y: 5)
    }
}

private extension Int {
    var uzs: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: NSNumber(value: self)) ?? String(self)) UZS"
    }
}
