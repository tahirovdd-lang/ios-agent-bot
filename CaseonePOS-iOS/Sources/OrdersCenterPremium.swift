import SwiftUI

private let ordersGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let ordersDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let ordersBackground = Color(red: 244/255, green: 248/255, blue: 247/255)

struct POSOrder: Identifiable, Hashable {
    enum OrderType: String, CaseIterable {
        case hall = "Зал"
        case delivery = "Доставка"
        case pickup = "Самовывоз"
    }

    enum Status: String, CaseIterable {
        case new = "Новый"
        case cooking = "Готовится"
        case ready = "Готов"
        case payment = "Ожидает оплату"
        case completed = "Завершён"
        case cancelled = "Отменён"
    }

    enum Payment: String {
        case cash = "Наличные"
        case uzcard = "Uzcard"
        case humo = "Humo"
        case visa = "Visa"
        case mixed = "Смешанная"
        case unpaid = "Не оплачен"
    }

    struct Item: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let quantity: Int
        let price: Int
        let station: String
        let comment: String?
    }

    let id = UUID()
    let number: Int
    let type: OrderType
    let status: Status
    let table: String?
    let guest: String
    let phone: String?
    let waiter: String
    let openedAt: String
    let elapsedMinutes: Int
    let payment: Payment
    let discount: Int
    let serviceCharge: Int
    let items: [Item]

    var subtotal: Int { items.reduce(0) { $0 + $1.price * $1.quantity } }
    var total: Int { max(0, subtotal + serviceCharge - discount) }
}

private let demoOrders: [POSOrder] = [
    POSOrder(number: 10524, type: .hall, status: .payment, table: "Стол 8", guest: "4 гостя", phone: nil, waiter: "Азиз Каримов", openedAt: "12:18", elapsedMinutes: 54, payment: .unpaid, discount: 25_000, serviceCharge: 86_000, items: [
        .init(name: "Плов", quantity: 2, price: 100_000, station: "Горячий цех", comment: nil),
        .init(name: "Шашлык из вырезки", quantity: 4, price: 38_000, station: "Мангал", comment: "Без лука"),
        .init(name: "Ачичук", quantity: 2, price: 20_000, station: "Холодный цех", comment: nil),
        .init(name: "Coca-Cola 1 л", quantity: 2, price: 22_000, station: "Бар", comment: nil)
    ]),
    POSOrder(number: 10525, type: .delivery, status: .cooking, table: nil, guest: "Далер", phone: "+998 90 123 45 67", waiter: "Малика Рахимова", openedAt: "12:44", elapsedMinutes: 28, payment: .uzcard, discount: 0, serviceCharge: 0, items: [
        .init(name: "Тандыр ягнёнка 500 г", quantity: 1, price: 140_000, station: "Горячий цех", comment: "Хорошо прожарить"),
        .init(name: "Картофель по-деревенски", quantity: 1, price: 25_000, station: "Горячий цех", comment: nil),
        .init(name: "Айран", quantity: 2, price: 15_000, station: "Бар", comment: nil)
    ]),
    POSOrder(number: 10526, type: .pickup, status: .ready, table: nil, guest: "Заказ с сайта", phone: "+998 93 777 20 20", waiter: "Система", openedAt: "12:56", elapsedMinutes: 16, payment: .humo, discount: 10_000, serviceCharge: 0, items: [
        .init(name: "Манты", quantity: 2, price: 55_000, station: "Горячий цех", comment: nil),
        .init(name: "Салат свежий", quantity: 1, price: 25_000, station: "Холодный цех", comment: nil)
    ]),
    POSOrder(number: 10523, type: .hall, status: .completed, table: "VIP 2", guest: "6 гостей", phone: nil, waiter: "Азиз Каримов", openedAt: "11:37", elapsedMinutes: 78, payment: .mixed, discount: 50_000, serviceCharge: 152_000, items: [
        .init(name: "Жиз из баранины 1 кг", quantity: 2, price: 280_000, station: "Горячий цех", comment: nil),
        .init(name: "Овощи на мангале", quantity: 2, price: 45_000, station: "Мангал", comment: nil),
        .init(name: "Чайник чая", quantity: 3, price: 20_000, station: "Бар", comment: nil)
    ])
]

