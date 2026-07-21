import Foundation

struct APIConfiguration {
    let baseURL: URL

    static let production = APIConfiguration(
        baseURL: URL(string: "https://api.example.caseonepos.uz")!
    )
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Сервер вернул некорректный ответ."
        case .unauthorized: return "Необходимо войти в систему заново."
        case .server(let code): return "Ошибка сервера: \(code)."
        case .decoding: return "Не удалось обработать данные CaseonePOS."
        }
    }
}

actor APIClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private var accessToken: String?

    init(configuration: APIConfiguration = .production, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    func get<Response: Decodable>(_ path: String, as type: Response.Type) async throws -> Response {
        let url = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw APIError.server(http.statusCode) }

        do {
            return try JSONDecoder.caseone.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

private extension JSONDecoder {
    static var caseone: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
