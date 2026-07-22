import SwiftUI
import Charts

struct LiveSalesPoint: Identifiable, Hashable {
    let id = UUID()
    let hour: String
    let amount: Double
}

struct LiveDashboardSnapshot: Hashable {
    let revenueToday: Double
    let revenueYesterday: Double
    let monthRevenue: Double
    let averageCheck: Double
    let checks: Int
    let openChecks: Int
    let activeTables: Int
    let guests: Int
    let kitchenQueue: Int
    let deliveryOrders: Int
    let pickupOrders: Int
    let refunds: Double
    let cancellations: Int
    let averageCookingMinutes: Int
    let employeesOnShift: Int
    let salesByHour: [LiveSalesPoint]

    static let demo = LiveDashboardSnapshot(
        revenueToday: 18_740_000,
        revenueYesterday: 16_980_000,
        monthRevenue: 436_250_000,
        averageCheck: 286_000,
        checks: 146,
        openChecks: 18,
        activeTables: 13,
        guests: 64,
        kitchenQueue: 11,
        deliveryOrders: 9,
        pickupOrders: 5,
        refunds: 340_000,
        cancellations: 3,
        averageCookingMinutes: 19,
        employeesOnShift: 17,
        salesByHour: [
            LiveSalesPoint(hour: "09", amount: 420_000),
            LiveSalesPoint(hour: "11", amount: 1_150_000),
            LiveSalesPoint(hour: "13", amount: 2_960_000),
            LiveSalesPoint(hour: "15", amount: 2_240_000),
            LiveSalesPoint(hour: "17", amount: 3_180_000),
            LiveSalesPoint(hour: "19", amount: 4_350_000),
            LiveSalesPoint(hour: "21", amount: 4_440_000)
        ]
    )
}

@MainActor
final class LiveDashboardViewModel: ObservableObject {
    @Published private(set) var snapshot = LiveDashboardSnapshot.demo
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated = Date()
    @Published private(set) var isOnline = false

    private var refreshTask: Task<Void, Never>?

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await self?.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Пока сервер CaseonePOS не подключён, интерфейс работает с безопасным офлайн-снимком.
        // Репозиторий можно подставить сюда без изменения экрана.
        try? await Task.sleep(for: .milliseconds(350))
        snapshot = .demo
        lastUpdated = Date()
        isOnline = false
    }
}

struct LiveDashboardView: View {
    @StateObject private var viewModel = LiveDashboardViewModel()

    private let brandGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
    private let brandDark = Color(red: 1/255, green: 63/255, blue: 74/255)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                liveHeader
                revenueHero
                operationalGrid
                salesChart
                controlSection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("CaseonePOS")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Обновить данные")
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.refresh() }
    }

    private var liveHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((viewModel.isOnline ? Color.green : Color.orange).opacity(0.14))
                Image(systemName: viewModel.isOnline ? "wifi" : "wifi.slash")
                    .foregroundStyle(viewModel.isOnline ? .green : .orange)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.isOnline ? "Онлайн" : "Офлайн-режим")
                    .font(.headline)
                Text("Обновлено \(viewModel.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("LIVE")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(brandGreen, in: Capsule())
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var revenueHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Выручка сегодня")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
            Text(money(viewModel.snapshot.revenueToday))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack {
                Label(growthText, systemImage: "arrow.up.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("Вчера: \(money(viewModel.snapshot.revenueYesterday))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [brandDark, brandGreen], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private var operationalGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard("Средний чек", money(viewModel.snapshot.averageCheck), "banknote.fill")
            metricCard("Чеки", "\(viewModel.snapshot.checks)", "doc.text.fill")
            metricCard("Открытые чеки", "\(viewModel.snapshot.openChecks)", "clock.fill")
            metricCard("Активные столы", "\(viewModel.snapshot.activeTables)", "table.furniture.fill")
            metricCard("Гости", "\(viewModel.snapshot.guests)", "person.2.fill")
            metricCard("На смене", "\(viewModel.snapshot.employeesOnShift)", "person.badge.clock.fill")
            metricCard("Очередь кухни", "\(viewModel.snapshot.kitchenQueue)", "flame.fill")
            metricCard("Готовка", "\(viewModel.snapshot.averageCookingMinutes) мин", "timer")
        }
    }

    private var salesChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Продажи по часам")
                        .font(.headline)
                    Text("Динамика текущего дня")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(money(viewModel.snapshot.monthRevenue))
                    .font(.caption.bold())
                    .foregroundStyle(brandGreen)
            }

            Chart(viewModel.snapshot.salesByHour) { point in
                AreaMark(
                    x: .value("Час", point.hour),
                    y: .value("Продажи", point.amount)
                )
                .foregroundStyle(
                    LinearGradient(colors: [brandGreen.opacity(0.42), brandGreen.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                )

                LineMark(
                    x: .value("Час", point.hour),
                    y: .value("Продажи", point.amount)
                )
                .foregroundStyle(brandGreen)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                PointMark(
                    x: .value("Час", point.hour),
                    y: .value("Продажи", point.amount)
                )
                .foregroundStyle(brandDark)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(compactMoney(number))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Контроль операций")
                .font(.headline)
            controlRow("Доставка", value: "\(viewModel.snapshot.deliveryOrders)", icon: "car.fill")
            controlRow("Самовывоз", value: "\(viewModel.snapshot.pickupOrders)", icon: "takeoutbag.and.cup.and.straw.fill")
            controlRow("Возвраты", value: money(viewModel.snapshot.refunds), icon: "arrow.uturn.backward.circle.fill")
            controlRow("Отмены", value: "\(viewModel.snapshot.cancellations)", icon: "xmark.circle.fill")
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func metricCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(brandGreen)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func controlRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(brandGreen)
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }

    private var growthText: String {
        let yesterday = max(viewModel.snapshot.revenueYesterday, 1)
        let percent = (viewModel.snapshot.revenueToday - yesterday) / yesterday * 100
        return String(format: "+%.1f%%", percent)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "UZS").precision(.fractionLength(0)))
    }

    private func compactMoney(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1f млн", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f тыс", value / 1_000) }
        return String(format: "%.0f", value)
    }
}

struct DirectorMonitorView: View {
    private let rows: [(String, String, String)] = [
        ("Оборот", "436,3 млн сум", "arrow.up.right"),
        ("Валовая прибыль", "182,8 млн сум", "chart.line.uptrend.xyaxis"),
        ("Себестоимость", "41,7%", "percent"),
        ("Фонд оплаты труда", "68,4 млн сум", "person.3.fill"),
        ("Расходы", "124,6 млн сум", "creditcard.fill"),
        ("Денежный поток", "+58,2 млн сум", "waveform.path.ecg")
    ]

    var body: some View {
        List {
            Section("Текущий месяц") {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 12) {
                        Image(systemName: row.2)
                            .foregroundStyle(Color(red: 6/255, green: 133/255, blue: 98/255))
                            .frame(width: 30)
                        Text(row.0)
                        Spacer()
                        Text(row.1).fontWeight(.semibold)
                    }
                }
            }

            Section("KPI ресторана") {
                LabeledContent("Выполнение плана", value: "92%")
                LabeledContent("Средняя маржа", value: "38,6%")
                LabeledContent("Оборачиваемость", value: "8,4 дня")
                LabeledContent("Фудкост", value: "31,2%")
            }
        }
        .navigationTitle("Монитор директора")
    }
}
