import Foundation

/// Gotowe wzory do galerii – punkt startowy do dalszej edycji.
enum Templates {
    static func make(_ name: String, _ kind: DesignKind, theme: String = "black", _ configure: (inout Design) -> Void = { _ in }) -> Design {
        var d = Design()
        d.name = name
        d.kind = kind
        if let preset = ThemePreset.all.first(where: { $0.id == theme }) {
            preset.apply(to: &d.style)
        }
        configure(&d)
        return d
    }

    static var all: [Design] {
        [
            make("Limity AI", .ai, theme: "claude") { d in
                d.ai.providers = .both
                d.ai.metric = .both
                d.ai.display = .rings
            },
            make("Limit Claude – sesja", .ai, theme: "claude") { d in
                d.ai.providers = .claude
                d.ai.metric = .session
            },
            make("Limity – paski", .ai, theme: "graphite") { d in
                d.ai.display = .bars
            },
            make("Zegar cyfrowy", .clock) { d in
                d.clock.style = .digital
                d.style.font = .rounded
                d.style.weight = .bold
            },
            make("Zegar analogowy", .clock, theme: "white") { d in
                d.clock.style = .analog
            },
            make("Duże cyfry", .clock, theme: "klein") { d in
                d.clock.style = .stacked
                d.style.font = .rounded
                d.style.weight = .heavy
            },
            make("Dwie strefy", .clock, theme: "graphite") { d in
                d.clock.style = .dual
                d.clock.secondTimeZone = "America/New_York"
            },
            make("Data", .date, theme: "white") { d in
                d.date.style = .dayBig
            },
            make("Tydzień roku", .date, theme: "neon") { d in
                d.date.style = .week
            },
            make("Najbliższe wydarzenie", .calendar, theme: "black") { d in
                d.calendar.style = .next
            },
            make("Agenda", .calendar, theme: "graphite") { d in
                d.calendar.style = .agenda
            },
            make("Miesiąc", .calendar, theme: "white") { d in
                d.calendar.style = .month
            },
            make("Przypomnienia", .reminders, theme: "black") { d in
                d.reminders.style = .list
            },
            make("Do zrobienia – licznik", .reminders, theme: "sunset") { d in
                d.reminders.style = .count
            },
            make("No Risk No Porsche", .note, theme: "black") { d in
                d.note.text = "No Risk\nNo Porsche"
                d.style.font = .markerFelt
                d.style.align = .center
                d.note.baseSize = 30
            },
            make("Dreams don't work", .note, theme: "black") { d in
                d.note.text = "dreams don’t work unless you do."
                d.style.font = .serif
                d.style.weight = .black
                d.note.baseSize = 30
            },
            make("Cytat", .note, theme: "black") { d in
                d.note.text = "“I’m the reason I smile everyday.”"
                d.note.author = "Kanye West"
                d.style.font = .serif
                d.style.weight = .bold
                d.note.baseSize = 24
            },
            make("Notatka", .note, theme: "paper") { d in
                d.note.text = "Dziś:\n• trening\n• dziennik tradingowy\n• 8 h snu"
                d.style.font = .noteworthy
                d.style.weight = .bold
                d.note.baseSize = 18
            },
            make("Odliczanie", .countdown, theme: "ocean") { d in
                d.countdown.title = "Wakacje"
            },
            make("Pogoda", .weather, theme: "ocean"),
            make("BTC-USD", .crypto, theme: "black") { d in
                d.crypto.symbols = ["BTCUSDT"]
            },
            make("Krypto – lista", .crypto, theme: "graphite") { d in
                d.crypto.symbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT"]
            },
            make("Bateria Maca", .battery, theme: "black"),
            make("Słońce i Księżyc", .astronomy, theme: "graphite"),
            make("Zdjęcie", .photo, theme: "black"),
        ]
    }

    /// Kafelki dodawane przy pierwszym uruchomieniu.
    static var starter: [Design] {
        let names = ["Limity AI", "Zegar cyfrowy", "Miesiąc", "Przypomnienia", "No Risk No Porsche", "Dreams don't work", "Cytat"]
        let all = Templates.all
        return names.compactMap { n in all.first { $0.name == n } }
    }
}
