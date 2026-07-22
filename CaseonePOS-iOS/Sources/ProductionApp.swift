import SwiftUI
import Charts
import LocalAuthentication

// MARK: - Offline demo application

@MainActor
final class DemoAppStore: ObservableObject {
    @Published var signedIn = false
    @Published var shiftOpen = true
    @Published var showCloseConfirmation = false
    @Published var selectedReceipt: DemoReceipt?

    let receipts: [DemoReceipt] = [
        .init(number: "#1542", date: "21.07.2026 13:27", table: "Стол 5 · Основной зал", waiter: "Тахиров Далер", payment: "Наличные", amount: 145_000),
        .init(number: "#1541", date: "21.07.2026 13:12", table: "Стол 2 · Терраса", waiter: "Тахиров Далер", payment: "Uzcard", amount: 98_000),
        .init(number: "#1540", date: "21.07.2026 12:45", table: "Стол 1 · VIP зал", waiter: "System Admin", payment: "Humo", amount: 75_000),
        .init(number: "#1539", date: "21.07.2026 12:30", table: "Стол 8 · Основной зал", waiter: "Тахиров Далер", payment: "Наличные", amount: 120_000)
    ]

    func authenticateFaceID() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            signedIn = true
            return
        }
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Вход в CaseonePOS Manager")) == true {
            signedIn = true
        }
    }
}

struct DemoReceipt: Identifiable, Hashable {
    let id = UUID()
    let number: String
    let date: String
    let table: String
    let waiter: String
    let payment: String
    let amount: Int
}

struct ProductionAppEntryView: View {
    @StateObject private var store = DemoAppStore()

    var body: some View {
        Group {
            if store.signedIn {
                ProductionRootView()
            } else {
                ProductionLoginView()
            }
        }
        .environmentObject(store)
        .animation(.easeInOut(duration: 0.25), value: store.signedIn)
    }
}

// MARK: - Login

struct ProductionLoginView: View {
    @EnvironmentObject private var store: DemoAppStore
    @State private var login = ""
    @State private var password = ""
    @State private var remember = true

    var body: some View {
        ZStack {
            Color(red: 244/255, green: 248/255, blue: 247/255).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 45)
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(colors: [brandDark, brandGreen], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 104, height: 104)
                        Image(systemName: "display.2").font(.system(size: 42)).foregroundStyle(.white)
                    }
                    Text("CaseonePOS").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(brandDark)
                    Text("MANAGER").font(.caption.bold()).tracking(5).foregroundStyle(brandGreen)
                    Text("Управляйте бизнесом из любого места").foregroundStyle(.secondary)

                    VStack(spacing: 15) {
                        Text("Добро пожаловать!").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Телефон или e-mail", text: $login).textInputAutocapitalization(.never).demoField()
                        SecureField("Пароль", text: $password).demoField()
                        Toggle("Запомнить меня", isOn: $remember).font(.caption)
                        Button("Войти") { store.signedIn = true }
                            .buttonStyle(DemoPrimaryButton())
                        Button { Task { await store.authenticateFaceID() } } label: {
                            Label("Войти с Face ID", systemImage: "faceid").frame(maxWidth: .infinity).padding(14)
                        }
                        .foregroundStyle(brandDark)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(brandDark.opacity(0.2)))
                    }
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
                    .shadow(color: brandDark.opacity(0.08), radius: 22, y: 12)
                }
                .padding(22)
            }
        }
    }
}

// MARK: - Root

struct ProductionRootView: View {
    var body: some View {
        TabView {
            NavigationStack { DemoDashboardView() }
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
        .tint(brandGreen)
    }
}

// MARK: - Dashboard

struct DemoDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Circle().fill(brandGradient).frame(width: 48, height: 48).overlay(Text("ТД").bold().foregroundStyle(.white))
                    VStack(alignment: .leading) {
                        Text("UZBEGIM CAFE").font(.headline)
                        Label("Смена открыта · 08:00", systemImage: "circle.fill").font(.caption).foregroundStyle(brandGreen)
                    }
                    Spacer(); Image(systemName: "bell")
                }.demoCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Оборот сегодня").font(.subheadline.bold())
                    Text("680 000 UZS").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("+12% к предыдущему дню").font(.caption)
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                .padding(22).background(brandGradient, in: RoundedRectangle(cornerRadius: 24))

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    DemoMetric(title: "Продаж", value: "9", icon: "receipt")
                    DemoMetric(title: "Средний чек", value: "75 556 UZS", icon: "sum")
                    DemoMetric(title: "Наличные", value: "600 000 UZS", icon: "banknote")
                    DemoMetric(title: "Карты", value: "80 000 UZS", icon: "creditcard")
                }

                Text("Быстрые действия").font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 12) {
                    NavigationLink { DemoAnalyticsView() } label: { DemoAction(title: "Аналитика", icon: "chart.bar") }
                    NavigationLink { DemoShiftView() } label: { DemoAction(title: "X / Z", icon: "doc.text") }
                    NavigationLink { DemoInventoryView() } label: { DemoAction(title: "Склад", icon: "shippingbox") }
                    NavigationLink { DemoKitchenView() } label: { DemoAction(title: "Кухня", icon: "fork.knife") }
                    NavigationLink { DemoWaitersView() } label: { DemoAction(title: "Сотрудники", icon: "person.2") }
                    NavigationLink { DemoSettingsView() } label: { DemoAction(title: "Настройки", icon: "gearshape") }
                }
            }.padding()
        }
        .background(appBackground).navigationTitle("Главная")
    }
}

