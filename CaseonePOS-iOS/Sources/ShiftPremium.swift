import SwiftUI
import LocalAuthentication
import UIKit

private let shiftGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let shiftDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let shiftBackground = Color(red: 244/255, green: 248/255, blue: 247/255)
private let shiftGradient = LinearGradient(colors: [shiftDark, shiftGreen], startPoint: .topLeading, endPoint: .bottomTrailing)

struct ShiftPayment: Identifiable {
    let id = UUID()
    let name: String
    let amount: Int
    let icon: String
}

struct ClosedShift: Identifiable, Hashable {
    let id = UUID()
    let number: String
    let date: String
    let cashier: String
    let turnover: Int
    let checks: Int
}

struct ShiftPremiumView: View {
    @EnvironmentObject private var store: DemoAppStore
    @State private var showHistory = false

    private let payments = [
        ShiftPayment(name: "Наличные", amount: 420_000, icon: "banknote.fill"),
        ShiftPayment(name: "Uzcard", amount: 110_000, icon: "creditcard.fill"),
        ShiftPayment(name: "Humo", amount: 65_000, icon: "creditcard.fill"),
        ShiftPayment(name: "Visa", amount: 35_000, icon: "v.circle.fill"),
        ShiftPayment(name: "Mastercard", amount: 20_000, icon: "m.circle.fill"),
        ShiftPayment(name: "CLICK", amount: 18_000, icon: "iphone"),
        ShiftPayment(name: "Payme", amount: 12_000, icon: "iphone")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                currentShiftCard
                financialSummary
                paymentsCard

                HStack(spacing: 12) {
                    NavigationLink { ShiftReportView(kind: .x) } label: {
                        ShiftActionCard(title: "X-отчёт", subtitle: "Без закрытия", icon: "doc.text.magnifyingglass")
                    }
                    NavigationLink { ShiftReportView(kind: .z) } label: {
                        ShiftActionCard(title: "Z-отчёт", subtitle: "Закрыть смену", icon: "lock.fill", danger: true)
                    }
                }

                Button { showHistory = true } label: {
                    Label("История смен", systemImage: "clock.arrow.circlepath")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(15)
                }
                .foregroundStyle(shiftDark)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .background(shiftBackground)
        .navigationTitle("Смена")
        .sheet(isPresented: $showHistory) { NavigationStack { ShiftHistoryView() } }
    }

    private var currentShiftCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Label(store.shiftOpen ? "Смена открыта" : "Смена закрыта", systemImage: store.shiftOpen ? "lock.open.fill" : "lock.fill")
                        .font(.title3.bold())
                    Text("Смена №1842").font(.caption).opacity(0.8)
                }
                Spacer()
                Circle().fill(.white.opacity(0.18)).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "person.crop.circle.fill").font(.title2))
            }
            Divider().overlay(.white.opacity(0.3))
            HStack {
                info("Кассир", "Тахиров Далер")
                Spacer()
                info("Открыта", "08:00")
                Spacer()
                info("Длительность", "5 ч 42 мин")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(shiftGradient, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: shiftDark.opacity(0.18), radius: 16, y: 8)
    }

    private var financialSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Финансовая сводка").font(.headline)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                ShiftMetric(title: "Оборот", value: "680 000 UZS", icon: "chart.line.uptrend.xyaxis")
                ShiftMetric(title: "Чеков", value: "9", icon: "receipt")
                ShiftMetric(title: "Средний чек", value: "75 556 UZS", icon: "sum")
                ShiftMetric(title: "Возвраты", value: "15 000 UZS", icon: "arrow.uturn.backward")
                ShiftMetric(title: "Скидки", value: "8 000 UZS", icon: "percent")
                ShiftMetric(title: "Сервис", value: "20 000 UZS", icon: "bell.fill")
            }
        }
    }

    private var paymentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Оплаты").font(.headline)
            ForEach(payments) { payment in
                HStack(spacing: 12) {
                    Image(systemName: payment.icon).frame(width: 30, height: 30).foregroundStyle(shiftGreen)
                    Text(payment.name)
                    Spacer()
                    Text(payment.amount.shiftUZS).fontWeight(.semibold).foregroundStyle(shiftDark)
                }
                if payment.id != payments.last?.id { Divider() }
            }
        }
        .shiftCard()
    }

    private func info(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).opacity(0.75)
            Text(value).font(.caption.bold())
        }
    }
}