struct OrdersCenterPremiumView: View {
    @State private var selectedStatus: POSOrder.Status?
    @State private var selectedType: POSOrder.OrderType?
    @State private var search = ""
    @State private var showAlerts = false

    private var filteredOrders: [POSOrder] {
        demoOrders.filter { order in
            (selectedStatus == nil || order.status == selectedStatus) &&
            (selectedType == nil || order.type == selectedType) &&
            (search.isEmpty || String(order.number).contains(search) || order.waiter.localizedCaseInsensitiveContains(search) || (order.table?.localizedCaseInsensitiveContains(search) ?? false))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summary
                filters
                LazyVStack(spacing: 12) {
                    ForEach(filteredOrders) { order in
                        NavigationLink { OrderDetailPremiumView(order: order) } label: {
                            OrderCardPremium(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(ordersBackground)
        .navigationTitle("Заказы")
        .searchable(text: $search, prompt: "Чек, стол или сотрудник")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAlerts = true } label: {
                    Image(systemName: "bell.badge.fill")
                }
                .tint(ordersGreen)
            }
        }
        .sheet(isPresented: $showAlerts) {
            NavigationStack { ManagerAlertsPremiumView() }
        }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Активные заказы").font(.caption).foregroundStyle(.secondary)
                    Text("\(demoOrders.filter { ![.completed, .cancelled].contains($0.status) }.count)")
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(ordersDark)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("На сумму").font(.caption).foregroundStyle(.secondary)
                    Text(ordersMoney(demoOrders.filter { ![.completed, .cancelled].contains($0.status) }.reduce(0) { $0 + $1.total }))
                        .font(.title3.bold()).foregroundStyle(ordersGreen)
                }
            }
            Divider()
            HStack {
                OrdersSummaryItem(title: "Готовятся", value: "\(demoOrders.filter { $0.status == .cooking }.count)", icon: "flame.fill")
                OrdersSummaryItem(title: "Готовы", value: "\(demoOrders.filter { $0.status == .ready }.count)", icon: "checkmark.circle.fill")
                OrdersSummaryItem(title: "К оплате", value: "\(demoOrders.filter { $0.status == .payment }.count)", icon: "creditcard.fill")
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var filters: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    OrdersFilterChip(title: "Все статусы", selected: selectedStatus == nil) { selectedStatus = nil }
                    ForEach(POSOrder.Status.allCases, id: \.self) { status in
                        OrdersFilterChip(title: status.rawValue, selected: selectedStatus == status) { selectedStatus = status }
                    }
                }
            }
            Picker("Тип", selection: $selectedType) {
                Text("Все").tag(POSOrder.OrderType?.none)
                ForEach(POSOrder.OrderType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(Optional(type))
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct OrdersSummaryItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(ordersGreen)
            Text(value).font(.headline).foregroundStyle(ordersDark)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OrdersFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(selected ? .white : ordersDark)
                .background(selected ? ordersGreen : .white, in: Capsule())
        }
    }
}

private struct OrderCardPremium: View {
    let order: POSOrder

    private var statusColor: Color {
        switch order.status {
        case .new: return .blue
        case .cooking: return .orange
        case .ready: return ordersGreen
        case .payment: return .purple
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Чек #\(order.number)").font(.headline).foregroundStyle(ordersDark)
                    Text(order.table ?? order.type.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(order.status.rawValue).font(.caption.bold()).foregroundStyle(statusColor)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            HStack {
                Label(order.waiter, systemImage: "person.fill")
                Spacer()
                Label("\(order.elapsedMinutes) мин", systemImage: "clock")
            }
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(order.items.reduce(0) { $0 + $1.quantity }) позиций").font(.subheadline)
                Spacer()
                Text(ordersMoney(order.total)).font(.headline).foregroundStyle(ordersDark)
            }
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 19))
    }
}

struct OrderDetailPremiumView: View {
    let order: POSOrder
    @State private var status: POSOrder.Status

