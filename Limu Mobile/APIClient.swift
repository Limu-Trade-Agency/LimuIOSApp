import Foundation
import Security

struct APIEnvelope<Value: Decodable>: Decodable {
    let status: Int
    let message: String
    let data: Value?
    let code: String?
    let errors: [String: String]?
}

struct APIError: LocalizedError {
    let status: Int
    let message: String
    let code: String?
    let fields: [String: String]

    var errorDescription: String? {
        if let mappedMessage = userFacingMessage {
            return mappedMessage
        }
        if let first = fields.values.first { return first }
        return message
    }

    private var userFacingMessage: String? {
        switch code {
        case "INVALID_CREDENTIALS":
            return "The email, phone, or password you entered is incorrect. Please try again."
        case "ACCOUNT_TEMPORARILY_LOCKED":
            return "Too many failed sign-in attempts. Please wait a few minutes and try again."
        case "ACCOUNT_INACTIVE":
            return "This account has been deactivated. To use it again, register with the same phone number or email and enter the code we send you."
        case "RATE_LIMITED":
            return "Too many attempts. Please wait a few minutes before trying again."
        default:
            return nil
        }
    }
}

private enum KeychainStore {
    nonisolated static let service = "LimuTrade.Mobile.API.v4"

    nonisolated static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated static func write(_ value: String, account: String) {
        delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()
    private static let liveBaseURL = URL(string: "https://portal.limu.co.mw/Api/v4/client/")!
    private static let localBaseURL = URL(string: "http://localhost/limu/Api/v4/client/")!
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["LIMU_API_BASE_URL"],
           let url = normalizedBaseURL(override) {
            return url
        }
        if ProcessInfo.processInfo.arguments.contains("--local-api") {
            return localBaseURL
        }
        return liveBaseURL
    }

    static var environmentName: String {
        baseURL.host?.caseInsensitiveCompare("localhost") == .orderedSame ? "local" : "live"
    }

    static var hasStoredSession: Bool { KeychainStore.read("refreshToken") != nil }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var accessToken: String?
    private var refreshToken: String?
    private var persistSession = true

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
        accessToken = KeychainStore.read("accessToken")
        refreshToken = KeychainStore.read("refreshToken")
    }

    func store(_ session: SessionDTO, persist: Bool) {
        accessToken = session.accessToken
        refreshToken = session.refreshToken
        persistSession = persist
        if persist {
            KeychainStore.write(session.accessToken, account: "accessToken")
            KeychainStore.write(session.refreshToken, account: "refreshToken")
        } else {
            KeychainStore.delete("accessToken")
            KeychainStore.delete("refreshToken")
        }
    }

    func clearSession() {
        accessToken = nil
        refreshToken = nil
        KeychainStore.delete("accessToken")
        KeychainStore.delete("refreshToken")
    }

    func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        let data = try await perform(path: path, method: "GET", query: query, body: nil, authenticated: true)
        return try decodeData(data)
    }

    func post<Value: Decodable>(_ path: String, body: [String: Any], authenticated: Bool = true) async throws -> Value {
        let data = try await perform(path: path, method: "POST", body: body, authenticated: authenticated)
        return try decodeData(data)
    }

    func put<Value: Decodable>(_ path: String, body: [String: Any]) async throws -> Value {
        let data = try await perform(path: path, method: "PUT", body: body, authenticated: true)
        return try decodeData(data)
    }

    func patch<Value: Decodable>(_ path: String, body: [String: Any]) async throws -> Value {
        let data = try await perform(path: path, method: "PATCH", body: body, authenticated: true)
        return try decodeData(data)
    }

    func send(_ path: String, method: String = "POST", body: [String: Any] = [:], authenticated: Bool = true) async throws {
        _ = try await perform(path: path, method: method, body: body, authenticated: authenticated)
    }

    func uploadPaymentProof(invoiceID: Int, amount: Double, transactionID: String, notes: String, fileURL: URL) async throws -> PaymentDTO {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("invoiceId", String(invoiceID))
        field("amount", String(amount))
        if !transactionID.isEmpty { field("transactionId", transactionID) }
        if !notes.isEmpty { field("notes", notes) }

        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        let fileData = try Data(contentsOf: fileURL)
        let ext = fileURL.pathExtension.lowercased()
        let mime = ext == "pdf" ? "application/pdf" : ext == "png" ? "image/png" : "image/jpeg"
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: \(mime)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        let data = try await perform(
            path: "payments/submit-proof.php",
            method: "POST",
            bodyData: body,
            contentType: "multipart/form-data; boundary=\(boundary)",
            authenticated: true
        )
        return try decodeData(data)
    }

    private func perform(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: [String: Any]?,
        authenticated: Bool,
        retryAfterRefresh: Bool = true
    ) async throws -> Data {
        let bodyData: Data?
        if let body {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } else {
            bodyData = nil
        }
        return try await perform(path: path, method: method, query: query, bodyData: bodyData, contentType: "application/json", authenticated: authenticated, retryAfterRefresh: retryAfterRefresh)
    }

    private func perform(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        bodyData: Data?,
        contentType: String,
        authenticated: Bool,
        retryAfterRefresh: Bool = true
    ) async throws -> Data {
        guard var components = URLComponents(url: URL(string: path, relativeTo: Self.baseURL)!, resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if bodyData != nil { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        if authenticated, let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401, authenticated, retryAfterRefresh, try await refreshSession() {
            return try await perform(path: path, method: method, query: query, bodyData: bodyData, contentType: contentType, authenticated: authenticated, retryAfterRefresh: false)
        }
        guard (200..<300).contains(http.statusCode) else { throw decodeError(data, fallbackStatus: http.statusCode) }
        return data
    }

    private func refreshSession() async throws -> Bool {
        guard let refreshToken else { return false }
        do {
            let data = try await perform(
                path: "auth/refresh.php",
                method: "POST",
                body: ["refreshToken": refreshToken],
                authenticated: false,
                retryAfterRefresh: false
            )
            let refreshed: SessionDTO = try decodeData(data)
            store(refreshed, persist: persistSession)
            return true
        } catch {
            clearSession()
            return false
        }
    }

    private func decodeData<Value: Decodable>(_ data: Data) throws -> Value {
        let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
        guard let value = envelope.data else {
            throw APIError(status: envelope.status, message: envelope.message, code: envelope.code, fields: envelope.errors ?? [:])
        }
        return value
    }

    private func decodeError(_ data: Data, fallbackStatus: Int) -> APIError {
        if let envelope = try? decoder.decode(APIEnvelope<APIEmpty>.self, from: data) {
            return APIError(status: envelope.status, message: envelope.message, code: envelope.code, fields: envelope.errors ?? [:])
        }
        return APIError(status: fallbackStatus, message: "The server returned an unexpected response.", code: nil, fields: [:])
    }

    private var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: "limuDeviceID") { return existing }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: "limuDeviceID")
        return created
    }

    private static func normalizedBaseURL(_ value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.hasSuffix("/") {
            trimmed.append("/")
        }
        return URL(string: trimmed)
    }
}
