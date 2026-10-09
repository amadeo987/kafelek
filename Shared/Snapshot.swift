import Foundation

/// Wszystkie dane „z zewnątrz”, które aplikacja zbiera i podaje widżetom.
struct Snapshot: Codable {
    var generatedAt = Date.distantPast
    var calendarAccess: AccessState = .unknown
    var remindersAccess: AccessState = .unknown
    var calendars: [SourceList] = []
    var reminderLists: [SourceList] = []
    var events: [EventItem] = []
    var reminders: [ReminderItem] = []
    var claude: ProviderUsage?
    var codex: ProviderUsage?
    var weather: [String: WeatherData] = [:]
    var crypto: [String: CryptoQuote] = [:]
    var battery: BatteryInfo?
    var system: SystemStats?
}

struct SystemStats: Codable, Hashable {
    /// Zużycie procesora 0–100.
    var cpu: Double
    var memoryUsed: Double
    var memoryTotal: Double
    var diskFree: Double
    var diskTotal: Double
    var updatedAt: Date

    var memoryPercent: Double { memoryTotal > 0 ? memoryUsed / memoryTotal * 100 : 0 }
    var diskUsedPercent: Double { diskTotal > 0 ? (diskTotal - diskFree) / diskTotal * 100 : 0 }
}

enum AccessState: String, Codable {
    case unknown, granted, denied
}

struct SourceList: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var colorHex: String
}

struct EventItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var calendarID: String
    var colorHex: String
    var location: String?
}

struct ReminderItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var due: Date?
    var dueHasTime: Bool
    var listID: String
    var colorHex: String
    var priority: Int
}

struct LimitWindow: Codable, Hashable {
    /// Zużycie w procentach 0–100.
    var usedPercent: Double
    var resetsAt: Date?

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

enum AIProvider: String, Codable {
    case claude, codex

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var colorHex: String {
        switch self {
        case .claude: "#D97757"
        case .codex: "#3B82F6"
        }
    }

    var symbol: String {
        switch self {
        case .claude: "sparkle"
        case .codex: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ProviderUsage: Codable, Hashable {
    var provider: AIProvider
    var session: LimitWindow?
    var weekly: LimitWindow?
    var plan: String?
    var source: String?
    var updatedAt: Date
    var error: String?
}

struct HourPoint: Codable, Hashable {
    var time: Date
    var temperature: Double
    var code: Int
    var isDay: Bool
}

struct DayPoint: Codable, Hashable {
    var date: Date
    var high: Double
    var low: Double
    var code: Int
}

struct WeatherData: Codable, Hashable {
    var placeName: String
    var temperature: Double
    var apparent: Double
    var code: Int
    var isDay: Bool
    var humidity: Double
    var wind: Double
    var high: Double
    var low: Double
    var sunrise: Date?
    var sunset: Date?
    var hourly: [HourPoint]
    var daily: [DayPoint]
    var updatedAt: Date
}

struct CryptoQuote: Codable, Hashable {
    var symbol: String
    var price: Double
    var changePercent: Double
    var sparkline: [Double]
    var updatedAt: Date
}

struct BatteryInfo: Codable, Hashable {
    var percent: Int
    var charging: Bool
    var onAC: Bool
    var minutesRemaining: Int?
}