// MARK: - Analytics

private struct DemoHour: Identifiable { let id = UUID(); let hour: String; let amount: Double }
private let demoHours = [DemoHour(hour: "08", amount: 45), .init(hour: "10", amount: 85), .init(hour: "12", amount: 150), .init(hour: "14", amount: 210), .init(hour: "16", amount: 120), .init(hour: "18", amount: 70), .init(hour: "20", amount: 160)]

struct DemoAnalyticsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                HStack { Label("21.07.2026 — 21.07.2026", systemImage: "calendar"); Spacer() }.demoCard()
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                    DemoMetric(title: "Продаж", value: "9", icon: "receipt")
                    DemoMetric(title: "Оборот", value: "680 000 UZS", icon: "banknote")
                    DemoMetric(title: "Средний чек", value: "75 556 UZS", icon: "sum")
                    DemoMetric(title: "Сервис", value: "0 UZS", icon: "bell")
                }
                VStack(alignment: .leading) {
                    Text("Оборот по часам").font(.headline)
                    Chart(demoHours) { BarMark(x: .value("Час", $0.hour), y: .value("Сумма", $0.amount)).foregroundStyle(brandGreen).cornerRadius(5) }.frame(height: 220)
                }.demoCard()
                DemoProgress(title: "Наличные", value: "600 000 UZS", progress: 0.88)
                DemoProgress(title: "Uzcard", value: "50 000 UZS", progress: 0.07)
                DemoProgress(title: "Humo", value: "20 000 UZS", progress: 0.03)
                DemoProgress(title: "Visa / Mastercard", value: "10 000 UZS", progress: 0.02)
                NavigationLink("Посмотреть аналитику по официантам") { DemoWaitersView() }.buttonStyle(DemoPrimaryButton())
            }.padding()
        }.background(appBackground).navigationTitle("Аналитика")
    }
}

// MARK: - Shift and reports

struct DemoShiftView: View {
    @EnvironmentObject private var store: DemoAppStore
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(store.shiftOpen ? "Смена открыта" : "Смена закрыта", systemImage: store.shiftOpen ? "lock.open.fill" : "lock.fill").font(.title3.bold())
                    Text("Кассир: Тахиров Далер Хайдарович")
                    Text("Открыта: 21.07.2026 в 08:00").font(.caption).foregroundStyle(.secondary)
                }.foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(brandGradient, in: RoundedRectangle(cornerRadius: 22))
                DemoReportSummary()
                NavigationLink("Сформировать X-отчёт") { DemoReportView(title: "X-отчёт", canClose: false) }.buttonStyle(DemoPrimaryButton())
                NavigationLink("Z-отчёт и закрыть смену") { DemoReportView(title: "Z-отчёт", canClose: true) }.buttonStyle(DemoDangerButton())
            }.padding()
        }.background(appBackground).navigationTitle("Смена")
    }
}

struct DemoReportSummary: View {
    var body: some View {
        VStack(spacing: 12) {
            reportRow("Чеков", "9")
            reportRow("Наличные", "200 000 UZS")
            reportRow("Uzcard", "50 000 UZS")
            reportRow("Humo", "20 000 UZS")
            reportRow("Visa", "7 000 UZS")
            reportRow("Mastercard", "3 000 UZS")
            Divider(); reportRow("Итого оборот", "280 000 UZS", bold: true)
        }.demoCard()
    }
    private func reportRow(_ title: String, _ value: String, bold: Bool = false) -> some View { HStack { Text(title); Spacer(); Text(value).fontWeight(bold ? .bold : .semibold).foregroundStyle(brandDark) } }
}

