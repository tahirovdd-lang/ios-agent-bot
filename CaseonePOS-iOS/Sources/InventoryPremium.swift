import SwiftUI
import LocalAuthentication

private let inventoryGreen = Color(red: 6/255, green: 133/255, blue: 98/255)
private let inventoryDark = Color(red: 1/255, green: 63/255, blue: 74/255)
private let inventoryBackground = Color(red: 244/255, green: 248/255, blue: 247/255)

struct InventoryProduct: Identifiable, Hashable {
    enum StockState: Int, Comparable {
        case out = 0, critical = 1, low = 2, normal = 3
        static func < (lhs: StockState, rhs: StockState) -> Bool { lhs.rawValue < rhs.rawValue }
    }
    let id = UUID()
    let name: String
    let category: String
    let sku: String
    let barcode: String
    let unit: String
    let stock: Double
    let minimum: Double
    let cost: Int
    let purchasePrice: Int
    let salePrice: Int
    let supplier: String
    let icon: String

    var state: StockState {
        if stock <= 0 { return .out }
        if stock <= minimum * 0.5 { return .critical }
        if stock <= minimum { return .low }
        return .normal
    }
    var value: Int { Int(stock) * cost }
}

struct InventoryMovement: Identifiable {
    enum Kind: String, CaseIterable { case income = "Приход", expense = "Расход", writeOff = "Списание", transfer = "Перемещение", correction = "Корректировка" }
    let id = UUID()
    let product: String
    let kind: Kind
    let amount: String
    let date: String
    let employee: String
}

private let inventoryProducts = [
    InventoryProduct(name: "Кофе зерновой", category: "Бар", sku: "BAR-001", barcode: "4780012345678", unit: "кг", stock: 12, minimum: 5, cost: 180_000, purchasePrice: 185_000, salePrice: 260_000, supplier: "Sam Coffee", icon: "cup.and.saucer.fill"),
    InventoryProduct(name: "Молоко 3,2%", category: "Бар", sku: "BAR-014", barcode: "4780098765432", unit: "л", stock: 4, minimum: 8, cost: 13_000, purchasePrice: 14_000, salePrice: 20_000, supplier: "Milk Trade", icon: "waterbottle.fill"),
    InventoryProduct(name: "Говяжья вырезка", category: "Кухня", sku: "KIT-021", barcode: "4780044455551", unit: "кг", stock: 2, minimum: 6, cost: 125_000, purchasePrice: 130_000, salePrice: 220_000, supplier: "Meat Premium", icon: "fork.knife"),
    InventoryProduct(name: "Pepsi 0,5", category: "Напитки", sku: "DRK-008", barcode: "4780001122334", unit: "шт", stock: 0, minimum: 12, cost: 8_000, purchasePrice: 9_000, salePrice: 15_000, supplier: "PepsiCo", icon: "takeoutbag.and.cup.and.straw.fill"),
    InventoryProduct(name: "Рис лазер", category: "Кухня", sku: "KIT-002", barcode: "4780011122233", unit: "кг", stock: 36, minimum: 15, cost: 24_000, purchasePrice: 25_000, salePrice: 40_000, supplier: "Agro Samarkand", icon: "leaf.fill")
]

private let inventoryMovements = [
    InventoryMovement(product: "Кофе зерновой", kind: .income, amount: "+5 кг", date: "Сегодня, 09:15", employee: "Далер"),
    InventoryMovement(product: "Молоко 3,2%", kind: .expense, amount: "−3 л", date: "Сегодня, 11:42", employee: "Азиз"),
    InventoryMovement(product: "Pepsi 0,5", kind: .writeOff, amount: "−4 шт", date: "Вчера, 22:10", employee: "Шохрух")
]

struct InventoryPremiumView: View {
    @State private var search = ""
    @State private var filter: InventoryProduct.StockState?
    @State private var showMovement = false
    @State private var showInventory = false

