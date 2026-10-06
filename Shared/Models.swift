import Foundation
import CoreGraphics

// MARK: - Pomocnik do tolerancyjnego dekodowania
// Biblioteka będzie się rozwijać – nowe pola nie mogą psuć starych plików library.json.

extension KeyedDecodingContainer {
    func v<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback()
    }
}

// MARK: - Rozmiary

enum KafelekSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large, extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "1×1"
        case .medium: "2×1"
        case .large: "2×2"
        case .extraLarge: "4×2"
        }
    }

    var name: String {
        switch self {
        case .small: "Mały"
        case .medium: "Średni"
        case .large: "Duży"
        case .extraLarge: "Bardzo duży"
        }
    }

    /// Wymiary zbliżone do natywnych widżetów macOS.
    var points: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        case .extraLarge: CGSize(width: 766, height: 382)
        }
    }

    var isCompact: Bool { self == .small }
    var isWide: Bool { self != .small }
    var isTall: Bool { self == .large || self == .extraLarge }
}

// MARK: - Rodzaje kafelków

enum DesignKind: String, Codable, CaseIterable, Identifiable {
    case clock, date, calendar, reminders, ai, note, countdown, photo, weather, crypto, battery, astronomy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: "Zegar"
        case .date: "Data"
        case .calendar: "Kalendarz"
        case .reminders: "Przypomnienia"
        case .ai: "Limity AI"
        case .note: "Notatka / cytat"
        case .countdown: "Odliczanie"
        case .photo: "Zdjęcie"
        case .weather: "Pogoda"
        case .crypto: "Kurs krypto"
        case .battery: "Bateria"
        case .astronomy: "Słońce i Księżyc"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock.fill"
        case .date: "calendar.day.timeline.left"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .ai: "gauge.with.dots.needle.67percent"
        case .note: "quote.opening"
        case .countdown: "hourglass"
        case .photo: "photo.fill"
        case .weather: "cloud.sun.fill"
        case .crypto: "bitcoinsign.circle.fill"
        case .battery: "battery.75percent"
        case .astronomy: "moon.stars.fill"
        }
    }
}

// MARK: - Styl

enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case solid, gradient, photo
    var id: String { rawValue }
    var title: String {
        switch self {
        case .solid: "Kolor"
        case .gradient: "Gradient"
        case .photo: "Zdjęcie"
        }
    }
}

enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, mono
    case avenir = "Avenir Next"
    case futura = "Futura"
    case didot = "Didot"
    case baskerville = "Baskerville"
    case georgia = "Georgia"
    case typewriter = "American Typewriter"
    case markerFelt = "Marker Felt"
    case chalkboard = "Chalkboard SE"
    case noteworthy = "Noteworthy"
    case bradley = "Bradley Hand"
    case snell = "Snell Roundhand"
    case copperplate = "Copperplate"
    case impact = "Impact"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Systemowa (SF)"
        case .rounded: "Zaokrąglona"
        case .serif: "Szeryfowa (New York)"
        case .mono: "Maszynowa (SF Mono)"
        default: rawValue
        }
    }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: "Cienka"
        case .regular: "Zwykła"
        case .medium: "Średnia"
        case .semibold: "Półgruba"
        case .bold: "Gruba"
        case .heavy: "Bardzo gruba"
        case .black: "Czarna"
        }
    }
}

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .leading: "Do lewej"
        case .center: "Środek"
        case .trailing: "Do prawej"
        }
    }
}

struct Style: Codable, Hashable {
    var background: BackgroundKind = .solid
    var color1 = "#000000"
    var color2 = "#2C2C2E"
    var gradientAngle: Double = 135
    var photoID: String?
    var photoDim: Double = 0.25
    var textColor = "#FFFFFF"
    var accentColor = "#FF9F0A"
    var font: FontChoice = .system
    var weight: WeightChoice = .semibold
    var textScale: Double = 1.0
    var align: TextAlign = .leading
    var padding: Double = 14
    var borderColor = "#FFFFFF"
    var borderWidth: Double = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = c.v(.background, background)
        color1 = c.v(.color1, color1)
        color2 = c.v(.color2, color2)
        gradientAngle = c.v(.gradientAngle, gradientAngle)
        photoID = c.v(.photoID, photoID)
        photoDim = c.v(.photoDim, photoDim)
        textColor = c.v(.textColor, textColor)
        accentColor = c.v(.accentColor, accentColor)
        font = c.v(.font, font)
        weight = c.v(.weight, weight)
        textScale = c.v(.textScale, textScale)
        align = c.v(.align, align)
        padding = c.v(.padding, padding)
        borderColor = c.v(.borderColor, borderColor)
        borderWidth = c.v(.borderWidth, borderWidth)
    }
}

