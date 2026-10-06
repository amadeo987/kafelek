import Foundation

/// Limity Claude i Codex – tymi samymi drogami co CodexBar:
/// • Claude: token z logowania Claude Code (plik ~/.claude/.credentials.json albo Pęk kluczy „Claude Code-credentials”)
///   → GET api.anthropic.com/api/oauth/usage; albo ciasteczko sessionKey z claude.ai.
/// • Codex: ~/.codex/auth.json → GET chatgpt.com/backend-api/wham/usage.
/// Tokeny nigdy nie są zapisywane ani wysyłane nigdzie indziej.
final class AISource {
    private var claudeToken: (value: String, expires: Date?)?
    private(set) var keychainDenied = false

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 20
        cfg.httpCookieAcceptPolicy = .never
        cfg.httpShouldSetCookies = false
        return URLSession(configuration: cfg)
    }()

    // MARK: Claude

    func fetchClaude(settings: AppSettings, sessionKey: String, userInitiated: Bool) async -> ProviderUsage {
        let now = Date()
        var lastError = "Brak logowania"

        let tryOAuth = settings.claudeSource != .web
        let tryWeb = settings.claudeSource != .claudeCode && !sessionKey.isEmpty

        if tryOAuth {
            if userInitiated { keychainDenied = false }
            if let token = claudeAccessToken(allowKeychain: settings.claudeKeychainEnabled && !keychainDenied) {
                switch await claudeOAuthUsage(token: token) {
                case .success(let usage):
                    return usage
                case .failure(let err):
                    lastError = err.message
                    if err.unauthorized { claudeToken = nil }
                }
            } else {
                lastError = keychainDenied ? "Brak zgody na Pęk kluczy" : "Zaloguj się w Claude Code (komenda: claude)"
            }
        }

        if tryWeb {
            switch await claudeWebUsage(sessionKey: sessionKey) {
            case .success(let usage): return usage
            case .failure(let err): lastError = err.message
            }
        }

        return ProviderUsage(provider: .claude, session: nil, weekly: nil, plan: nil, source: nil, updatedAt: now, error: lastError)
    }

    private struct FetchError: Error {
        let message: String
        var unauthorized = false
    }

    private func claudeAccessToken(allowKeychain: Bool) -> String? {
        if let t = claudeToken, (t.expires ?? .distantFuture) > Date().addingTimeInterval(60) {
            return t.value
        }
        // 1) plik (Linux / starsze wersje)
        let file = AppPaths.home.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: file), let parsed = parseClaudeCredentials(data) {
            claudeToken = parsed
            return parsed.value
        }
        // 2) Pęk kluczy przez /usr/bin/security – zgoda „Zawsze pozwalaj” przetrwa aktualizacje Kafelka
        guard allowKeychain else { return nil }
        let result = Shell.run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"], timeout: 60)
        if result.status == 0, let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
           let parsed = parseClaudeCredentials(data) {
            claudeToken = parsed
            return parsed.value
        }
        if result.status == 128 || result.stderr.contains("User canceled") || result.stderr.contains("user canceled") {
            keychainDenied = true
        }
        return nil
    }

    private func parseClaudeCredentials(_ data: Data) -> (value: String, expires: Date?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        var expires: Date?
        if let ms = oauth["expiresAt"] as? Double { expires = Date(timeIntervalSince1970: ms / 1000) }
        else if let ms = oauth["expiresAt"] as? Int { expires = Date(timeIntervalSince1970: Double(ms) / 1000) }
        return (token, expires)
    }

    private struct ClaudeUsageResponse: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resetsAt: String?
            enum CodingKeys: String, CodingKey {
                case utilization
                case resetsAt = "resets_at"
            }
        }
        let fiveHour: Window?
        let sevenDay: Window?
        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private func claudeOAuthUsage(token: String) async -> Result<ProviderUsage, FetchError> {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return .failure(FetchError(message: "Zły adres")) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("claude-cli/2.1.0 (external, cli)", forHTTPHeaderField: "User-Agent")
        return await perform(req, provider: .claude, source: "Claude Code") { data in
            let r = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            return (Self.window(r.fiveHour), Self.window(r.sevenDay), nil)
        }
    }

    private func claudeWebUsage(sessionKey: String) async -> Result<ProviderUsage, FetchError> {
        guard let orgURL = URL(string: "https://claude.ai/api/organizations") else { return .failure(FetchError(message: "Zły adres")) }
        var req = URLRequest(url: orgURL)
        applyBrowserHeaders(&req, sessionKey: sessionKey)
        guard let result = try? await session.data(for: req), let http = result.1 as? HTTPURLResponse else {
            return .failure(FetchError(message: "Brak połączenia z claude.ai"))
        }
        let data = result.0
        guard http.statusCode == 200 else {
            return .failure(FetchError(message: http.statusCode == 401 || http.statusCode == 403 ? "sessionKey wygasł" : "claude.ai: błąd \(http.statusCode)", unauthorized: true))
        }
        guard let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let org = orgs.first(where: { (($0["capabilities"] as? [String]) ?? []).contains("chat") }) ?? orgs.first,
              let uuid = org["uuid"] as? String,
              let usageURL = URL(string: "https://claude.ai/api/organizations/\(uuid)/usage") else {
            return .failure(FetchError(message: "Nie znaleziono organizacji"))
        }
        var ureq = URLRequest(url: usageURL)
        applyBrowserHeaders(&ureq, sessionKey: sessionKey)
        return await perform(ureq, provider: .claude, source: "claude.ai") { data in
            let r = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            return (Self.window(r.fiveHour), Self.window(r.sevenDay), nil)
        }
    }

    private func applyBrowserHeaders(_ req: inout URLRequest, sessionKey: String) {
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
    }

    private static func window(_ w: ClaudeUsageResponse.Window?) -> LimitWindow? {
        guard let w, let u = w.utilization else { return nil }
        return LimitWindow(usedPercent: u, resetsAt: w.resetsAt.flatMap(parseISO))
    }

    static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    // MARK: Codex

    private struct CodexUsageResponse: Decodable {
        struct Window: Decodable {
            let usedPercent: Double?
            let resetAt: Double?
            let resetAfterSeconds: Double?
            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case resetAt = "reset_at"
                case resetAfterSeconds = "reset_after_seconds"
            }
        }
        struct RateLimit: Decodable {
            let primaryWindow: Window?
            let secondaryWindow: Window?
            enum CodingKeys: String, CodingKey {
                case primaryWindow = "primary_window"
                case secondaryWindow = "secondary_window"
            }
        }
        let planType: String?
        let rateLimit: RateLimit?
        enum CodingKeys: String, CodingKey {
            case planType = "plan_type"
            case rateLimit = "rate_limit"
        }
    }

    func fetchCodex() async -> ProviderUsage {
        let now = Date()
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? AppPaths.home.appendingPathComponent(".codex")
        let authFile = home.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: authFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ProviderUsage(provider: .codex, session: nil, weekly: nil, plan: nil, source: nil, updatedAt: now,
                                 error: "Zaloguj się w Codex (komenda: codex)")
        }
        guard let tokens = json["tokens"] as? [String: Any],
              let access = (tokens["access_token"] as? String) ?? (tokens["accessToken"] as? String), !access.isEmpty else {
            return ProviderUsage(provider: .codex, session: nil, weekly: nil, plan: nil, source: nil, updatedAt: now,
                                 error: "Codex: zaloguj się kontem ChatGPT")
        }
        let accountID = (tokens["account_id"] as? String) ?? (tokens["accountId"] as? String)

        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            return ProviderUsage(provider: .codex, session: nil, weekly: nil, plan: nil, source: nil, updatedAt: now, error: "Zły adres")
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Kafelek", forHTTPHeaderField: "User-Agent")
        if let accountID, !accountID.isEmpty { req.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id") }

        let result = await perform(req, provider: .codex, source: "Codex CLI") { data in
            let r = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
            func win(_ w: CodexUsageResponse.Window?) -> LimitWindow? {
                guard let w, let used = w.usedPercent else { return nil }
                var reset: Date?
                if let at = w.resetAt { reset = Date(timeIntervalSince1970: at) }
                else if let after = w.resetAfterSeconds { reset = Date().addingTimeInterval(after) }
                return LimitWindow(usedPercent: used, resetsAt: reset)
            }
            return (win(r.rateLimit?.primaryWindow), win(r.rateLimit?.secondaryWindow), r.planType)
        }
        switch result {
        case .success(let u): return u
        case .failure(let e):
            return ProviderUsage(provider: .codex, session: nil, weekly: nil, plan: nil, source: nil, updatedAt: now,
                                 error: e.unauthorized ? "Token Codex wygasł – uruchom codex" : e.message)
        }
    }

    // MARK: Wspólne

    private func perform(_ req: URLRequest, provider: AIProvider, source: String,
                         parse: @escaping (Data) throws -> (LimitWindow?, LimitWindow?, String?)) async -> Result<ProviderUsage, FetchError> {
        var request = req
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let result = try? await session.data(for: request), let http = result.1 as? HTTPURLResponse else {
            return .failure(FetchError(message: "Brak połączenia"))
        }
        let data = result.0
        switch http.statusCode {
        case 200:
            do {
                let (s, w, plan) = try parse(data)
                if s == nil && w == nil { return .failure(FetchError(message: "Brak danych o limitach")) }
                return .success(ProviderUsage(provider: provider, session: s, weekly: w, plan: plan, source: source, updatedAt: Date(), error: nil))
            } catch {
                return .failure(FetchError(message: "Nieznany format odpowiedzi"))
            }
        case 401, 403:
            return .failure(FetchError(message: "Logowanie wygasło", unauthorized: true))
        case 429:
            return .failure(FetchError(message: "Za dużo zapytań – spróbuję później"))
        default:
            return .failure(FetchError(message: "Błąd serwera \(http.statusCode)"))
        }
    }
}

// MARK: - Uruchamianie poleceń

enum Shell {
    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    static func run(_ path: String, _ args: [String], timeout: TimeInterval = 30) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
        } catch {
            return Result(status: -1, stdout: "", stderr: error.localizedDescription)
        }
        let deadline = Date().addingTimeInterval(timeout)
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outData = out.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errData = err.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        while p.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if p.isRunning { p.terminate() }
        p.waitUntilExit()
        _ = group.wait(timeout: .now() + 2)
        return Result(status: p.terminationStatus,
                      stdout: String(data: outData, encoding: .utf8) ?? "",
                      stderr: String(data: errData, encoding: .utf8) ?? "")
    }
}
