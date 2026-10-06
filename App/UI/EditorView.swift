import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    let designID: UUID

    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @State private var draft = Design()
    @State private var loaded = false
    @State private var previewSize: KafelekSize = .small

    var body: some View {
        HSplitView {
            Form {
                Section("Kafelek") {
                    TextField("Nazwa", text: $draft.name)
                    Picker("Rodzaj", selection: $draft.kind) {
                        ForEach(DesignKind.allCases) { k in
                            Label(k.title, systemImage: k.symbol).tag(k)
                        }
                    }
                }
                KindOptionsEditor(design: $draft)
                StyleEditor(style: $draft.style)
                Section("Akcje") {
                    Menu {
                        ForEach(KafelekSize.allCases) { size in
                            Button(size.label + " – " + size.name) {
                                store.addToDesktop(ref: SlotRef.design(draft.id).raw, size: size)
                            }
                        }
                    } label: {
                        Label("Połóż na pulpicie jako kafelek pływający", systemImage: "macwindow.badge.plus")
                    }
                    HStack {
                        Button {
                            if let c = store.duplicate(draft.id) { Navigation.shared.selection = .design(c.id) }
                        } label: { Label("Duplikuj", systemImage: "plus.square.on.square") }
                        Spacer()
                        Button(role: .destructive) {
                            store.delete(draft.id)
                            Navigation.shared.selection = .gallery
                        } label: { Label("Usuń kafelek", systemImage: "trash") }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, idealWidth: 440, maxWidth: 560)

            preview
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(draft.name)
        .onAppear {
            if let d = store.design(designID) {
                draft = d
                previewSize = (d.kind == .ai || d.kind == .weather) ? .medium : .small
            }
            loaded = true
        }
        .onChange(of: draft) { _, new in
            if loaded { store.upsert(new) }
        }
    }

    private var preview: some View {
        VStack(spacing: 18) {
            Picker("Rozmiar", selection: $previewSize) {
                ForEach(KafelekSize.allCases) { s in Text("\(s.label)  \(s.name)").tag(s) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 520)

            Spacer(minLength: 0)
            GeometryReader { geo in
                let pts = previewSize.points
                let scale = min(1.4, min((geo.size.width - 40) / pts.width, (geo.size.height - 20) / pts.height))
                TimelineView(TickSchedule(interval: 1)) { tl in
                    KafelekTile(design: draft, ctx: RenderContext(now: tl.date, size: previewSize, snapshot: hub.snapshot,
                                                                 photos: PhotoStore.images(for: [draft]), isWidget: false, interactive: false))
                        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
                        .scaleEffect(max(0.3, scale))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text("Jak go postawić na pulpicie?")
                    .font(.headline)
                Text("Kliknij prawym na tapecie → **Edytuj widżety** → wyszukaj **Kafelek** → przeciągnij rozmiar na pulpit → prawy klik na widżecie → **Edytuj „Kafelek”** → wybierz **\(draft.name)**.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: 460)
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(hex: "#5B6B7A"), Color(hex: "#2B3440")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.35)
        )
    }
}

// MARK: - Opcje zależne od rodzaju

struct KindOptionsEditor: View {
    @Binding var design: Design
    @ObservedObject private var hub = DataHub.shared

    static let zones = ["", "Europe/Warsaw", "Europe/London", "Europe/Berlin", "Europe/Kyiv", "America/New_York", "America/Chicago",
                        "America/Los_Angeles", "America/Sao_Paulo", "Asia/Dubai", "Asia/Kolkata", "Asia/Singapore",
                        "Asia/Hong_Kong", "Asia/Shanghai", "Asia/Tokyo", "Australia/Sydney", "UTC"]

    var body: some View {
        switch design.kind {
        case .clock: clock
        case .date:
            Section("Data") {
                Picker("Styl", selection: $design.date.style) {
                    ForEach(DateStyle.allCases) { Text($0.title).tag($0) }
                }
            }
        case .calendar: calendar
        case .reminders: reminders
        case .ai: ai
        case .note: note
        case .countdown: countdown
        case .photo: photo
        case .weather, .astronomy:
            Section(design.kind == .weather ? "Pogoda" : "Słońce i Księżyc") {
                PlaceSearch(options: $design.weather)
                Text("Dane: Open‑Meteo (za darmo, bez konta). Odświeżanie co 30 min.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .crypto: crypto
        case .battery:
            Section("Bateria") {
                Text("Pokazuje poziom baterii tego Maca. Odświeżanie co 2 min.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func zonePicker(_ title: String, _ binding: Binding<String>, allowLocal: Bool) -> some View {
        Picker(title, selection: binding) {
            ForEach(Self.zones.filter { allowLocal || !$0.isEmpty }, id: \.self) { z in
                Text(z.isEmpty ? "Lokalna (\(TimeZone.current.identifier))" : z).tag(z)
            }
        }
    }

    private var clock: some View {
        Section("Zegar") {
            Picker("Styl", selection: $design.clock.style) {
                ForEach(ClockStyle.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Format 24‑godzinny", isOn: $design.clock.use24h)
            Toggle("Pokaż datę", isOn: $design.clock.showDate)
            Toggle("Sekundy (tylko kafelki pływające – widżety macOS nie pozwalają)", isOn: $design.clock.showSeconds)
            zonePicker("Strefa czasowa", $design.clock.timeZone, allowLocal: true)
            if design.clock.style == .dual {
                zonePicker("Druga strefa", $design.clock.secondTimeZone, allowLocal: false)
            }
            TextField("Podpis (opcjonalnie)", text: $design.clock.label)
        }
    }

    private var calendar: some View {
        Section("Kalendarz") {
            Picker("Styl", selection: $design.calendar.style) {
                ForEach(CalendarStyle.allCases) { Text($0.title).tag($0) }
            }
            Stepper("Dni do przodu: \(design.calendar.daysAhead)", value: $design.calendar.daysAhead, in: 1...31)
            Toggle("Ukryj wydarzenia całodniowe", isOn: $design.calendar.hideAllDay)
            Toggle("Pokaż miejsce", isOn: $design.calendar.showLocation)
            AccessRow(state: hub.snapshot.calendarAccess, name: "Kalendarza") {
                Task { await hub.refreshCalendar() }
            }
            DisclosureGroup("Kalendarze (\(design.calendar.calendarIDs.isEmpty ? "wszystkie" : String(design.calendar.calendarIDs.count)))") {
                MultiSelectList(items: hub.snapshot.calendars, selected: $design.calendar.calendarIDs)
            }
        }
    }

    private var reminders: some View {
        Section("Przypomnienia") {
            Picker("Styl", selection: $design.reminders.style) {
                ForEach(RemindersStyle.allCases) { Text($0.title).tag($0) }
            }
            TextField("Tytuł (puste = nazwa listy)", text: $design.reminders.title)
            Toggle("Pokaż termin", isOn: $design.reminders.showDue)
            Toggle("Tylko na dziś i zaległe", isOn: $design.reminders.onlyDueToday)
            AccessRow(state: hub.snapshot.remindersAccess, name: "Przypomnień") {
                Task { await hub.refreshReminders() }
            }
            DisclosureGroup("Listy (\(design.reminders.listIDs.isEmpty ? "wszystkie" : String(design.reminders.listIDs.count)))") {
                MultiSelectList(items: hub.snapshot.reminderLists, selected: $design.reminders.listIDs)
            }
            Text("Kółko przy przypomnieniu w widżecie odhacza je od razu w Apple Przypomnieniach.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var ai: some View {
        Section("Limity AI") {
            Picker("Konta", selection: $design.ai.providers) {
                ForEach(AIProviderChoice.allCases) { Text($0.title).tag($0) }
            }
            Picker("Limity", selection: $design.ai.metric) {
                ForEach(AIMetricChoice.allCases) { Text($0.title).tag($0) }
            }
            Picker("Wygląd", selection: $design.ai.display) {
                ForEach(AIDisplayStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Pokazuj", selection: $design.ai.showRemaining) {
                Text("Ile zostało").tag(true)
                Text("Ile zużyte").tag(false)
            }
            .pickerStyle(.segmented)
            Toggle("Czas do resetu", isOn: $design.ai.showResets)
            AIStatusRow(usage: hub.snapshot.claude, name: "Claude")
            AIStatusRow(usage: hub.snapshot.codex, name: "Codex")
            Button("Ustawienia kont AI…") { Navigation.shared.selection = .accounts }
        }
    }

    private var note: some View {
        Section("Tekst") {
            TextEditor(text: $design.note.text)
                .font(.body)
                .frame(minHeight: 90)
            TextField("Autor (dla cytatu, opcjonalnie)", text: $design.note.author)
            LabeledContent("Wielkość") {
                Slider(value: $design.note.baseSize, in: 10...60)
            }
        }
    }

    private var countdown: some View {
        Section("Odliczanie") {
            TextField("Tytuł", text: $design.countdown.title)
            DatePicker("Data", selection: $design.countdown.target)
            Toggle("Pokazuj godziny", isOn: $design.countdown.showTime)
            Text("Po minięciu daty kafelek liczy dni „od”.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var photo: some View {
        Section("Zdjęcie") {
            HStack {
                if let id = design.photo.photoID, let img = PhotoStore.image(id) {
                    Image(nsImage: img).resizable().scaledToFill().frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(design.photo.photoID == nil ? "Wybierz zdjęcie…" : "Zmień zdjęcie…") {
                    if let id = pickPhoto() { design.photo.photoID = id }
                }
            }
            TextField("Podpis (opcjonalnie)", text: $design.photo.caption)
            Toggle("Wypełnij cały kafelek", isOn: $design.photo.fill)
        }
    }

    private var crypto: some View {
        Section("Kurs krypto") {
            TextField("Symbole (po przecinku)", text: Binding(
                get: { design.crypto.symbols.joined(separator: ", ") },
                set: { design.crypto.symbols = $0.split(whereSeparator: { $0 == "," || $0 == " " }).map { String($0).uppercased() } }
            ))
            Text("Np. BTC, ETH, SOL albo pełne pary jak BTCUSDC. Dane: Binance, co 2 min.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Wykres 24 h", isOn: $design.crypto.showChart)
        }
    }
}

func pickPhoto() -> String? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Wybierz zdjęcie do kafelka"
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return PhotoStore.importImage(from: url)
}

struct AccessRow: View {
    let state: AccessState
    let name: String
    let request: () -> Void

    var body: some View {
        switch state {
        case .granted:
            Label("Dostęp do \(name): jest", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .unknown:
            Button("Daj dostęp do \(name)", action: request)
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Label("Brak dostępu do \(name)", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                Button("Otwórz Ustawienia prywatności") {
                    let pane = name.hasPrefix("Kal") ? "Privacy_Calendars" : "Privacy_Reminders"
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

struct AIStatusRow: View {
    let usage: ProviderUsage?
    let name: String

    var body: some View {
        HStack {
            Text(name).fontWeight(.medium)
            Spacer()
            if let u = usage {
                if u.session != nil || u.weekly != nil {
                    Text([u.session.map { "sesja \(Fmt.percent($0.remainingPercent))" },
                          u.weekly.map { "tydzień \(Fmt.percent($0.remainingPercent))" }].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
                if let e = u.error {
                    Text(e).foregroundStyle(.orange).lineLimit(1)
                }
            } else {
                Text("brak danych").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}

struct MultiSelectList: View {
    let items: [SourceList]
    @Binding var selected: [String]

    var body: some View {
        if items.isEmpty {
            Text("Brak list – daj dostęp powyżej.").foregroundStyle(.secondary)
        } else {
            ForEach(items) { item in
                Toggle(isOn: Binding(
                    get: { selected.isEmpty || selected.contains(item.id) },
                    set: { on in toggle(item.id, on) }
                )) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: item.colorHex)).frame(width: 9, height: 9)
                        Text(item.title)
                    }
                }
            }
        }
    }

    private func toggle(_ id: String, _ on: Bool) {
        var chosen = selected.isEmpty ? Set(items.map(\.id)) : Set(selected)
        if on { chosen.insert(id) } else { chosen.remove(id) }
        if chosen.count == items.count || chosen.isEmpty {
            selected = []
        } else {
            selected = items.map(\.id).filter { chosen.contains($0) }
        }
    }
}

struct PlaceSearch: View {
    @Binding var options: WeatherOptions
    @State private var query = ""
    @State private var results: [GeoPlace] = []
    @State private var searching = false

    var body: some View {
        LabeledContent("Miejsce") {
            Text(options.placeName).fontWeight(.semibold)
        }
        HStack {
            TextField("Szukaj miasta…", text: $query)
                .onSubmit { search() }
            Button(searching ? "Szukam…" : "Szukaj") { search() }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
        }
        ForEach(results) { place in
            Button {
                options.placeName = place.name
                options.latitude = place.latitude
                options.longitude = place.longitude
                results = []
                query = ""
            } label: {
                HStack {
                    Text(place.name).fontWeight(.medium)
                    Text(place.detail).foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searching = true
        Task {
            let found = await WeatherSource.search(q)
            await MainActor.run {
                results = found
                searching = false
            }
        }
    }
}