// MARK: - Opcje poszczególnych rodzajów

enum ClockStyle: String, Codable, CaseIterable, Identifiable {
    case digital, analog, stacked, dual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .digital: "Cyfrowy"
        case .analog: "Analogowy"
        case .stacked: "Duże cyfry"
        case .dual: "Dwie strefy"
        }
    }
}

struct ClockOptions: Codable, Hashable {
    var style: ClockStyle = .digital
    var use24h = true
    var showSeconds = false
    var showDate = true
    var timeZone = ""
    var secondTimeZone = "America/New_York"
    var label = ""

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = c.v(.style, style)
        use24h = c.v(.use24h, use24h)
        showSeconds = c.v(.showSeconds, showSeconds)
        showDate = c.v(.showDate, showDate)
        timeZone = c.v(.timeZone, timeZone)
        secondTimeZone = c.v(.secondTimeZone, secondTimeZone)
        label = c.v(.label, label)
    }
}

enum DateStyle: String, Codable, CaseIterable, Identifiable {
    case dayBig, full, week
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dayBig: "Duży dzień"
        case .full: "Pełna data"
        case .week: "Tydzień i postęp roku"
        }
    }
}

struct DateOptions: Codable, Hashable {
    var style: DateStyle = .dayBig

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = c.v(.style, style)
    }
}

enum CalendarStyle: String, Codable, CaseIterable, Identifiable {
    case next, agenda, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .next: "Najbliższe wydarzenie"
        case .agenda: "Lista wydarzeń"
        case .month: "Miesiąc"
        }
    }
}

struct CalendarOptions: Codable, Hashable {
    var style: CalendarStyle = .agenda
    var calendarIDs: [String] = []
    var daysAhead = 7
    var showLocation = false
    var hideAllDay = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = c.v(.style, style)
        calendarIDs = c.v(.calendarIDs, calendarIDs)
        daysAhead = c.v(.daysAhead, daysAhead)
        showLocation = c.v(.showLocation, showLocation)
        hideAllDay = c.v(.hideAllDay, hideAllDay)
    }
}

enum RemindersStyle: String, Codable, CaseIterable, Identifiable {
    case list, count
    var id: String { rawValue }
    var title: String {
        switch self {
        case .list: "Lista"
        case .count: "Licznik"
        }
    }
}

struct RemindersOptions: Codable, Hashable {
    var style: RemindersStyle = .list
    var listIDs: [String] = []
    var title = ""
    var showDue = true
    var onlyDueToday = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = c.v(.style, style)
        listIDs = c.v(.listIDs, listIDs)
        title = c.v(.title, title)
        showDue = c.v(.showDue, showDue)
        onlyDueToday = c.v(.onlyDueToday, onlyDueToday)
    }
}

enum AIProviderChoice: String, Codable, CaseIterable, Identifiable {
    case both, claude, codex
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Claude + Codex"
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

enum AIMetricChoice: String, Codable, CaseIterable, Identifiable {
    case both, session, weekly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Sesja + tydzień"
        case .session: "Sesja (5 h)"
        case .weekly: "Tydzień"
        }
    }
}

enum AIDisplayStyle: String, Codable, CaseIterable, Identifiable {
    case rings, bars
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rings: "Pierścienie"
        case .bars: "Paski"
        }
    }
}

struct AIOptions: Codable, Hashable {
    var providers: AIProviderChoice = .both
    var metric: AIMetricChoice = .both
    var display: AIDisplayStyle = .rings
    var showRemaining = true
    var showResets = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        providers = c.v(.providers, providers)
        metric = c.v(.metric, metric)
        display = c.v(.display, display)
        showRemaining = c.v(.showRemaining, showRemaining)
        showResets = c.v(.showResets, showResets)
    }
}

struct NoteOptions: Codable, Hashable {
    var text = "No Risk\nNo Porsche"
    var author = ""
    var baseSize: Double = 28

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = c.v(.text, text)
        author = c.v(.author, author)
        baseSize = c.v(.baseSize, baseSize)
    }
}

struct CountdownOptions: Codable, Hashable {
    var title = "Wakacje"
    var target = Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var showTime = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.v(.title, title)
        target = c.v(.target, target)
        showTime = c.v(.showTime, showTime)
    }
}

