import SwiftUI
import UIKit

private let receiptGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let receiptDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let receiptBackground = Color(red: 244/255, green: 248/255, blue: 247/255)

struct POSReceiptItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let quantity: Int
    let price: Int
    var total: Int { quantity * price }
}

struct POSReceipt: Identifiable, Hashable {
    enum Status: String, CaseIterable { case paid = "Оплачен", refunded = "Возврат", cancelled = "Отменён" }
    let id = UUID()
    let number: String
    let time: String
    let cashier: String
    let waiter: String
    let table: String
    let guests: Int
    let payment: String
    let status: Status
    let items: [POSReceiptItem]
    let discount: Int
    let service: Int
    var subtotal: Int { items.reduce(0) { $0 + $1.total } }
    var total: Int { subtotal - discount + service }
}

private let demoReceipts: [POSReceipt] = [
    POSReceipt(number: "#10482", time: "12:48", cashier: "Далер", waiter: "Азиз", table: "Стол 7", guests: 4, payment: "Uzcard", status: .paid, items: [POSReceiptItem(name: "Плов", quantity: 2, price: 50_000), POSReceiptItem(name: "Ачичук", quantity: 1, price: 20_000), POSReceiptItem(name: "Чай", quantity: 2, price: 10_000)], discount: 0, service: 14_000),
    POSReceipt(number: "#10481", time: "12:31", cashier: "Далер", waiter: "Шохрух", table: "VIP 2", guests: 6, payment: "Наличные", status: .paid, items: [POSReceiptItem(name: "Шашлык", quantity: 8, price: 22_000), POSReceiptItem(name: "Салат", quantity: 2, price: 35_000)], discount: 15_000, service: 23_100),
    POSReceipt(number: "#10480", time: "12:09", cashier: "Далер", waiter: "Азиз", table: "Стол 3", guests: 2, payment: "Humo", status: .refunded, items: [POSReceiptItem(name: "Капучино", quantity: 2, price: 28_000)], discount: 0, service: 0),
    POSReceipt(number: "#10479", time: "11:52", cashier: "Далер", waiter: "Малика", table: "Доставка", guests: 1, payment: "CLICK", status: .paid, items: [POSReceiptItem(name: "Пицца", quantity: 1, price: 95_000), POSReceiptItem(name: "Pepsi", quantity: 2, price: 15_000)], discount: 5_000, service: 0)
]

struct ReceiptsPremiumView: View {
    @State private var search = ""
    @State private var status: POSReceipt.Status?
    @State private var payment = "Все"

