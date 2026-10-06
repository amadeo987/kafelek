import Foundation

enum Fmt {
    static let pl = Locale(identifier: "pl_PL")

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = pl
        c.firstWeekday = 2
        return c
    }

    static func string(_ date: Date, _ format: String, tz: TimeZone? = nil) -> String {
        let f = DateFormatter()
        f.locale = pl
        f.timeZone = tz ?? .current
        f.dateFormat = format
        return f.string(from: date)
    }

    static func time(_ date: Date, use24h: Bool = true, seconds: Bool = false, tz: TimeZone? = nil) -> String {
        let base = use24h ? "HH:mm" : "h:mm"
        return string(date, seconds ? base + ":ss" : base, tz: tz)
    }

    static func ampm(_ date: Date, tz: TimeZone? = nil) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz ?? .current
        f.dateFormat = "a"
        return f.string(from: date)
    }

    /// „wt., 6 paź”
    static func shortDate(_ date: Date, tz: TimeZone? = nil) -> String {
        string(date, "EEE, d MMM", tz: tz)
    }

    /// „wtorek, 6 października”
    static func longDate(_ date: Date, tz: TimeZone? = nil) -> String {
        string(date, "EEEE, d MMMM", tz: tz)
    }

    static func weekday(_ date: Date) -> String { string(date, "EEEE") }
    static func weekdayShort(_ date: Date) -> String { string(date, "EEE") }
    static func monthName(_ date: Date) -> String { string(date, "LLLL") }
    static func dayNumber(_ date: Date) -> String { string(date, "d") }

    /// „Dziś”, „Jutro” albo „czw., 8 paź”.
    static func dayLabel(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Dziś" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: t) { return "Jutro" }
        return string(date, "EEE, d MMM")
    }

    /// „za 3 h 25 min”, „za 2 d 4 h”.
    static func until(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let s = Int(date.timeIntervalSince(now))
        if s <= 0 { return "teraz" }
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "za \(d) d \(h) h" }
        if h > 0 { return "za \(h) h \(m) min" }
        return "za \(max(1, m)) min"
    }

    static func compactUntil(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let s = Int(date.timeIntervalSince(now))
        if s <= 0 { return "0m" }
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(max(1, m))m"
    }

    static func eventTime(_ e: EventItem) -> String {
        if e.allDay { return "cały dzień" }
        return time(e.start) + "–" + time(e.end)
    }

    static func number(_ value: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.locale = pl
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func price(_ value: Double) -> String {
        if value >= 1000 { return number(value, decimals: 0) }
        if value >= 1 { return number(value, decimals: 2) }
        return number(value, decimals: 4)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func temp(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    static func timeZoneName(_ id: String) -> String {
        if id.isEmpty { return "Lokalnie" }
        let last = id.split(separator: "/").last.map(String.init) ?? id
        return last.replacingOccurrences(of: "_", with: " ")
    }

    static func cryptoName(_ symbol: String) -> String {
        for quote in ["USDT", "USDC", "FDUSD", "BUSD", "EUR", "PLN", "BTC"] where symbol.hasSuffix(quote) && symbol.count > quote.count {
            let base = String(symbol.dropLast(quote.count))
            let q = quote.hasPrefix("USD") || quote == "FDUSD" || quote == "BUSD" ? "USD" : quote
            return base + "-" + q
        }
        return symbol
    }

    static func normalizeCryptoSymbol(_ raw: String) -> String {
        let s = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        if s.isEmpty { return s }
        for quote in ["USDT", "USDC", "FDUSD", "EUR", "PLN"] where s.hasSuffix(quote) && s.count > quote.count {
            return s
        }
        return s + "USDT"
    }
}

// MARK: - Pogoda (kody WMO z Open‑Meteo)

enum WeatherCode {
    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.min.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66: return "cloud.rain.fill"
        case 65, 67: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func name(_ code: Int) -> String {
        switch code {
        case 0: return "Bezchmurnie"
        case 1: return "Przeważnie słonecznie"
        case 2: return "Częściowe zachmurzenie"
        case 3: return "Pochmurno"
        case 45, 48: return "Mgła"
        case 51, 53, 55: return "Mżawka"
        case 56, 57: return "Marznąca mżawka"
        case 61, 63: return "Deszcz"
        case 65: return "Ulewa"
        case 66, 67: return "Marznący deszcz"
        case 71, 73, 75: return "Śnieg"
        case 77: return "Ziarna śniegu"
        case 80, 81, 82: return "Przelotne opady"
        case 85, 86: return "Przelotny śnieg"
        case 95: return "Burza"
        case 96, 99: return "Burza z gradem"
        default: return "—"
        }
    }
}

// MARK: - Fazy Księżyca (liczone lokalnie)

struct MoonPhase {
    let fraction: Double   // 0 = nów, 0.5 = pełnia
    let illumination: Double

    init(date: Date) {
        let synodic = 29.530588853
        let knownNew = Date(timeIntervalSince1970: 947_182_440) // 2000‑01‑06 18:14 UTC
        let days = date.timeIntervalSince(knownNew) / 86400
        var f = (days / synodic).truncatingRemainder(dividingBy: 1)
        if f < 0 { f += 1 }
        fraction = f
        illumination = (1 - cos(2 * .pi * f)) / 2
    }

    private var index: Int { Int((fraction * 8).rounded()) % 8 }

    var name: String {
        ["Nów", "Przybywający sierp", "Pierwsza kwadra", "Przybywający garb",
         "Pełnia", "Ubywający garb", "Ostatnia kwadra", "Ubywający sierp"][index]
    }

    var symbol: String {
        ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous",
         "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"][index]
    }

    /// Dni do najbliższej pełni.
    var daysToFull: Int {
        let synodic = 29.530588853
        var d = (0.5 - fraction) * synodic
        if d < 0 { d += synodic }
        return Int(d.rounded())
    }
}
