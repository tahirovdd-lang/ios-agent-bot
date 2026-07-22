import Foundation
import Security

// MARK: - API configuration

struct APIConfiguration: Sendable {
    let baseURL: URL
    let timeout: TimeInterval

    static let production = APIConfiguration(
        baseURL: URL(string: "https://api.caseonepos.uz")!,
        timeout: 30
    )
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var body: Data? { get }
}

extension APIEndpoint {
    var queryItems: [URLQueryItem] { [] }
    var body: Data? { nil }
}

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(statusCode: Int, message: String?)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Некорректный адрес сервера"
        case .invalidResponse: return "Сервер вернул некорректный ответ"
        case .unauthorized: return "Сессия истекла. Войдите повторно"
        case let .server(code, message): return message ?? "Ошибка сервера: \(code)"
        case let .decoding(message): return "Ошибка обработки данных: \(message)"
        case let .transport(message): return "Ошибка подключения: \(message)"
        }
    }
}

// MARK: - Secure token storage

protocol TokenStore: Sendable {
    func accessToken() -> String?
    func refreshToken() -> String?
    func save(accessToken: String, refreshToken: String?) throws
    func clear() throws
}

final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service = "uz.caseonepos.manager.auth"
    private let accessAccount = "access-token"
    private let refreshAccount = "refresh-token"

    func accessToken() -> String? { read(account: accessAccount) }
    func refreshToken() -> String? { read(account: refreshAccount) }

    func save(accessToken: String, refreshToken: String?) throws {
        try write(accessToken, account: accessAccount)
        if let refreshToken {
            try write(refreshToken, account: refreshAccount)
        } else {
            try delete(account: refreshAccount)
        }
    }

    func clear() throws {
        try delete(account: accessAccount)
        try delete(account: refreshAccount)
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else { throw APIError.transport("Keychain: \(insertStatus)") }
        } else if status != errSecSuccess {
            throw APIError.transport("Keychain: \(status)")
        }
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIError.transport("Keychain: \(status)")
        }
    }
}

// MARK: - Network client

actor APIClient {
    typealias TokenRefresher = @Sendable (_ refreshToken: String) async throws -> (access: String, refresh: String?)

    private let configuration: APIConfiguration
    private let session: URLSession
    private let tokenStore: TokenStore
    private let tokenRefresher: TokenRefresher?
    private let decoder: JSONDecoder

    init(
        configuration: APIConfiguration,
        tokenStore: TokenStore,
        tokenRefresher: TokenRefresher? = nil
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.tokenRefresher = tokenRefresher
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.waitsForConnectivity = true
        sessionConfiguration.requestCachePolicy = .reloadRevalidatingCacheData
        self.session = URLSession(configuration: sessionConfiguration)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        do {
            return try await perform(endpoint, as: type)
        } catch APIError.unauthorized {
            guard let tokenRefresher,
                  let refreshToken = tokenStore.refreshToken() else { throw APIError.unauthorized }
            let tokens = try await tokenRefresher(refreshToken)
            try tokenStore.save(accessToken: tokens.access, refreshToken: tokens.refresh ?? refreshToken)
            return try await perform(endpoint, as: type)
        }
    }

    private func perform<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        as type: Response.Type
    ) async throws -> Response {
        let request = try makeRequest(endpoint)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw APIError.server(statusCode: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func makeRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// MARK: - Offline cache

actor OfflineCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folderName: String = "CaseonePOSCache") {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = root.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save<Value: Encodable & Sendable>(_ value: Value, key: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    func load<Value: Decodable & Sendable>(_ type: Value.Type, key: String) throws -> Value? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    func remove(key: String) throws {
        let url = fileURL(for: key)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "-")
        return directory.appendingPathComponent("\(safeKey).json")
    }
}

// MARK: - Repository contracts

protocol DashboardRepository: Sendable { func refresh() async throws }
protocol AnalyticsRepository: Sendable { func refresh() async throws }
protocol ReceiptRepository: Sendable { func refresh() async throws }
protocol InventoryRepository: Sendable { func refresh() async throws }
protocol EmployeeRepository: Sendable { func refresh() async throws }
protocol NotificationRepository: Sendable { func refresh() async throws }
protocol SettingsRepository: Sendable { func refresh() async throws }

private actor PlaceholderRepository: DashboardRepository, AnalyticsRepository, ReceiptRepository, InventoryRepository, EmployeeRepository, NotificationRepository, SettingsRepository {
    func refresh() async throws {
        // The concrete API endpoints will replace this implementation.
        // Keeping one contract now allows screens to migrate without redesign.
    }
}

@MainActor
final class AppServices: ObservableObject {
    let apiClient: APIClient
    let cache: OfflineCache
    let tokenStore: TokenStore

    let dashboard: DashboardRepository
    let analytics: AnalyticsRepository
    let receipts: ReceiptRepository
    let inventory: InventoryRepository
    let employees: EmployeeRepository
    let notifications: NotificationRepository
    let settings: SettingsRepository

    @Published private(set) var isOnline = true
    @Published private(set) var lastSyncDate: Date?

    static let live = AppServices()

    init() {
        let tokenStore = KeychainTokenStore()
        let repository = PlaceholderRepository()
        self.tokenStore = tokenStore
        self.cache = OfflineCache()
        self.apiClient = APIClient(configuration: .production, tokenStore: tokenStore)
        self.dashboard = repository
        self.analytics = repository
        self.receipts = repository
        self.inventory = repository
        self.employees = repository
        self.notifications = repository
        self.settings = repository
    }

    func refreshAll() async {
        do {
            async let dashboard: Void = self.dashboard.refresh()
            async let analytics: Void = self.analytics.refresh()
            async let receipts: Void = self.receipts.refresh()
            async let inventory: Void = self.inventory.refresh()
            async let employees: Void = self.employees.refresh()
            async let notifications: Void = self.notifications.refresh()
            async let settings: Void = self.settings.refresh()
            _ = try await (dashboard, analytics, receipts, inventory, employees, notifications, settings)
            isOnline = true
            lastSyncDate = Date()
        } catch {
            isOnline = false
        }
    }
}
