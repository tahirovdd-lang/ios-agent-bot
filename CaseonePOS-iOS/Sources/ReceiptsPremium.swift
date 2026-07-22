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

private let premiumDemoReceipts: [POSReceipt] = [
    POSReceipt(number: "#10482", time: "12:48", cashier: "Далер", waiter: "Азиз", table: "Стол 7", guests: 4, payment: "Uzcard", status: .paid, items: [POSReceiptItem(name: "Плов", quantity: 2, price: 50_000), POSReceiptItem(name: "Ачичук", quantity: 1, price: 20_000)], discount: 0, service: 12_000),
    POSReceipt(number: "#10481", time: "12:31", cashier: "Далер", waiter: "Шохрух", table: "VIP 2", guests: 6, payment: "Наличные", status: .paid, items: [POSReceiptItem(name: "Шашлык", quantity: 8, price: 22_000)], discount: 10_000, service: 16_600),
    POSReceipt(number: "#10480", time: "12:09", cashier: "Далер", waiter: "Азиз", table: "Стол 3", guests: 2, payment: "Humo", status: .refunded, items: [POSReceiptItem(name: "Капучино", quantity: 2, price: 28_000)], discount: 0, service: 0)
]

struct ReceiptsPremiumView: View {
    @State private var search = ""
    @State private var selectedStatus: POSReceipt.Status?
    @State private var payment = "Все"

    private var filtered: [POSReceipt] {
        premiumDemoReceipts.filter {
            (search.isEmpty || $0.number.localizedCaseInsensitiveContains(search) || $0.waiter.localizedCaseInsensitiveContains(search) || $0.table.localizedCaseInsensitiveContains(search)) &&
            (selectedStatus == nil || $0.status == selectedStatus) &&
            (payment == "Все" || $0.payment == payment)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    metric("Чеков", "128", "doc.text.fill")
                    metric("Средний чек", "86 400", "sum")
                }
                VStack(spacing: 10) {
                    Picker("Статус", selection: $selectedStatus) {
                        Text("Все").tag(Optional<POSReceipt.Status>.none)
                        ForEach(POSReceipt.Status.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(Optional(value))
                        }
                    }.pickerStyle(.segmented)
                    Picker("Оплата", selection: $payment) {
                        ForEach(["Все", "Наличные", "Uzcard", "Humo", "CLICK"], id: \.self) { Text($0) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))

                LazyVStack(spacing: 12) {
                    ForEach(filtered) { receipt in
                        NavigationLink { ReceiptDetailView(receipt: receipt) } label: { PremiumReceiptRow(receipt: receipt) }
                            .buttonStyle(.plain)
                    }
                }
            }.padding()
        }
        .background(receiptBackground)
        .navigationTitle("Чеки")
        .searchable(text: $search, prompt: "Номер, официант или стол")
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(receiptGreen)
            Text(value).font(.title3.bold()).foregroundStyle(receiptDark)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PremiumReceiptRow: View {
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
            HStack { Label(receipt.payment, systemImage: "creditcard.fill").font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(receipt.total.formatted()) сум").font(.headline).foregroundStyle(receiptDark) }
        }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ReceiptDetailView: View {
    let receipt: POSReceipt
    @State private var showShare = false
    @State private var showRefund = false
    @State private var shareURL: URL?
    @State private var notice = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: receipt.status == .paid ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill").font(.system(size: 44)).foregroundStyle(receipt.status == .paid ? receiptGreen : .orange)
                    Text(receipt.status.rawValue).font(.title3.bold())
                    Text("\(receipt.time) • \(receipt.payment)").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 12) {
                    ForEach(receipt.items) { item in
                        HStack { Text("\(item.quantity)×").foregroundStyle(.secondary); Text(item.name); Spacer(); Text("\(item.total.formatted())") }
                    }
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))

                VStack(spacing: 10) {
                    line("Подытог", receipt.subtotal); line("Скидка", -receipt.discount); line("Сервис", receipt.service); Divider()
                    HStack { Text("Итого").font(.headline); Spacer(); Text("\(receipt.total.formatted()) сум").font(.title3.bold()).foregroundStyle(receiptDark) }
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 10) {
                    Button { exportPDF() } label: { Label("PDF", systemImage: "square.and.arrow.up") }.buttonStyle(PremiumReceiptActionStyle())
                    Button { printReceipt() } label: { Label("Печать", systemImage: "printer.fill") }.buttonStyle(PremiumReceiptActionStyle())
                }
                if receipt.status == .paid {
                    Button { showRefund = true } label: { Label("Оформить возврат", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity).padding(14) }
                        .foregroundStyle(.red).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                }
                if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(receiptGreen) }
            }.padding()
        }
        .background(receiptBackground)
        .navigationTitle(receipt.number)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { if let shareURL { PremiumReceiptShareSheet(items: [shareURL]) } }
        .sheet(isPresented: $showRefund) { RefundReceiptView(receipt: receipt) { notice = $0 } }
    }

    private func line(_ title: String, _ value: Int) -> some View { HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text("\(value.formatted()) сум") }.font(.subheadline) }
    private func exportPDF() { shareURL = PremiumReceiptPDF.make(receipt: receipt); showShare = shareURL != nil }
    private func printReceipt() {
        guard let url = PremiumReceiptPDF.make(receipt: receipt), let data = try? Data(contentsOf: url) else { return }
        let controller = UIPrintInteractionController.shared; controller.printingItem = data; controller.present(animated: true)
    }
}

private struct PremiumReceiptActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.fontWeight(.semibold).frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(receiptGreen.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 15)) }
}

struct RefundReceiptView: View {
    let receipt: POSReceipt
    let completion: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Ошибка заказа"
    var body: some View {
        NavigationStack {
            Form {
                Picker("Причина", selection: $reason) { ForEach(["Ошибка заказа", "Отказ гостя", "Ошибка оплаты", "Другое"], id: \.self) { Text($0) } }
                LabeledContent("Сумма", value: "\(receipt.total.formatted()) сум")
            }
            .navigationTitle("Возврат")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Подтвердить") { completion("Возврат \(receipt.number) оформлен: \(reason)"); dismiss() } }
            }
        }
    }
}

private enum PremiumReceiptPDF {
    static func make(receipt: POSReceipt) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(receipt.number.replacingOccurrences(of: "#", with: "")).pdf")
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var lines = ["CaseonePOS", "Чек \(receipt.number)", "Кассир: \(receipt.cashier)", "Официант: \(receipt.waiter)", ""]
                lines += receipt.items.map { "\($0.quantity) × \($0.name) — \($0.total.formatted()) сум" }
                lines += ["", "ИТОГО: \(receipt.total.formatted()) сум", "Оплата: \(receipt.payment)"]
                (lines.joined(separator: "\n") as NSString).draw(in: CGRect(x: 44, y: 44, width: 507, height: 754), withAttributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.black])
            }
            return url
        } catch { return nil }
    }
}

private struct PremiumReceiptShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
