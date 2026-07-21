import SwiftUI

private let employeeGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let employeeDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let employeeBackground = Color(red: 244/255, green: 248/255, blue: 247/255)

struct StaffMember: Identifiable, Hashable {
    enum Role: String, CaseIterable { case administrator = "Администратор", manager = "Менеджер", cashier = "Кассир", waiter = "Официант", bartender = "Бармен", cook = "Повар", courier = "Курьер" }
    enum Status: String, CaseIterable { case working = "На смене", offline = "Не в смене", vacation = "В отпуске" }

    let id = UUID()
    let name: String
    let role: Role
    let status: Status
    let phone: String
    let hired: String
    let lastLogin: String
    let salesToday: Int
    let salesMonth: Int
    let orders: Int
    let averageCheck: Int
    let returnsCount: Int
    let cancellations: Int
    let plan: Double
}

private let demoStaff: [StaffMember] = [
    StaffMember(name: "Далер Тахиров", role: .administrator, status: .working, phone: "+998 90 123 45 67", hired: "12.03.2024", lastLogin: "Сегодня, 11:42", salesToday: 3_850_000, salesMonth: 94_200_000, orders: 42, averageCheck: 91_700, returnsCount: 1, cancellations: 0, plan: 0.96),
    StaffMember(name: "Азиз Каримов", role: .waiter, status: .working, phone: "+998 93 555 18 20", hired: "08.06.2025", lastLogin: "Сегодня, 10:58", salesToday: 2_960_000, salesMonth: 76_400_000, orders: 35, averageCheck: 84_600, returnsCount: 0, cancellations: 1, plan: 0.88),
    StaffMember(name: "Малика Рахимова", role: .cashier, status: .working, phone: "+998 97 740 22 11", hired: "19.11.2024", lastLogin: "Сегодня, 11:01", salesToday: 3_210_000, salesMonth: 82_100_000, orders: 39, averageCheck: 82_300, returnsCount: 1, cancellations: 0, plan: 0.91),
    StaffMember(name: "Шохрух Алиев", role: .bartender, status: .offline, phone: "+998 99 310 44 12", hired: "03.02.2025", lastLogin: "Вчера, 23:52", salesToday: 0, salesMonth: 61_800_000, orders: 0, averageCheck: 78_900, returnsCount: 0, cancellations: 0, plan: 0.79),
    StaffMember(name: "Ислом Нормуродов", role: .cook, status: .vacation, phone: "+998 95 620 13 44", hired: "27.09.2023", lastLogin: "14 июля, 22:10", salesToday: 0, salesMonth: 0, orders: 0, averageCheck: 0, returnsCount: 0, cancellations: 0, plan: 0.72)
]

struct MorePremiumView: View {
    var body: some View {
        List {
            Section("Управление") {
                NavigationLink { EmployeesPremiumView() } label: { Label("Сотрудники", systemImage: "person.3.fill") }
                NavigationLink { InventoryPremiumView() } label: { Label("Склад", systemImage: "shippingbox.fill") }
                NavigationLink { NotificationsPremiumView() } label: { Label("Уведомления", systemImage: "bell.badge.fill") }
            }
            Section("Система") {
                NavigationLink { SettingsPremiumView() } label: { Label("Настройки", systemImage: "gearshape.fill") }
                LabeledContent("Версия", value: "1.0 Demo")
            }
        }
        .navigationTitle("Ещё")
        .tint(employeeGreen)
    }
}

struct EmployeesPremiumView: View {
    @State private var search = ""
    @State private var selectedRole: StaffMember.Role?
    @State private var selectedStatus: StaffMember.Status?