enum ShiftReportKind { case x, z }

struct ShiftReportView: View {
    @EnvironmentObject private var store: DemoAppStore
    @Environment(\.dismiss) private var dismiss
    let kind: ShiftReportKind
    @State private var pin = ""
    @State private var showCloseSheet = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var pdfURL: URL?

    private var title: String { kind == .x ? "X-отчёт" : "Z-отчёт" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                reportHeader
                reportSection("Продажи", rows: [("Количество чеков", "9"), ("Оборот", "680 000 UZS"), ("Средний чек", "75 556 UZS"), ("Возвраты", "15 000 UZS"), ("Скидки", "8 000 UZS")])
                reportSection("Оплаты", rows: [("Наличные", "420 000 UZS"), ("Uzcard", "110 000 UZS"), ("Humo", "65 000 UZS"), ("Visa", "35 000 UZS"), ("Mastercard", "20 000 UZS"), ("CLICK", "18 000 UZS"), ("Payme", "12 000 UZS")])
                reportSection("Касса", rows: [("Внесения", "0 UZS"), ("Изъятия", "0 UZS"), ("Расчётный остаток", "420 000 UZS")])

                Button { exportPDF() } label: {
                    Label("Создать PDF", systemImage: "doc.richtext.fill")
                        .frame(maxWidth: .infinity).padding(15)
                }
                .buttonStyle(.borderedProminent).tint(shiftGreen)

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Поделиться отчётом", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.bordered)
                }

                Button { message = "Отчёт отправлен на печать (демо)"; showMessage = true } label: {
                    Label("Печать", systemImage: "printer.fill").frame(maxWidth: .infinity).padding(15)
                }.buttonStyle(.bordered)

                if kind == .z {
                    Button { showCloseSheet = true } label: {
                        Label("Закрыть смену", systemImage: "lock.fill").frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                }
            }.padding()
        }
        .background(shiftBackground)
        .navigationTitle(title)
        .sheet(isPresented: $showCloseSheet) { closeSheet }
        .alert("CaseonePOS", isPresented: $showMessage) { Button("OK") {} } message: { Text(message) }
    }

    private var reportHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: kind == .x ? "doc.text.magnifyingglass" : "doc.text.fill").font(.system(size: 42)).foregroundStyle(shiftGreen)
            Text(title).font(.title2.bold())
            Text("Смена №1842 · 21.07.2026").foregroundStyle(.secondary)
            Text(kind == .x ? "Промежуточный отчёт без закрытия смены" : "Итоговый отчёт перед закрытием смены").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).shiftCard()
    }

    private func reportSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack { Text(row.0); Spacer(); Text(row.1).fontWeight(.semibold).foregroundStyle(shiftDark) }
                if index < rows.count - 1 { Divider() }
            }
        }.shiftCard()
    }

    private var closeSheet: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "faceid").font(.system(size: 70)).foregroundStyle(shiftGreen)
                Text("Подтвердите закрытие смены").font(.title2.bold()).multilineTextAlignment(.center)
                Button("Подтвердить через Face ID") { Task { await closeWithBiometrics() } }
                    .buttonStyle(.borderedProminent).tint(shiftGreen)
                Text("или введите PIN").foregroundStyle(.secondary)
                SecureField("PIN", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Button("Закрыть по PIN") {
                    if pin == "1234" { completeClose() } else { message = "Неверный PIN"; showMessage = true }
                }.buttonStyle(.bordered)
                Spacer()
            }.padding().navigationTitle("Подтверждение")
        }
    }

    @MainActor private func closeWithBiometrics() async {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error),
           (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Закрытие смены CaseonePOS")) == true {
            completeClose()
        } else {
            message = "Не удалось подтвердить личность. Используйте PIN 1234."
            showMessage = true
        }
    }

    private func completeClose() {
        store.shiftOpen = false
        showCloseSheet = false
        message = "Смена №1842 успешно закрыта. Z-отчёт сохранён."
        showMessage = true
    }

    private func exportPDF() {
        let formatter = UIGraphicsPDFRendererFormat()
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: formatter)
        let data = renderer.pdfData { context in
            context.beginPage()
            let text = """
            CASEONEPOS — \(title)
            Смена №1842 · 21.07.2026

            Чеков: 9
            Оборот: 680 000 UZS
            Наличные: 420 000 UZS
            Uzcard: 110 000 UZS
            Humo: 65 000 UZS
            Visa: 35 000 UZS
            Mastercard: 20 000 UZS
            CLICK: 18 000 UZS
            Payme: 12 000 UZS
            Возвраты: 15 000 UZS
            """
            text.draw(in: CGRect(x: 45, y: 55, width: 505, height: 700), withAttributes: [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.black])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CaseonePOS-\(title).pdf")
        try? data.write(to: url)
        pdfURL = url
        message = "PDF создан и готов к отправке"
        showMessage = true
    }
}

