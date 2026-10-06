import Foundation

/// Widżet nie ma dostępu do plików aplikacji (to wymagałoby płatnego konta Apple – App Groups),
/// więc aplikacja wystawia malutki serwer tylko na 127.0.0.1, a widżet pobiera z niego dane.
enum LocalAPI {
    static let ports: [UInt16] = [47863, 47864, 47865]
    static let markerHeader = "X-Kafelek"

    static func get(_ path: String, timeout: TimeInterval = 2.5) async -> Data? {
        for port in ports {
            guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { continue }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
            req.httpMethod = "GET"
            guard let result = try? await session.data(for: req),
                  let http = result.1 as? HTTPURLResponse,
                  http.value(forHTTPHeaderField: markerHeader) != nil else { continue }
            return http.statusCode == 200 ? result.0 : nil
        }
        return nil
    }

    @discardableResult
    static func post(_ path: String, timeout: TimeInterval = 5) async -> Bool {
        for port in ports {
            guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { continue }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
            req.httpMethod = "POST"
            guard let result = try? await session.data(for: req),
                  let http = result.1 as? HTTPURLResponse,
                  http.value(forHTTPHeaderField: markerHeader) != nil else { continue }
            return http.statusCode == 200
        }
        return false
    }

    static func query(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.connectionProxyDictionary = [:]
        cfg.timeoutIntervalForRequest = 5
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()
}