    init(order: POSOrder) {
        self.order = order
        _status = State(initialValue: order.status)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                header
                items
                payment
                actions
            }
            .padding()
        }
        .background(ordersBackground)
        .navigationTitle("Чек #\(order.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 11) {
            OrderDetailLine(title: "Тип", value: order.type.rawValue)
            OrderDetailLine(title: "Стол / клиент", value: order.table ?? order.guest)
            OrderDetailLine(title: "Официант", value: order.waiter)
            OrderDetailLine(title: "Открыт", value: "\(order.openedAt) · \(order.elapsedMinutes) мин")
            if let phone = order.phone { OrderDetailLine(title: "Телефон", value: phone) }
            Picker("Статус", selection: $status) {
                ForEach(POSOrder.Status.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(ordersGreen)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Состав заказа").font(.headline).foregroundStyle(ordersDark)
            ForEach(order.items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(item.quantity) × \(item.name)").fontWeight(.medium)
                        Spacer()
                        Text(ordersMoney(item.price * item.quantity)).fontWeight(.semibold)
                    }
                    Text(item.station).font(.caption).foregroundStyle(.secondary)
                    if let comment = item.comment {
                        Label(comment, systemImage: "text.bubble.fill").font(.caption).foregroundStyle(.orange)
                    }
                }
                if item.id != order.items.last?.id { Divider() }
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var payment: some View {
        VStack(spacing: 10) {
            OrderDetailLine(title: "Подытог", value: ordersMoney(order.subtotal))
            OrderDetailLine(title: "Сервис", value: ordersMoney(order.serviceCharge))
            OrderDetailLine(title: "Скидка", value: "−\(ordersMoney(order.discount))")
            Divider()
            HStack {
                Text("Итого").font(.headline)
                Spacer()
                Text(ordersMoney(order.total)).font(.title3.bold()).foregroundStyle(ordersGreen)
            }
            OrderDetailLine(title: "Оплата", value: order.payment.rawValue)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Отметить готовым") { status = .ready }
                .buttonStyle(.borderedProminent).tint(ordersGreen).frame(maxWidth: .infinity)
            HStack {
                Button("Печать") { }.buttonStyle(.bordered)
                Button("Отправить чек") { }.buttonStyle(.bordered)
                Button("Отмена") { status = .cancelled }.buttonStyle(.bordered).tint(.red)
            }
        }
    }
}

private struct OrderDetailLine: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
    }
}

struct ManagerAlert: Identifiable {
    enum Severity { case info, warning, critical }
    let id = UUID()
    let title: String
    let message: String
    let time: String
    let severity: Severity
    var read: Bool
}

struct ManagerAlertsPremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alerts = [
        ManagerAlert(title: "Просрочка кухни", message: "Чек #10525 готовится дольше установленного времени.", time: "Сейчас", severity: .critical, read: false),
        ManagerAlert(title: "Критический остаток", message: "Кофе зерновой: осталось 1,8 кг.", time: "8 мин назад", severity: .warning, read: false),
        ManagerAlert(title: "Крупный чек", message: "Чек #10523 закрыт на сумму 812 000 сум.", time: "21 мин назад", severity: .info, read: true),
        ManagerAlert(title: "Возврат", message: "Малика оформила возврат позиции на 38 000 сум.", time: "34 мин назад", severity: .warning, read: false)
    ]

    var body: some View {
        List {
            Section {
                ForEach(alerts.indices, id: \.self) { index in
                    Button {
                        alerts[index].read = true
                    } label: {
                        AlertRowPremium(alert: alerts[index])
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Непрочитано: \(alerts.filter { !$0.read }.count)")
                    Spacer()
                    Button("Прочитать все") {
                        for index in alerts.indices { alerts[index].read = true }
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Уведомления")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") { dismiss() }
            }
        }
    }
}

private struct AlertRowPremium: View {
    let alert: ManagerAlert

    private var icon: String {
        switch alert.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var color: Color {
        switch alert.severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title).fontWeight(alert.read ? .regular : .bold)
                    Spacer()
                    Text(alert.time).font(.caption2).foregroundStyle(.secondary)
                }
                Text(alert.message).font(.subheadline).foregroundStyle(.secondary)
            }
            if !alert.read { Circle().fill(ordersGreen).frame(width: 8, height: 8) }
        }
        .padding(.vertical, 5)
    }
}

private func ordersMoney(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return "\(formatter.string(from: NSNumber(value: value)) ?? "0") сум"
}