struct ShiftHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private let shifts = [
        ClosedShift(number: "№1841", date: "20.07.2026 · 08:00–23:10", cashier: "Тахиров Далер", turnover: 1_480_000, checks: 24),
        ClosedShift(number: "№1840", date: "19.07.2026 · 08:00–22:45", cashier: "System Admin", turnover: 1_210_000, checks: 19),
        ClosedShift(number: "№1839", date: "18.07.2026 · 08:00–23:30", cashier: "Исломов Бехруз", turnover: 1_670_000, checks: 27)
    ]

    var filtered: [ClosedShift] { search.isEmpty ? shifts : shifts.filter { $0.number.contains(search) || $0.cashier.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        List(filtered) { shift in
            NavigationLink {
                VStack(spacing: 16) {
                    reportRow("Смена", shift.number); reportRow("Период", shift.date); reportRow("Кассир", shift.cashier); reportRow("Чеков", "\(shift.checks)"); reportRow("Оборот", shift.turnover.shiftUZS)
                    ShareLink(item: "CaseonePOS Z-отчёт \(shift.number): \(shift.turnover.shiftUZS)") { Label("Поделиться", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent).tint(shiftGreen)
                    Spacer()
                }.padding().navigationTitle(shift.number)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(shift.number).bold(); Spacer(); Text(shift.turnover.shiftUZS).bold().foregroundStyle(shiftDark) }
                    Text(shift.date).font(.caption).foregroundStyle(.secondary)
                    Text("\(shift.cashier) · \(shift.checks) чеков").font(.caption)
                }.padding(.vertical, 6)
            }
        }
        .searchable(text: $search, prompt: "Номер смены или кассир")
        .navigationTitle("История смен")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
    }

    private func reportRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
            .padding().background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ShiftMetric: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(shiftGreen)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(shiftDark).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).shiftCard()
    }
}

private struct ShiftActionCard: View {
    let title: String; let subtitle: String; let icon: String; var danger = false
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).opacity(0.8)
        }
        .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 120)
        .background(danger ? LinearGradient(colors: [.red.opacity(0.9), .orange], startPoint: .topLeading, endPoint: .bottomTrailing) : shiftGradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

private extension View {
    func shiftCard() -> some View { padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18)).shadow(color: shiftDark.opacity(0.05), radius: 10, y: 5) }
}

private extension Int {
    var shiftUZS: String { NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal).replacingOccurrences(of: ",", with: " ") + " UZS" }
}
