import SwiftUI

private let operationsGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let operationsDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let operationsBackground = Color(red: 244/255, green: 248/255, blue: 247/255)

enum RestaurantTableStatus: String, CaseIterable, Identifiable {
    case free = "Свободен"
    case waiting = "Ожидает заказ"
    case serving = "Обслуживается"
    case payment = "Ожидает оплату"
    case reserved = "Забронирован"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .free: return operationsGreen
        case .waiting: return .orange
        case .serving: return .blue
        case .payment: return .purple
        case .reserved: return .red
        }
    }

    var icon: String {
        switch self {
        case .free: return "checkmark.circle.fill"
        case .waiting: return "clock.fill"
        case .serving: return "fork.knife"
        case .payment: return "creditcard.fill"
        case .reserved: return "calendar.badge.clock"
        }
    }
}

struct RestaurantTable: Identifiable, Hashable {
    let id: Int
    let name: String
    let zone: String
    let seats: Int
    let status: RestaurantTableStatus
    let guests: Int
    let waiter: String?
    let openedAt: String?
    let total: Int
    let kitchenStatus: String?
    let barStatus: String?
}

private let restaurantTables: [RestaurantTable] = [
    .init(id: 1, name: "Стол 1", zone: "Главный зал", seats: 4, status: .serving, guests: 3, waiter: "Азиз", openedAt: "11:18", total: 428_000, kitchenStatus: "2 блюда готовятся", barStatus: "Готово"),
    .init(id: 2, name: "Стол 2", zone: "Главный зал", seats: 4, status: .free, guests: 0, waiter: nil, openedAt: nil, total: 0, kitchenStatus: nil, barStatus: nil),
    .init(id: 3, name: "Стол 3", zone: "Главный зал", seats: 6, status: .payment, guests: 5, waiter: "Малика", openedAt: "10:42", total: 786_000, kitchenStatus: "Выдано", barStatus: "Выдано"),
    .init(id: 4, name: "Стол 4", zone: "Терраса", seats: 4, status: .waiting, guests: 2, waiter: "Азиз", openedAt: "11:37", total: 0, kitchenStatus: "Заказ не принят", barStatus: nil),
    .init(id: 5, name: "Стол 5", zone: "Терраса", seats: 8, status: .reserved, guests: 0, waiter: nil, openedAt: "13:00", total: 0, kitchenStatus: nil, barStatus: nil),
    .init(id: 6, name: "VIP 1", zone: "VIP", seats: 10, status: .serving, guests: 8, waiter: "Далер", openedAt: "10:55", total: 1_642_000, kitchenStatus: "1 блюдо просрочено", barStatus: "3 напитка готовятся"),
    .init(id: 7, name: "VIP 2", zone: "VIP", seats: 12, status: .free, guests: 0, waiter: nil, openedAt: nil, total: 0, kitchenStatus: nil, barStatus: nil),
    .init(id: 8, name: "Стол 8", zone: "Терраса", seats: 4, status: .serving, guests: 4, waiter: "Малика", openedAt: "11:04", total: 334_000, kitchenStatus: "Готово", barStatus: "Выдано")
]

struct RestaurantFloorView: View {
    @State private var selectedZone = "Все"
    @State private var selectedStatus: RestaurantTableStatus?

    private var zones: [String] { ["Все"] + Array(Set(restaurantTables.map(\.zone))).sorted() }

