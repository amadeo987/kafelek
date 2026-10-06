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
                    d.photo.caption = "No risk, no story"
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
            Category(id: "text", title: "Tekst i cytaty", symbol: "quote.opening", items: [
                make("No Risk No Porsche", .note, size: .medium) { d in
                    d.note.text = "No Risk\nNo Porsche"
                    d.style.font = .markerFelt
                    d.style.align = .center
                    d.note.baseSize = 30
                },
                make("Dreams don't work", .note, size: .medium) { d in
                    d.note.text = "dreams don’t work unless you do."
                    d.style.font = .serif
                    d.style.weight = .black
                    d.note.baseSize = 30
                },
                make("Cytat", .note, size: .medium) { d in
                    d.note.text = "“I’m the reason I smile everyday.”"
                    d.note.author = "Kanye West"
                    d.style.font = .serif
                    d.style.weight = .bold
                    d.note.baseSize = 24
                },
                make("Notatka", .note, theme: "paper") { d in
                    d.note.text = "Dziś:\n• trening\n• dziennik\n• 8 h snu"
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
                make("Bateria Maca", .battery, theme: "glass"),
                make("Słońce i Księżyc", .astronomy, size: .medium, theme: "graphite"),
            ]),
        ]
    }

    static var all: [Design] { categories.flatMap(\.items) }

    /// Kafelki dodawane przy pierwszym uruchomieniu.
    static var starter: [Design] {
        let names = ["Claude", "Codex", "Limity – pierścienie", "No Risk No Porsche", "Dreams don't work", "Cytat"]
        let all = Templates.all
        return names.compactMap { n in all.first { $0.name == n } }
    }
}