struct DemoReportView: View {
    @EnvironmentObject private var store: DemoAppStore
    let title: String
    let canClose: Bool
    @State private var showFaceID = false
    var body: some View {
        VStack(spacing: 18) {
            DemoReportSummary()
            Spacer()
            if canClose {
                Button("Закрыть смену") { showFaceID = true }.buttonStyle(DemoPrimaryButton())
            } else {
                ShareLink(item: "CaseonePOS X-отчёт: оборот 280 000 UZS") { Label("Поделиться", systemImage: "square.and.arrow.up") }.buttonStyle(DemoPrimaryButton())
            }
        }.padding().background(appBackground).navigationTitle(title).sheet(isPresented: $showFaceID) {
            VStack(spacing: 24) {
                Spacer(); Image(systemName: "faceid").font(.system(size: 76)).foregroundStyle(brandGreen)
                Text("Подтвердите закрытие смены").font(.title2.bold()).multilineTextAlignment(.center)
                Button("Подтвердить") { store.shiftOpen = false; showFaceID = false }.buttonStyle(DemoPrimaryButton())
                Button("Отмена") { showFaceID = false }.padding(); Spacer()
            }.padding(24).presentationDetents([.medium])
        }
    }
}

// MARK: - Receipts

struct DemoReceiptsView: View {
    @EnvironmentObject private var store: DemoAppStore
    @State private var search = ""
    var filtered: [DemoReceipt] { search.isEmpty ? store.receipts : store.receipts.filter { $0.number.contains(search) || $0.table.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List(filtered) { receipt in
            NavigationLink(value: receipt) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(receipt.number).bold(); Spacer(); Text(receipt.amount.uzsDemo).bold().foregroundStyle(brandDark) }
                    Text(receipt.table).font(.subheadline)
                    HStack { Text(receipt.date); Spacer(); Text(receipt.payment) }.font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 7)
            }
        }.searchable(text: $search, prompt: "Номер чека или стол").navigationDestination(for: DemoReceipt.self) { DemoReceiptDetailView(receipt: $0) }.navigationTitle("История чеков")
    }
}

struct DemoReceiptDetailView: View {
    let receipt: DemoReceipt
    @State private var showRefund = false
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    detailRow("Дата", receipt.date); detailRow("Официант", receipt.waiter); detailRow("Зал / Стол", receipt.table); detailRow("Оплата", receipt.payment)
                }.demoCard()
                VStack(spacing: 12) {
                    detailRow("Плов", "50 000 UZS"); detailRow("Шашлык из баранины", "60 000 UZS"); detailRow("Салат Ачичук", "15 000 UZS"); detailRow("Чай зелёный", "5 000 UZS"); Divider(); detailRow("Сервис", "20 000 UZS"); detailRow("Итого", receipt.amount.uzsDemo, bold: true)
                }.demoCard()
                Button("Возврат чека") { showRefund = true }.buttonStyle(DemoDangerButton())
            }.padding()
        }.background(appBackground).navigationTitle("Чек \(receipt.number)").alert("Оформить возврат?", isPresented: $showRefund) { Button("Отмена", role: .cancel) {}; Button("Вернуть", role: .destructive) {} } message: { Text("Демонстрационный возврат без изменения данных") }
    }
    private func detailRow(_ a: String, _ b: String, bold: Bool = false) -> some View { HStack(alignment: .top) { Text(a); Spacer(); Text(b).fontWeight(bold ? .bold : .regular).multilineTextAlignment(.trailing) } }
}

// MARK: - Inventory, kitchen, waiters, more

struct DemoInventoryView: View {
    let items = [("Coca-Cola 1L", "24 шт", false), ("Pepsi 1L", "12 шт", false), ("Fanta 1L", "3 шт", true), ("Минеральная вода", "52 шт", false), ("Red Bull 0.25L", "2 шт", true)]
    var body: some View { List(items, id: \.0) { item in HStack { Image(systemName: "shippingbox.fill").foregroundStyle(item.2 ? .orange : brandGreen); VStack(alignment: .leading) { Text(item.0).bold(); Text(item.2 ? "Низкий остаток" : "В наличии").font(.caption).foregroundStyle(item.2 ? .orange : .secondary) }; Spacer(); Text(item.1).bold() } }.navigationTitle("Склад") }
}

struct DemoKitchenView: View {
    let items = [("Плов",45,0.75),("Шашлык из баранины",32,0.55),("Лагман",24,0.40),("Манты",18,0.30),("Салат Ачичук",16,0.26)]
    var body: some View { List(items, id: \.0) { item in VStack(alignment: .leading, spacing: 8) { HStack { Text(item.0).bold(); Spacer(); Text("Продано: \(item.1)") }; ProgressView(value: item.2).tint(brandGreen) }.padding(.vertical, 7) }.navigationTitle("Кухня") }
}

