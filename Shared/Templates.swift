import Foundation

/// Gotowe wzory – punkt startowy do dalszej edycji.
enum Templates {
    struct Category: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let items: [Design]
    }

    static func make(_ name: String, _ kind: DesignKind, size: KafelekSize = .small, theme: String = "black",
                     _ configure: (inout Design) -> Void = { _ in }) -> Design {
        var d = Design()
        d.name = name
        d.kind = kind
        d.size = size
        if let preset = ThemePreset.all.first(where: { $0.id == theme }) {
            preset.apply(to: &d.style)
        }
        configure(&d)
        return d
    }

    static var categories: [Category] {
        [
            Category(id: "photo", title: "Zdjęcia", symbol: "photo.on.rectangle.angled", items: [
                make("Zdjęcie", .photo) { d in d.style.padding = 12 },
                make("Album – zmieniające się zdjęcia", .photo, size: .medium) { d in
                    d.photo.intervalMinutes = 60
                },
                make("Zdjęcie z podpisem", .photo, size: .large) { d in
                    d.photo.caption = "Podpis"
                    d.style.font = .markerFelt
                },
            ]),
            Category(id: "ai", title: "Limity AI", symbol: "gauge.with.dots.needle.67percent", items: [
                make("Claude", .ai, size: .medium) { d in
                    d.ai.providers = .claude
                    d.ai.display = .bars
                },
                make("Codex", .ai, size: .medium) { d in
                    d.ai.providers = .codex
                    d.ai.display = .bars
                },
                make("Claude – mały", .ai) { d in
                    d.ai.providers = .claude
                    d.ai.display = .bars
                },
                make("Claude + Codex", .ai, size: .large) { d in
                    d.ai.providers = .both
                    d.ai.display = .bars
                },
                make("Limity – pierścienie", .ai, size: .medium, theme: "glass") { d in
                    d.ai.providers = .both
                    d.ai.display = .rings
                },
                make("Sesja Claude – pierścień", .ai, theme: "glass") { d in
                    d.ai.providers = .claude
                    d.ai.metric = .session
                    d.ai.display = .rings
                },
            ]),
            Category(id: "time", title: "Czas i data", symbol: "clock", items: [
                make("Zegar cyfrowy", .clock) { d in
                    d.clock.style = .digital
                    d.style.font = .rounded
                    d.style.weight = .semibold
                },
                make("Zegar analogowy", .clock, theme: "glass") { d in d.clock.style = .analog },
                make("Duże cyfry", .clock) { d in
                    d.clock.style = .stacked
                    d.style.font = .rounded
                    d.style.weight = .bold
                    d.style.accentColor = "#8E8E93"
                },
                make("Dwie strefy", .clock, size: .medium, theme: "graphite") { d in
                    d.clock.style = .dual
                    d.clock.secondTimeZone = "America/New_York"
                },
                make("Data", .date, theme: "white") { d in d.date.style = .dayBig },
                make("Tydzień roku", .date) { d in d.date.style = .week },
            ]),
            Category(id: "calendar", title: "Kalendarz i Przypomnienia", symbol: "calendar", items: [
                make("Najbliższe wydarzenie", .calendar) { d in d.calendar.style = .next },
                make("Agenda", .calendar, size: .medium) { d in d.calendar.style = .agenda },
                make("Miesiąc", .calendar, theme: "white") { d in d.calendar.style = .month },
                make("Przypomnienia", .reminders, size: .medium) { d in d.reminders.style = .list },
                make("Do zrobienia – licznik", .reminders, theme: "glass") { d in d.reminders.style = .count },
            ]),
            Category(id: "tools", title: "Narzędzia", symbol: "bolt.square", items: [
                make("Skróty", .shortcuts, size: .medium) { d in
                    var a1 = ActionItem(); a1.type = .app; a1.title = "Finder"; a1.value = "/System/Library/CoreServices/Finder.app"; a1.symbol = "folder.fill"; a1.colorHex = "#0A84FF"
                    var a2 = ActionItem(); a2.type = .url; a2.title = "YouTube"; a2.value = "https://youtube.com"; a2.symbol = "play.rectangle.fill"; a2.colorHex = "#FF3B30"
                    var a3 = ActionItem(); a3.type = .app; a3.title = "Terminal"; a3.value = "/System/Applications/Utilities/Terminal.app"; a3.symbol = "terminal.fill"; a3.colorHex = "#3A3A3C"
                    var a4 = ActionItem(); a4.type = .url; a4.title = "Claude"; a4.value = "https://claude.ai"; a4.symbol = "sparkle"; a4.colorHex = "#D97757"
                    d.shortcuts.actions = [a1, a2, a3, a4]
                },
                make("System Maca", .system, size: .medium, theme: "glass") { d in d.system.display = .rings },
                make("System – paski", .system) { d in
                    d.system.display = .bars
                    d.system.metrics = [.cpu, .memory, .disk]
                },
                make("Dysk", .system, theme: "glass") { d in
                    d.system.metrics = [.disk]
                    d.system.display = .rings
                },
            ]),
            Category(id: "text", title: "Tekst", symbol: "text.quote", items: [
                make("Cytat", .note, size: .medium) { d in
                    d.note.text = "Twój cytat"
                    d.note.author = "Autor"
                    d.style.font = .serif
                    d.style.weight = .bold
                    d.note.baseSize = 26
                },
                make("Napis odręczny", .note, size: .medium) { d in
                    d.note.text = "Twój tekst"
                    d.style.font = .markerFelt
                    d.style.align = .center
                    d.note.baseSize = 30
                },
                make("Notatka", .note, theme: "paper") { d in
                    d.note.text = "Dziś:\n• \n• \n• "
                    d.style.font = .noteworthy
                    d.style.weight = .bold
                    d.note.baseSize = 17
                },
            ]),
            Category(id: "other", title: "Inne", symbol: "square.grid.2x2", items: [
                make("Odliczanie", .countdown) { d in d.countdown.title = "Wakacje" },
                make("Pogoda", .weather, size: .medium, theme: "glass"),
                make("BTC-USD", .crypto) { d in d.crypto.symbols = ["BTCUSDT"] },
                make("Krypto – lista", .crypto, size: .medium) { d in d.crypto.symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"] },
                make("Słońce i Księżyc", .astronomy, size: .medium, theme: "graphite"),
            ]),
        ]
    }

    static var all: [Design] { categories.flatMap(\.items) }

    /// Kafelki dodawane przy pierwszym uruchomieniu.
    static var starter: [Design] {
        let names = ["Claude", "Codex", "Limity – pierścienie", "System Maca"]
        let all = Templates.all
        return names.compactMap { n in all.first { $0.name == n } }
    }
}