    private var filtered: [StaffMember] {
        demoStaff.filter { member in
            (search.isEmpty || member.name.localizedCaseInsensitiveContains(search) || member.phone.contains(search)) &&
            (selectedRole == nil || member.role == selectedRole) &&
            (selectedStatus == nil || member.status == selectedStatus)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summary
                filters
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { member in
                        NavigationLink { EmployeeDetailView(member: member) } label: { EmployeeRow(member: member) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(employeeBackground)
        .navigationTitle("Сотрудники")
        .searchable(text: $search, prompt: "Имя или телефон")
    }

    private var summary: some View {
        HStack(spacing: 10) {
            EmployeeMetric(title: "Всего", value: "\(demoStaff.count)", icon: "person.3.fill")
            EmployeeMetric(title: "На смене", value: "\(demoStaff.filter { $0.status == .working }.count)", icon: "checkmark.circle.fill")
            EmployeeMetric(title: "Продажи", value: shortMoney(demoStaff.reduce(0) { $0 + $1.salesToday }), icon: "chart.line.uptrend.xyaxis")
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            Picker("Статус", selection: $selectedStatus) {
                Text("Все").tag(StaffMember.Status?.none)
                ForEach(StaffMember.Status.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Роль").foregroundStyle(.secondary)
                Spacer()
                Picker("Роль", selection: $selectedRole) {
                    Text("Все роли").tag(StaffMember.Role?.none)
                    ForEach(StaffMember.Role.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct EmployeeMetric: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(employeeGreen)
            Text(value).font(.headline).foregroundStyle(employeeDark).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmployeeRow: View {
    let member: StaffMember
    private var statusColor: Color { member.status == .working ? employeeGreen : member.status == .vacation ? .orange : .gray }
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(employeeGreen.opacity(0.12))
                Text(member.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined())
                    .font(.headline).foregroundStyle(employeeGreen)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name).font(.headline).foregroundStyle(employeeDark)
                Text(member.role.rawValue).font(.caption).foregroundStyle(.secondary)
                Text(member.status.rawValue).font(.caption2.bold()).foregroundStyle(statusColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(money(member.salesToday)).font(.subheadline.bold()).foregroundStyle(employeeDark)
                Text("\(member.orders) заказов").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct EmployeeDetailView: View {
    let member: StaffMember
    @State private var permissions = ["Отчёты": true, "Склад": true, "Возвраты": false, "Закрытие смены": false, "Изменение цен": false]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profile
                performance
                details
                permissionsCard
            }
            .padding()
        }
        .background(employeeBackground)
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profile: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(employeeGreen.opacity(0.12))
                Image(systemName: "person.fill").font(.system(size: 38)).foregroundStyle(employeeGreen)
            }.frame(width: 82, height: 82)
            Text(member.name).font(.title3.bold()).foregroundStyle(employeeDark)
            Text(member.role.rawValue).foregroundStyle(.secondary)
            Text(member.status.rawValue).font(.caption.bold()).foregroundStyle(member.status == .working ? employeeGreen : .secondary)
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var performance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Производительность").font(.headline).foregroundStyle(employeeDark)
            ProgressView(value: member.plan) { Text("Выполнение плана") } currentValueLabel: { Text("\(Int(member.plan * 100))%") }
                .tint(employeeGreen)
            HStack {
                PerformanceValue(title: "Сегодня", value: money(member.salesToday))
                PerformanceValue(title: "За месяц", value: money(member.salesMonth))
            }
            HStack {
                PerformanceValue(title: "Средний чек", value: money(member.averageCheck))
                PerformanceValue(title: "Заказы", value: "\(member.orders)")
            }
            HStack {
                PerformanceValue(title: "Возвраты", value: "\(member.returnsCount)")
                PerformanceValue(title: "Отмены", value: "\(member.cancellations)")
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var details: some View {
        VStack(spacing: 11) {
            detailLine("Телефон", member.phone)
            detailLine("Дата приёма", member.hired)
            detailLine("Последний вход", member.lastLogin)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Права доступа").font(.headline).foregroundStyle(employeeDark)
            ForEach(permissions.keys.sorted(), id: \.self) { key in
                Toggle(key, isOn: Binding(get: { permissions[key] ?? false }, set: { permissions[key] = $0 }))
                    .tint(employeeGreen)
            }
            Text("В рабочей версии изменение критических прав потребует Face ID или PIN администратора.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium) }
    }
}

private struct PerformanceValue: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.subheadline.bold()).foregroundStyle(employeeDark).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotificationsPremiumView: View {
    var body: some View {
        List {
            Label("Возврат чека #10480", systemImage: "arrow.uturn.backward.circle.fill")
            Label("Кофе заканчивается на складе", systemImage: "exclamationmark.triangle.fill")
            Label("Смена №1842 открыта", systemImage: "lock.open.fill")
        }.navigationTitle("Уведомления")
    }
}

struct SettingsPremiumView: View {
    @State private var pushEnabled = true
    @State private var biometricEnabled = true
    var body: some View {
        Form {
            Section("Безопасность") {
                Toggle("Face ID", isOn: $biometricEnabled)
                Toggle("Push-уведомления", isOn: $pushEnabled)
            }
            Section("Оборудование") {
                NavigationLink("Принтеры") { Text("Настройка принтеров") }
                NavigationLink("Платёжные терминалы") { Text("Настройка терминалов") }
            }
            Section("Интеграции") {
                LabeledContent("CaseonePOS API", value: "Демо")
            }
        }
        .navigationTitle("Настройки")
        .tint(employeeGreen)
    }
}

private func money(_ value: Int) -> String { "\(value.formatted()) сум" }
private func shortMoney(_ value: Int) -> String {
    value >= 1_000_000 ? String(format: "%.1f млн", Double(value) / 1_000_000) : value.formatted()
}