struct DemoWaitersView: View {
    let staff = [("Тахиров Далер", "510 000 UZS", 0.75), ("System Admin", "170 000 UZS", 0.25), ("Исломов Бехруз", "80 000 UZS", 0.12), ("Каримова Дилноза", "60 000 UZS", 0.09)]
    var body: some View { List(staff, id: \.0) { item in VStack(alignment: .leading, spacing: 8) { HStack { Text(item.0).bold(); Spacer(); Text(item.1).foregroundStyle(brandDark).bold() }; ProgressView(value: item.2).tint(brandGreen) }.padding(.vertical, 8) }.navigationTitle("По официантам") }
}

struct DemoMoreView: View {
    @EnvironmentObject private var store: DemoAppStore
    var body: some View {
        List {
            Section { HStack { Circle().fill(brandGradient).frame(width: 52, height: 52).overlay(Text("ТД").bold().foregroundStyle(.white)); VStack(alignment: .leading) { Text("Тахиров Далер").bold(); Text("Системный администратор").font(.caption); Text("UZBEGIM CAFE").font(.caption).foregroundStyle(.secondary) } } }
            Section("Управление") {
                NavigationLink("Организация") { DemoSimpleInfo(title: "Организация") }
                NavigationLink("Сотрудники") { DemoWaitersView() }
                NavigationLink("Склад") { DemoInventoryView() }
                NavigationLink("Кухня") { DemoKitchenView() }
                NavigationLink("Уведомления") { DemoSimpleInfo(title: "Уведомления") }
                NavigationLink("Настройки") { DemoSettingsView() }
            }
            Section { Button("Выйти", role: .destructive) { store.signedIn = false } }
        }.navigationTitle("Ещё")
    }
}

struct DemoSettingsView: View {
    @State private var faceID = true; @State private var alerts = true; @State private var lowStock = true
    var body: some View { Form { Section("Безопасность") { Toggle("Использовать Face ID", isOn: $faceID); Label("PIN для закрытия смены", systemImage: "lock") }; Section("Уведомления") { Toggle("Продажи и смены", isOn: $alerts); Toggle("Низкие остатки", isOn: $lowStock) }; Section("Приложение") { LabeledContent("Версия", value: "1.0.0"); LabeledContent("Режим", value: "Демо") } }.navigationTitle("Настройки") }
}

struct DemoSimpleInfo: View { let title: String; var body: some View { ContentUnavailableView(title, systemImage: "checkmark.circle.fill", description: Text("Раздел готов к подключению реальных данных CaseonePOS")) } }

// MARK: - Shared UI

private let brandGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let brandDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let appBackground = Color(red: 244/255, green: 248/255, blue: 247/255)
private let brandGradient = LinearGradient(colors: [brandDark, brandGreen], startPoint: .topLeading, endPoint: .bottomTrailing)

struct DemoMetric: View { let title: String; let value: String; let icon: String; var body: some View { VStack(spacing: 8) { Image(systemName: icon).foregroundStyle(brandGreen); Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 95).demoCard() } }
struct DemoAction: View { let title: String; let icon: String; var body: some View { VStack(spacing: 9) { Image(systemName: icon).font(.title3).foregroundStyle(brandGreen); Text(title).font(.caption.bold()).foregroundStyle(.primary) }.frame(maxWidth: .infinity, minHeight: 78).demoCard() } }
struct DemoProgress: View { let title: String; let value: String; let progress: Double; var body: some View { VStack(alignment: .leading, spacing: 8) { HStack { Text(title).bold(); Spacer(); Text(value).foregroundStyle(brandDark).bold() }; ProgressView(value: progress).tint(brandGreen) }.demoCard() } }

struct DemoPrimaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.fontWeight(.bold).foregroundStyle(.white).frame(maxWidth: .infinity).padding(15).background(brandGradient.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 14)) } }
struct DemoDangerButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.fontWeight(.bold).foregroundStyle(.white).frame(maxWidth: .infinity).padding(15).background(Color.red.opacity(configuration.isPressed ? 0.75 : 0.9), in: RoundedRectangle(cornerRadius: 14)) } }

extension View {
    fileprivate func demoCard() -> some View { self.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18)).shadow(color: brandDark.opacity(0.05), radius: 10, y: 5) }
    fileprivate func demoField() -> some View { self.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08))) }
}
extension Int { fileprivate var uzsDemo: String { NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal).replacingOccurrences(of: ",", with: " ") + " UZS" } }