    private var products: [InventoryProduct] {
        inventoryProducts
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.barcode.contains(search) || $0.sku.localizedCaseInsensitiveContains(search) }
            .filter { filter == nil || $0.state == filter }
            .sorted { $0.state < $1.state }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                alerts
                actions
                filters
                LazyVStack(spacing: 12) {
                    ForEach(products) { product in
                        NavigationLink { InventoryProductDetailView(product: product) } label: { InventoryProductRow(product: product) }
                            .buttonStyle(.plain)
                    }
                }
                movements
            }.padding()
        }
        .background(inventoryBackground)
        .navigationTitle("Склад")
        .searchable(text: $search, prompt: "Название, артикул или штрихкод")
        .sheet(isPresented: $showMovement) { NavigationStack { InventoryMovementForm() } }
        .sheet(isPresented: $showInventory) { NavigationStack { StocktakeView() } }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            InventoryMetric(title: "Стоимость", value: "\(inventoryProducts.reduce(0) { $0 + $1.value }.formatted())", subtitle: "сум", icon: "shippingbox.fill")
            InventoryMetric(title: "SKU", value: "\(inventoryProducts.count)", subtitle: "позиций", icon: "barcode")
        }
    }

    private var alerts: some View {
        HStack(spacing: 12) {
            alertCard("Низкий остаток", inventoryProducts.filter { $0.state == .low || $0.state == .critical }.count, .orange, "exclamationmark.triangle.fill")
            alertCard("Нет в наличии", inventoryProducts.filter { $0.state == .out }.count, .red, "xmark.circle.fill")
        }
    }

    private func alertCard(_ title: String, _ count: Int, _ color: Color, _ icon: String) -> some View {
        HStack { Image(systemName: icon); VStack(alignment: .leading) { Text("\(count)").font(.title3.bold()); Text(title).font(.caption) } }
            .foregroundStyle(color).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button { showMovement = true } label: { Label("Движение", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity).padding(14) }
            Button { showInventory = true } label: { Label("Инвентаризация", systemImage: "checklist").frame(maxWidth: .infinity).padding(14) }
        }.font(.subheadline.bold()).foregroundStyle(.white).buttonStyle(.plain)
        .background(inventoryGreen, in: RoundedRectangle(cornerRadius: 16))
    }

    private var filters: some View {
        Picker("Остаток", selection: $filter) {
            Text("Все").tag(Optional<InventoryProduct.StockState>.none)
            Text("Нет").tag(Optional(InventoryProduct.StockState.out))
            Text("Критично").tag(Optional(InventoryProduct.StockState.critical))
            Text("Мало").tag(Optional(InventoryProduct.StockState.low))
            Text("Норма").tag(Optional(InventoryProduct.StockState.normal))
        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var movements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние движения").font(.headline).foregroundStyle(inventoryDark)
            ForEach(inventoryMovements) { movement in
                HStack {
                    Image(systemName: movement.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill").foregroundStyle(movement.kind == .income ? inventoryGreen : .orange)
                    VStack(alignment: .leading) { Text(movement.product).font(.subheadline.bold()); Text("\(movement.kind.rawValue) • \(movement.employee)").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); VStack(alignment: .trailing) { Text(movement.amount).font(.subheadline.bold()); Text(movement.date).font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct InventoryMetric: View {
    let title: String; let value: String; let subtitle: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) { Image(systemName: icon).foregroundStyle(inventoryGreen); Text(value).font(.title3.bold()).foregroundStyle(inventoryDark); Text("\(title) • \(subtitle)").font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct InventoryProductRow: View {
    let product: InventoryProduct
    private var color: Color { switch product.state { case .normal: inventoryGreen; case .low: .yellow; case .critical: .orange; case .out: .red } }
    private var label: String { switch product.state { case .normal: "Норма"; case .low: "Заканчивается"; case .critical: "Критично"; case .out: "Нет" } }
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: product.icon).font(.title3).foregroundStyle(inventoryGreen).frame(width: 44, height: 44).background(inventoryGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) { Text(product.name).font(.subheadline.bold()).foregroundStyle(inventoryDark); Text("\(product.sku) • \(product.category)").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) { Text("\(product.stock.formatted()) \(product.unit)").font(.subheadline.bold()); Text(label).font(.caption2.bold()).foregroundStyle(color) }
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct InventoryProductDetailView: View {
    let product: InventoryProduct
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: product.icon).font(.system(size: 48)).foregroundStyle(inventoryGreen).frame(maxWidth: .infinity).padding(28).background(.white, in: RoundedRectangle(cornerRadius: 22))
                detailCard("Остатки", [("Текущий", "\(product.stock.formatted()) \(product.unit)"), ("Минимальный", "\(product.minimum.formatted()) \(product.unit)")])
                detailCard("Идентификация", [("Артикул", product.sku), ("Штрихкод", product.barcode), ("Категория", product.category)])
                detailCard("Цены", [("Себестоимость", "\(product.cost.formatted()) сум"), ("Закупочная", "\(product.purchasePrice.formatted()) сум"), ("Продажная", "\(product.salePrice.formatted()) сум")])
                detailCard("Поставщик", [("Компания", product.supplier)])
            }.padding()
        }.background(inventoryBackground).navigationTitle(product.name).navigationBarTitleDisplayMode(.inline)
    }

    private func detailCard(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline).foregroundStyle(inventoryDark); ForEach(rows, id: \.0) { row in HStack { Text(row.0).foregroundStyle(.secondary); Spacer(); Text(row.1).fontWeight(.medium) } } }
            .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct InventoryMovementForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = InventoryMovement.Kind.income
    @State private var product = "Кофе зерновой"
    @State private var quantity = ""
    var body: some View {
        Form {
            Picker("Операция", selection: $kind) { ForEach(InventoryMovement.Kind.allCases, id: \.self) { Text($0.rawValue) } }
            Picker("Товар", selection: $product) { ForEach(inventoryProducts.map(\.name), id: \.self) { Text($0) } }
            TextField("Количество", text: $quantity).keyboardType(.decimalPad)
            Section { Button("Сохранить движение") { dismiss() }.frame(maxWidth: .infinity).fontWeight(.bold) }
        }.navigationTitle("Движение товара").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
    }
}

struct StocktakeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var product = "Кофе зерновой"
    @State private var actual = ""
    @State private var verified = false
    var body: some View {
        Form {
            Section("Сканирование") { Label("Сканировать штрихкод", systemImage: "barcode.viewfinder").foregroundStyle(inventoryGreen) }
            Picker("Товар", selection: $product) { ForEach(inventoryProducts.map(\.name), id: \.self) { Text($0) } }
            TextField("Фактическое количество", text: $actual).keyboardType(.decimalPad)
            if verified { Label("Инвентаризация подтверждена", systemImage: "checkmark.seal.fill").foregroundStyle(inventoryGreen) }
            Button("Подтвердить через Face ID") { authenticate() }.frame(maxWidth: .infinity).fontWeight(.bold)
        }.navigationTitle("Инвентаризация").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
    }
    private func authenticate() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Подтвердите инвентаризацию") { success, _ in DispatchQueue.main.async { verified = success } }
    }
}