struct PhotoOptions: Codable, Hashable {
    var photoID: String?
    var caption = ""
    var fill = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        photoID = c.v(.photoID, photoID)
        caption = c.v(.caption, caption)
        fill = c.v(.fill, fill)
    }
}

struct WeatherOptions: Codable, Hashable {
    var placeName = "Warszawa"
    var latitude: Double = 52.2297
    var longitude: Double = 21.0122

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        placeName = c.v(.placeName, placeName)
        latitude = c.v(.latitude, latitude)
        longitude = c.v(.longitude, longitude)
    }

    /// Klucz pod którym dane pogodowe leżą w Snapshot.weather.
    var key: String { String(format: "%.2f,%.2f", latitude, longitude) }
}

struct CryptoOptions: Codable, Hashable {
    var symbols: [String] = ["BTCUSDT"]
    var showChart = true

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbols = c.v(.symbols, symbols)
        showChart = c.v(.showChart, showChart)
    }
}

// MARK: - Projekt kafelka

struct Design: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = "Nowy kafelek"
    var kind: DesignKind = .clock
    var style = Style()
    var clock = ClockOptions()
    var date = DateOptions()
    var calendar = CalendarOptions()
    var reminders = RemindersOptions()
    var ai = AIOptions()
    var note = NoteOptions()
    var countdown = CountdownOptions()
    var photo = PhotoOptions()
    var weather = WeatherOptions()
    var crypto = CryptoOptions()
    var createdAt = Date()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, id)
        name = c.v(.name, name)
        kind = c.v(.kind, kind)
        style = c.v(.style, style)
        clock = c.v(.clock, clock)
        date = c.v(.date, date)
        calendar = c.v(.calendar, calendar)
        reminders = c.v(.reminders, reminders)
        ai = c.v(.ai, ai)
        note = c.v(.note, note)
        countdown = c.v(.countdown, countdown)
        photo = c.v(.photo, photo)
        weather = c.v(.weather, weather)
        crypto = c.v(.crypto, crypto)
        createdAt = c.v(.createdAt, createdAt)
    }

    /// Czy kafelek musi się odświeżać co minutę.
    var ticksEveryMinute: Bool {
        switch kind {
        case .clock, .countdown, .ai, .calendar: true
        default: false
        }
    }

    /// Identyfikatory zdjęć używanych przez kafelek.
    var photoIDs: [String] {
        var ids: [String] = []
        if style.background == .photo, let p = style.photoID { ids.append(p) }
        if kind == .photo, let p = photo.photoID { ids.append(p) }
        return ids
    }
}

// MARK: - Harmonogramy (jak w Widgetsmith: inny kafelek o innej porze)

struct ScheduleRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var startMinutes = 8 * 60
    var designID: UUID?
    /// Dni tygodnia wg Calendar (1 = niedziela … 7 = sobota). Pusty zbiór = codziennie.
    var weekdays: Set<Int> = []

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, id)
        startMinutes = c.v(.startMinutes, startMinutes)
        designID = c.v(.designID, designID)
        weekdays = c.v(.weekdays, weekdays)
    }
}

struct Schedule: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = "Harmonogram"
    var rules: [ScheduleRule] = []
    var fallbackDesignID: UUID?

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, id)
        name = c.v(.name, name)
        rules = c.v(.rules, rules)
        fallbackDesignID = c.v(.fallbackDesignID, fallbackDesignID)
    }

    func designID(at date: Date, calendar cal: Calendar = .current) -> UUID? {
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = comps.weekday ?? 1
        let today = rules.filter { $0.weekdays.isEmpty || $0.weekdays.contains(weekday) }
        if let rule = today.filter({ $0.startMinutes <= minutes }).max(by: { $0.startMinutes < $1.startMinutes }) {
            return rule.designID ?? fallbackDesignID
        }
        // Przed pierwszą regułą dnia obowiązuje ostatnia reguła z poprzedniego dnia.
        let prevWeekday = weekday == 1 ? 7 : weekday - 1
        let yesterday = rules.filter { $0.weekdays.isEmpty || $0.weekdays.contains(prevWeekday) }
        if let rule = yesterday.max(by: { $0.startMinutes < $1.startMinutes }) {
            return rule.designID ?? fallbackDesignID
        }
        return fallbackDesignID
    }

    /// Najbliższe momenty przełączenia w podanym oknie czasu.
    func switchDates(from start: Date, hours: Int, calendar cal: Calendar = .current) -> [Date] {
        var result: [Date] = []
        let day0 = cal.startOfDay(for: start)
        for dayOffset in 0...2 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: day0) else { continue }
            for rule in rules {
                guard let d = cal.date(byAdding: .minute, value: rule.startMinutes, to: day) else { continue }
                if d > start && d < start.addingTimeInterval(Double(hours) * 3600) { result.append(d) }
            }
        }
        return result.sorted()
    }
}