    private var filtered: [POSReceipt] {
        demoReceipts.filter { receipt in
            let matchesSearch = search.isEmpty || receipt.number.localizedCaseInsensitiveContains(search) || receipt.waiter.localizedCaseInsensitiveContains(search) || receipt.table.localizedCaseInsensitiveContains(search)
            let matchesStatus = status == nil || receipt.status == status
            let matchesPayment = payment == "Все" || receipt.payment == payment
            return matchesSearch && matchesStatus && matchesPayment
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summary
                filters
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { receipt in
                        NavigationLink { ReceiptDetailView(receipt: receipt) } label: { ReceiptRow(receipt: receipt) }
                            .buttonStyle(.plain)
                    }
                }
            }.padding()
        }
        .background(receiptBackground)
        .navigationTitle("Чеки")
        .searchable(text: $search, prompt: "Номер, официант или стол")
    }

    private var summary: some View {
        HStack(spacing: 12) {
            ReceiptMetric(title: "Чеков", value: "128", icon: "doc.text.fill")
            ReceiptMetric(title: "Средний чек", value: "86 400", icon: "sum")
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            Picker("Статус", selection: $status) {
                Text("Все").tag(POSReceipt.Status?.none)
                ForEach(POSReceipt.Status.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
            }.pickerStyle(.segmented)
            Picker("Оплата", selection: $payment) {
                ForEach(["Все", "Наличные", "Uzcard", "Humo", "CLICK"], id: \.self, content: Text.init)
            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ReceiptMetric: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(receiptGreen)
            Text(value).font(.title3.bold()).foregroundStyle(receiptDark)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ReceiptRow: View {
    let receipt: POSReceipt
    private var statusColor: Color { receipt.status == .paid ? receiptGreen : receipt.status == .refunded ? .orange : .red }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(receipt.number).font(.headline).foregroundStyle(receiptDark)
                    Text("\(receipt.time) • \(receipt.table) • \(receipt.waiter)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(receipt.status.rawValue).font(.caption.bold()).foregroundStyle(statusColor).padding(.horizontal, 9).padding(.vertical, 5).background(statusColor.opacity(0.12), in: Capsule())
            }
            Divider()
            HStack {
                Label(receipt.payment, systemImage: "creditcard.fill").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(receipt.total.formatted()) сум").font(.headline).foregroundStyle(receiptDark)
            }
        }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ReceiptDetailView: View {
    let receipt: POSReceipt
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showRefund = false
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                itemsCard
                totalsCard
                detailsCard
                actionButtons
                if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(receiptGreen).padding() }
            }.padding()
        }
        .background(receiptBackground)
        .navigationTitle(receipt.number)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { if let shareURL { ReceiptShareSheet(items: [shareURL]) } }
        .sheet(isPresented: $showRefund) { RefundReceiptView(receipt: receipt) { message = $0 } }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: receipt.status == .paid ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill").font(.system(size: 44)).foregroundStyle(receipt.status == .paid ? receiptGreen : .orange)
            Text(receipt.status.rawValue).font(.title3.bold())
            Text("\(receipt.time) • \(receipt.payment)").foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var itemsCard: some View {
        VStack(spacing: 12) {
            ForEach(receipt.items) { item in
                HStack(alignment: .top) {
                    Text("\(item.quantity)×").foregroundStyle(.secondary).frame(width: 30, alignment: .leading)
                    Text(item.name)
                    Spacer()
                    Text("\(item.total.formatted())")
                }.font(.subheadline)
            }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var totalsCard: some View {
        VStack(spacing: 10) {
            totalLine("Подытог", receipt.subtotal)
            totalLine("Скидка", -receipt.discount)
            totalLine("Сервис", receipt.service)
            Divider()
            HStack { Text("Итого").font(.headline); Spacer(); Text("\(receipt.total.formatted()) сум").font(.title3.bold()).foregroundStyle(receiptDark) }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func totalLine(_ title: String, _ value: Int) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text("\(value.formatted()) сум") }.font(.subheadline)
    }

    private var detailsCard: some View {
        VStack(spacing: 10) {
            detail("Кассир", receipt.cashier); detail("Официант", receipt.waiter); detail("Стол", receipt.table); detail("Гостей", "\(receipt.guests)")
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.medium) }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { exportPDF() } label: { Label("PDF", systemImage: "square.and.arrow.up") }.buttonStyle(ReceiptActionStyle())
                Button { printReceipt() } label: { Label("Печать", systemImage: "printer.fill") }.buttonStyle(ReceiptActionStyle())
            }
            if receipt.status == .paid {
                Button { showRefund = true } label: { Label("Оформить возврат", systemImage: "arrow.uturn.backward") .frame(maxWidth: .infinity).padding(14) }
                    .foregroundStyle(.red).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
            }
        }
    }

    private func exportPDF() {
        shareURL = ReceiptPDF.make(receipt: receipt)
        showShare = shareURL != nil
    }

    private func printReceipt() {
        guard let url = ReceiptPDF.make(receipt: receipt), let data = try? Data(contentsOf: url) else { return }
        let controller = UIPrintInteractionController.shared
        controller.printingItem = data
        controller.present(animated: true)
    }
}

private struct ReceiptActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.fontWeight(.semibold).frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(receiptGreen.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 15))
    }
}

struct RefundReceiptView: View {
    let receipt: POSReceipt
    let completion: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Ошибка заказа"
    @State private var fullRefund = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Возврат") {
                    Toggle("Вернуть весь чек", isOn: $fullRefund)
                    Picker("Причина", selection: $reason) {
                        ForEach(["Ошибка заказа", "Отказ гостя", "Ошибка оплаты", "Другое"], id: \.self, content: Text.init)
                    }
                    LabeledContent("Сумма", value: "\(receipt.total.formatted()) сум")
                }
                Section { Text("Операция будет записана в журнал действий. В рабочей версии потребуется подтверждение Face ID или PIN.").font(.footnote) }
            }
            .navigationTitle("Возврат")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Подтвердить") { completion("Возврат \(receipt.number) оформлен: \(reason)"); dismiss() }.fontWeight(.bold) }
            }
        }
    }
}

private enum ReceiptPDF {
    static func make(receipt: POSReceipt) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(receipt.number.replacingOccurrences(of: "#", with: "")) .pdf")
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var lines = ["CaseonePOS", "Чек \(receipt.number)", "Время: \(receipt.time)", "Кассир: \(receipt.cashier)", "Официант: \(receipt.waiter)", "Стол: \(receipt.table)", ""]
                lines += receipt.items.map { "\($0.quantity) × \($0.name) — \($0.total.formatted()) сум" }
                lines += ["", "Подытог: \(receipt.subtotal.formatted()) сум", "Скидка: \(receipt.discount.formatted()) сум", "Сервис: \(receipt.service.formatted()) сум", "ИТОГО: \(receipt.total.formatted()) сум", "Оплата: \(receipt.payment)"]
                let text = lines.joined(separator: "\n") as NSString
                text.draw(in: CGRect(x: 44, y: 44, width: 507, height: 754), withAttributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.black])
            }
            return url
        } catch { return nil }
    }
}

private struct ReceiptShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