    private var filteredTables: [RestaurantTable] {
        restaurantTables.filter { table in
            (selectedZone == "Все" || table.zone == selectedZone) &&
            (selectedStatus == nil || table.status == selectedStatus)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                filters
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filteredTables) { table in
                        NavigationLink { RestaurantTableDetailView(table: table) } label: {
                            TableCard(table: table)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(operationsBackground)
        .navigationTitle("Столы")
    }

    private var summary: some View {
        HStack(spacing: 10) {
            OperationsMetric(title: "Всего", value: "\(restaurantTables.count)", icon: "square.grid.3x3.fill")
            OperationsMetric(title: "Занято", value: "\(restaurantTables.filter { $0.status != .free && $0.status != .reserved }.count)", icon: "person.2.fill")
            OperationsMetric(title: "Выручка", value: compactMoney(restaurantTables.reduce(0) { $0 + $1.total }), icon: "banknote.fill")
        }
    }

    private var filters: some View {
        VStack(spacing: 12) {
            Picker("Зона", selection: $selectedZone) {
                ForEach(zones, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Все", selected: selectedStatus == nil) { selectedStatus = nil }
                    ForEach(RestaurantTableStatus.allCases) { status in
                        FilterChip(title: status.rawValue, selected: selectedStatus == status, color: status.color) {
                            selectedStatus = status
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct TableCard: View {
    let table: RestaurantTable

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: table.status.icon).foregroundStyle(table.status.color)
                Spacer()
                Text(table.zone).font(.caption2).foregroundStyle(.secondary)
            }
            Text(table.name).font(.headline).foregroundStyle(operationsDark)
            Text(table.status.rawValue).font(.caption.bold()).foregroundStyle(table.status.color)
            Divider()
            HStack {
                Label("\(table.guests)/\(table.seats)", systemImage: "person.2")
                Spacer()
                Text(table.total == 0 ? "—" : fullMoney(table.total)).fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let waiter = table.waiter {
                Text("Официант: \(waiter)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(table.status.color.opacity(0.25)))
    }
}

struct RestaurantTableDetailView: View {
    let table: RestaurantTable

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Image(systemName: table.status.icon).font(.system(size: 36)).foregroundStyle(table.status.color)
                    Text(table.name).font(.title2.bold()).foregroundStyle(operationsDark)
                    Text(table.status.rawValue).font(.subheadline.bold()).foregroundStyle(table.status.color)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 22))

                detailCard

                if table.status != .free && table.status != .reserved {
                    kitchenCard
                    Button("Открыть чек") { }
                        .buttonStyle(.borderedProminent)
                        .tint(operationsGreen)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(operationsBackground)
        .navigationTitle(table.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailCard: some View {
        VStack(spacing: 12) {
            detailLine("Зона", table.zone)
            detailLine("Мест", "\(table.seats)")
            detailLine("Гостей", "\(table.guests)")
            detailLine("Официант", table.waiter ?? "Не назначен")
            detailLine("Открыт", table.openedAt ?? "—")
            detailLine("Сумма", table.total == 0 ? "—" : fullMoney(table.total))
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var kitchenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статусы заказа").font(.headline).foregroundStyle(operationsDark)
            Label(table.kitchenStatus ?? "Нет данных", systemImage: "frying.pan.fill")
            Label(table.barStatus ?? "Нет данных", systemImage: "wineglass.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium) }
    }
}

enum KitchenStation: String, CaseIterable, Identifiable {
    case all = "Все"
    case hot = "Горячий"
    case cold = "Холодный"
    case bar = "Бар"
    case dessert = "Десерты"
    var id: String { rawValue }
}

enum KitchenOrderStatus: String, CaseIterable, Identifiable {
    case new = "Новый"
    case cooking = "Готовится"
    case ready = "Готово"
    case served = "Выдано"
    var id: String { rawValue }
}

struct KitchenTicket: Identifiable, Hashable {
    let id: Int
    let receipt: String
    let table: String
    let station: KitchenStation
    let items: [String]
    let minutes: Int
    var status: KitchenOrderStatus
    let comment: String?
}

struct KitchenDisplayView: View {
    @State private var station: KitchenStation = .all
    @State private var tickets: [KitchenTicket] = [
        .init(id: 1, receipt: "#10482", table: "VIP 1", station: .hot, items: ["Плов ×2", "Шашлык ×3"], minutes: 27, status: .cooking, comment: "Без острого"),
        .init(id: 2, receipt: "#10483", table: "Стол 1", station: .cold, items: ["Ачичук ×1", "Греческий ×1"], minutes: 12, status: .new, comment: nil),
        .init(id: 3, receipt: "#10484", table: "Стол 8", station: .bar, items: ["Капучино ×2", "Мохито ×1"], minutes: 9, status: .ready, comment: "Один без сахара"),
        .init(id: 4, receipt: "#10485", table: "Доставка", station: .hot, items: ["Манты ×3"], minutes: 34, status: .cooking, comment: nil),
        .init(id: 5, receipt: "#10486", table: "Стол 3", station: .dessert, items: ["Чизкейк ×2"], minutes: 6, status: .new, comment: nil)
    ]

    private var visibleTickets: [KitchenTicket] {
        tickets.filter { station == .all || $0.station == station }
            .filter { $0.status != .served }
            .sorted { $0.minutes > $1.minutes }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summary
                Picker("Цех", selection: $station) {
                    ForEach(KitchenStation.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVStack(spacing: 12) {
                    ForEach(visibleTickets) { ticket in
                        KitchenTicketCard(ticket: ticket) {
                            advance(ticket.id)
                        }
                    }
                }
            }
            .padding()
        }
        .background(operationsBackground)
        .navigationTitle("Кухня")
    }

    private var summary: some View {
        HStack(spacing: 10) {
            OperationsMetric(title: "В очереди", value: "\(tickets.filter { $0.status == .new }.count)", icon: "list.bullet.clipboard.fill")
            OperationsMetric(title: "Готовится", value: "\(tickets.filter { $0.status == .cooking }.count)", icon: "flame.fill")
            OperationsMetric(title: "Просрочено", value: "\(tickets.filter { $0.minutes >= 25 && $0.status != .ready && $0.status != .served }.count)", icon: "exclamationmark.triangle.fill")
        }
    }

    private func advance(_ id: Int) {
        guard let index = tickets.firstIndex(where: { $0.id == id }) else { return }
        switch tickets[index].status {
        case .new: tickets[index].status = .cooking
        case .cooking: tickets[index].status = .ready
        case .ready: tickets[index].status = .served
        case .served: break
        }
    }
}

private struct KitchenTicketCard: View {
    let ticket: KitchenTicket
    let onAdvance: () -> Void

    private var overdue: Bool { ticket.minutes >= 25 && ticket.status != .ready }
    private var buttonTitle: String {
        switch ticket.status {
        case .new: return "Начать"
        case .cooking: return "Готово"
        case .ready: return "Выдано"
        case .served: return "Выдано"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.receipt).font(.headline).foregroundStyle(operationsDark)
                    Text("\(ticket.table) • \(ticket.station.rawValue)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(ticket.minutes) мин")
                    .font(.caption.bold())
                    .foregroundStyle(overdue ? .red : operationsGreen)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((overdue ? Color.red : operationsGreen).opacity(0.1), in: Capsule())
            }

            ForEach(ticket.items, id: \.self) { Text($0).font(.subheadline.weight(.medium)) }
            if let comment = ticket.comment {
                Label(comment, systemImage: "text.bubble.fill").font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Text(ticket.status.rawValue).font(.caption.bold()).foregroundStyle(statusColor(ticket.status))
                Spacer()
                Button(buttonTitle, action: onAdvance)
                    .buttonStyle(.borderedProminent)
                    .tint(operationsGreen)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(overdue ? Color.red.opacity(0.35) : Color.clear))
    }

    private func statusColor(_ status: KitchenOrderStatus) -> Color {
        switch status {
        case .new: return .orange
        case .cooking: return .blue
        case .ready: return operationsGreen
        case .served: return .secondary
        }
    }
}

private struct OperationsMetric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(operationsGreen)
            Text(value).font(.headline).foregroundStyle(operationsDark).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    var color: Color = operationsGreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.bold())
                .foregroundStyle(selected ? .white : color)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(selected ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private func compactMoney(_ value: Int) -> String {
    if value >= 1_000_000 { return String(format: "%.1f млн", Double(value) / 1_000_000) }
    if value >= 1_000 { return "\(value / 1_000) тыс" }
    return "\(value)"
}

private func fullMoney(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return "\(formatter.string(from: NSNumber(value: value)) ?? "\(value)") сум"
}
