import SwiftUI
import Charts

private struct AnalyticsPoint: Identifiable {
    let id = UUID()
    let label: String
    let current: Double
    let previous: Double
}

private struct TopProduct: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let revenue: Int
}

struct AnalyticsPremiumView: View {
    @State private var period = "Сегодня"
    @State private var compareEnabled = true

    private let periods = ["Сегодня", "Неделя", "Месяц"]
    private let points: [AnalyticsPoint] = [
        .init(label: "08", current: 45, previous: 30),
        .init(label: "10", current: 82, previous: 65),
        .init(label: "12", current: 148, previous: 120),
        .init(label: "14", current: 210, previous: 170),
        .init(label: "16", current: 126, previous: 105),
        .init(label: "18", current: 176, previous: 130),
        .init(label: "20", current: 230, previous: 190)
    ]
    private let products: [TopProduct] = [
        .init(name: "Плов", quantity: 45, revenue: 2_250_000),
        .init(name: "Шашлык из баранины", quantity: 32, revenue: 1_920_000),
        .init(name: "Лагман", quantity: 24, revenue: 1_080_000),
        .init(name: "Манты", quantity: 18, revenue: 900_000)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                periodPicker
                summaryGrid
                revenueChart
                paymentCard
                topProducts
                staffCard
            }
            .padding()
        }
        .background(Color(red: 244/255, green: 248/255, blue: 247/255))
        .navigationTitle("Аналитика")
        .navigationBarTitleDisplayMode(.large)
    }

    private var periodPicker: some View {
        VStack(spacing: 14) {
            Picker("Период", selection: $period) {
                ForEach(periods, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Сравнить с предыдущим периодом", isOn: $compareEnabled)
                .font(.subheadline.weight(.semibold))
                .tint(analyticsGreen)
        }
        .analyticsCard()
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            AnalyticsMetric(title: "Оборот", value: "5 842 000", change: "+18,4%", icon: "banknote.fill")
            AnalyticsMetric(title: "Чеков", value: "73", change: "+11,2%", icon: "receipt.fill")
            AnalyticsMetric(title: "Средний чек", value: "80 027", change: "+6,5%", icon: "chart.line.uptrend.xyaxis")
            AnalyticsMetric(title: "Гостей", value: "126", change: "+14,8%", icon: "person.2.fill")
        }
    }

    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Продажи по часам").font(.headline)
                    Text("тыс. UZS").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Пик 20:00", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Время", point.label),
                        y: .value("Текущий", point.current)
                    )
                    .foregroundStyle(LinearGradient(colors: [analyticsGreen.opacity(0.32), analyticsGreen.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Время", point.label),
                        y: .value("Текущий", point.current)
                    )
                    .foregroundStyle(analyticsGreen)
                    .lineStyle(.init(lineWidth: 3))
                    .interpolationMethod(.catmullRom)

                    if compareEnabled {
                        LineMark(
                            x: .value("Время", point.label),
                            y: .value("Предыдущий", point.previous)
                        )
                        .foregroundStyle(.secondary.opacity(0.65))
                        .lineStyle(.init(lineWidth: 2, dash: [5, 5]))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 230)
        }
        .analyticsCard()
    }

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Способы оплаты").font(.headline)
            PaymentRow(title: "Наличные", amount: "3 420 000 UZS", progress: 0.59, icon: "banknote.fill")
            PaymentRow(title: "Uzcard", amount: "1 120 000 UZS", progress: 0.19, icon: "creditcard.fill")
            PaymentRow(title: "Humo", amount: "802 000 UZS", progress: 0.14, icon: "creditcard")
            PaymentRow(title: "Visa / Mastercard", amount: "500 000 UZS", progress: 0.08, icon: "wave.3.right.circle.fill")
        }
        .analyticsCard()
    }

    private var topProducts: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Топ продаж").font(.headline)
                Spacer()
                Button("Все блюда") { }
                    .font(.caption.bold())
                    .foregroundStyle(analyticsGreen)
            }
            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(analyticsGreen.opacity(0.12), in: Circle())
                        .foregroundStyle(analyticsGreen)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name).font(.subheadline.bold())
                        Text("Продано: \(product.quantity)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(product.revenue.analyticsUZS)
                        .font(.caption.bold())
                        .foregroundStyle(analyticsDark)
                }
                if index < products.count - 1 { Divider() }
            }
        }
        .analyticsCard()
    }

    private var staffCard: some View {
        NavigationLink {
            DemoWaitersView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(analyticsGradient, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Аналитика сотрудников").font(.headline).foregroundStyle(.primary)
                    Text("Выручка, чеки и средний чек по каждому официанту")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .analyticsCard()
        }
        .buttonStyle(.plain)
    }
}

private struct AnalyticsMetric: View {
    let title: String
    let value: String
    let change: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(analyticsGreen)
                Spacer()
                Text(change)
                    .font(.caption2.bold())
                    .foregroundStyle(analyticsGreen)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(analyticsGreen.opacity(0.1), in: Capsule())
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(analyticsDark)
            Text(title == "Гостей" || title == "Чеков" ? "" : "UZS")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .analyticsCard()
    }
}

private struct PaymentRow: View {
    let title: String
    let amount: String
    let progress: Double
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon).font(.subheadline.bold())
                Spacer()
                Text(amount).font(.caption.bold()).foregroundStyle(analyticsDark)
            }
            ProgressView(value: progress).tint(analyticsGreen)
        }
    }
}

private let analyticsGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let analyticsDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let analyticsGradient = LinearGradient(colors: [analyticsDark, analyticsGreen], startPoint: .topLeading, endPoint: .bottomTrailing)

private extension View {
    func analyticsCard() -> some View {
        padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: analyticsDark.opacity(0.055), radius: 12, y: 6)
    }
}

private extension Int {
    var analyticsUZS: String {
        NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
            .replacingOccurrences(of: ",", with: " ") + " UZS"
    }
}