// MARK: - Kafelki pływające na pulpicie (bez limitów WidgetKit)

struct DesktopItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var ref = ""
    var size: KafelekSize = .small
    var x: Double = 80
    var y: Double = 400
    var scale: Double = 1.0

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.v(.id, id)
        ref = c.v(.ref, ref)
        size = c.v(.size, size)
        x = c.v(.x, x)
        y = c.v(.y, y)
        scale = c.v(.scale, scale)
    }
}

// MARK: - Ustawienia

enum ClaudeSource: String, Codable, CaseIterable, Identifiable {
    case auto, claudeCode, web
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Automatycznie"
        case .claudeCode: "Logowanie Claude Code"
        case .web: "Ciasteczko claude.ai (sessionKey)"
        }
    }
}

struct AppSettings: Codable, Hashable {
    var aiRefreshMinutes = 5
    var claudeSource: ClaudeSource = .auto
    var claudeKeychainEnabled = true
    var autoUpdateCheck = true
    var desktopLocked = true
    var launchAtLoginAsked = false
    var firstRunDone = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aiRefreshMinutes = c.v(.aiRefreshMinutes, aiRefreshMinutes)
        claudeSource = c.v(.claudeSource, claudeSource)
        claudeKeychainEnabled = c.v(.claudeKeychainEnabled, claudeKeychainEnabled)
        autoUpdateCheck = c.v(.autoUpdateCheck, autoUpdateCheck)
        desktopLocked = c.v(.desktopLocked, desktopLocked)
        launchAtLoginAsked = c.v(.launchAtLoginAsked, launchAtLoginAsked)
        firstRunDone = c.v(.firstRunDone, firstRunDone)
    }
}

// MARK: - Biblioteka

struct Library: Codable {
    var version = 1
    var designs: [Design] = []
    var schedules: [Schedule] = []
    var desktop: [DesktopItem] = []
    var settings = AppSettings()

    enum CodingKeys: String, CodingKey {
        case version, designs, schedules, desktop, settings
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.v(.version, version)
        designs = Library.lossy(c, .designs)
        schedules = Library.lossy(c, .schedules)
        desktop = Library.lossy(c, .desktop)
        settings = c.v(.settings, settings)
    }

    /// Jeden uszkodzony element nie może skasować całej listy.
    private static func lossy<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [T] {
        guard let items = try? c.decodeIfPresent([Lossy<T>].self, forKey: key) else { return [] }
        return items.compactMap { $0.value }
    }

    func design(_ id: UUID?) -> Design? {
        guard let id else { return nil }
        return designs.first { $0.id == id }
    }

    func schedule(_ id: UUID?) -> Schedule? {
        guard let id else { return nil }
        return schedules.first { $0.id == id }
    }

    /// Rozwiązuje odnośnik ("d:<uuid>" albo "s:<uuid>") na konkretny projekt w danej chwili.
    func resolve(ref: String, at date: Date) -> Design? {
        switch SlotRef(ref) {
        case .design(let id): return design(id)
        case .schedule(let id):
            guard let s = schedule(id) else { return nil }
            return design(s.designID(at: date))
        case .none: return nil
        }
    }

    func title(for ref: String) -> String {
        switch SlotRef(ref) {
        case .design(let id): return design(id)?.name ?? "Usunięty kafelek"
        case .schedule(let id): return schedule(id).map { "⏱ " + $0.name } ?? "Usunięty harmonogram"
        case .none: return "—"
        }
    }

    func switchDates(for ref: String, from start: Date, hours: Int) -> [Date] {
        if case .schedule(let id) = SlotRef(ref), let s = schedule(id) {
            return s.switchDates(from: start, hours: hours)
        }
        return []
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

enum SlotRef: Equatable {
    case design(UUID)
    case schedule(UUID)

    init?(_ raw: String) {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "d": self = .design(id)
        case "s": self = .schedule(id)
        default: return nil
        }
    }

    var raw: String {
        switch self {
        case .design(let id): "d:" + id.uuidString
        case .schedule(let id): "s:" + id.uuidString
        }
    }
}

enum KJSON {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    static let prettyEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
