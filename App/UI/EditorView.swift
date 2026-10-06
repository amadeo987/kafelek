import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

enum EditorTab: String, CaseIterable, Identifiable {
    case widget = "Widżet"
    case style = "Styl"
    case photos = "Zdjęcia"
    var id: String { rawValue }
}

struct EditorView: View {
    let designID: UUID

    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @State private var draft = Design()
    @State private var loaded = false
    @State private var tab: EditorTab = .widget

    var body: some View {
        HStack(spacing: 0) {
            preview
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(EditorTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Form {
                    switch tab {
                    case .widget: widgetTab
                    case .style: StyleEditor(style: $draft.style)
                    case .photos: PhotosEditor(design: $draft)
                    }
                }
                .formStyle(.grouped)
            }
            .frame(minWidth: 400, idealWidth: 440, maxWidth: 520)
        }
        .navigationTitle(draft.name)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Navigation.shared.selection = .gallery
                } label: {
                    Label("Moje widżety", systemImage: "chevron.left")
                }
                .help("Wróć do moich widżetów")
            }
        }
        .onAppear {
            if let d = store.design(designID) {
                draft = d
                if d.kind == .photo && d.photo.photoIDs.isEmpty { tab = .photos }
            }
            loaded = true
        }
        .onChange(of: draft) { _, new in
            if loaded { store.upsert(new) }
        }
    }

    @ViewBuilder private var widgetTab: some View {
        Section {
            TextField("Nazwa", text: $draft.name)
            Picker("Rodzaj", selection: $draft.kind) {
                ForEach(DesignKind.allCases) { k in
                    Label(k.title, systemImage: k.symbol).tag(k)
                }
            }
        }
        KindOptionsEditor(design: $draft)
        Section("Gdzie go postawić") {
            Text("Na pulpicie: prawy klik na tapecie → **Edytuj widżety** → wyszukaj **Kafelek** → przeciągnij rozmiar → prawy klik na widżecie → **Edytuj** → wybierz **\(draft.name)**.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(KafelekSize.allCases) { size in
                    Button(size.label + " – " + size.name) {
                        store.addToDesktop(ref: SlotRef.design(draft.id).raw, size: size)
                    }
                }
            } label: {
                Label("Albo połóż jako kafelek pływający", systemImage: "macwindow.badge.plus")
            }
        }
        Section {
            HStack {
                Button {
                    if let c = store.duplicate(draft.id) { Navigation.shared.selection = .design(c.id) }
                } label: { Label("Duplikuj", systemImage: "plus.square.on.square") }
                Spacer()
                Button(role: .destructive) {
                    store.delete(draft.id)
                    Navigation.shared.selection = .gallery
                } label: { Label("Usuń", systemImage: "trash") }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 18) {
            Picker("Rozmiar", selection: $draft.size) {
                ForEach(KafelekSize.allCases) { s in Text("\(s.name) \(s.label)").tag(s) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 460)

            GeometryReader { geo in
                let pts = draft.size.points
                let scale = min(1.5, min((geo.size.width - 40) / pts.width, (geo.size.height - 20) / pts.height))
                TimelineView(TickSchedule(interval: 1)) { tl in
                    KafelekTile(design: draft, ctx: RenderContext(now: tl.date, size: draft.size, snapshot: hub.snapshot,
                                                                 photos: PhotoStore.images(for: [draft]), isWidget: false, interactive: false))
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                        .scaleEffect(max(0.3, scale))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .padding(24)
        .background(DesktopBackdrop())
    }
}

/// Tło podglądu – coś jak tapeta, żeby szkło i kolory wyglądały jak na pulpicie.
struct DesktopBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "#C9C1B2"), Color(hex: "#8E9AAF"), Color(hex: "#4A5568")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Zdjęcia

struct PhotosEditor: View {
    @Binding var design: Design
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var dropTargeted = false
    @State private var importing = false

    private static let intervals: [(Int, String)] = [
        (5, "5 min"), (15, "15 min"), (30, "30 min"), (60, "1 godz."), (180, "3 godz."),
        (360, "6 godz."), (720, "12 godz."), (1440, "1 dzień"),
    ]

    var body: some View {
        if design.kind == .photo {
            Section {
                dropZone
                HStack {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 30, matching: .images) {
                        Label("Z biblioteki Zdjęć", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        add(urls: pickFiles(multiple: true))
                    } label: {
                        Label("Z plików…", systemImage: "folder")
                    }
                    if importing { ProgressView().controlSize(.small) }
                }
            } header: {
                Text("Zdjęcia (\(design.photo.photoIDs.count))")
            } footer: {
                Text("Dodaj jedno zdjęcie albo kilka – wtedy będą się zmieniać same.")
            }
            if !design.photo.photoIDs.isEmpty {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                        ForEach(design.photo.photoIDs, id: \.self) { id in
                            thumb(id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Wyświetlanie") {
                    if design.photo.photoIDs.count > 1 {
                        Picker("Zmieniaj co", selection: $design.photo.intervalMinutes) {
                            ForEach(Self.intervals, id: \.0) { Text($0.1).tag($0.0) }
                        }
                    }
                    Toggle("Wypełnij cały widżet (przytnij)", isOn: $design.photo.fill)
                    Picker("Kadr", selection: $design.photo.align) {
                        ForEach(PhotoAlign.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Podpis (opcjonalnie)", text: $design.photo.caption)
                }
            }
        } else {
            Section("Zdjęcie w tle") {
                if let id = design.style.photoID, let img = PhotoStore.image(id) {
                    Image(nsImage: img).resizable().scaledToFill().frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack {
                    Button(design.style.photoID == nil ? "Wybierz zdjęcie…" : "Zmień zdjęcie…") {
                        if let url = pickFiles(multiple: false).first, let id = PhotoStore.importImage(from: url) {
                            design.style.photoID = id
                            design.style.background = .photo
                        }
                    }
                    if design.style.background == .photo {
                        Button("Usuń tło") { design.style.background = .solid }
                    }
                }
                if design.style.background == .photo {
                    LabeledContent("Przyciemnienie") {
                        Slider(value: $design.style.photoDim, in: 0...0.8)
                    }
                }
                Text("Chcesz widżet z samymi zdjęciami albo albumem? Zmień rodzaj na **Zdjęcie** w zakładce Widżet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Przeciągnij tu zdjęcia")
                .font(.headline)
            Text("z Findera, Zdjęć albo przeglądarki")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importing = true
            let binding = $design
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let id = PhotoStore.importImage(data: data) {
                        await MainActor.run { binding.wrappedValue.photo.photoIDs.append(id) }
                    }
                }
                await MainActor.run {
                    pickerItems = []
                    importing = false
                }
            }
        }
    }

    private func thumb(_ id: String) -> some View {
        ZStack(alignment: .topTrailing) {
            if let img = PhotoStore.image(id) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary).frame(width: 76, height: 76)
            }
            Button {
                design.photo.photoIDs.removeAll { $0 == id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }

    private func add(urls: [URL]) {
        for url in urls {
            if let id = PhotoStore.importImage(from: url) { design.photo.photoIDs.append(id) }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let binding = $design
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, let id = PhotoStore.importImage(from: url) else { return }
                    DispatchQueue.main.async { binding.wrappedValue.photo.photoIDs.append(id) }
                }
            } else if p.canLoadObject(ofClass: NSImage.self) {
                _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
                    guard let img = obj as? NSImage, let tiff = img.tiffRepresentation,
                          let id = PhotoStore.importImage(data: tiff) else { return }
                    DispatchQueue.main.async { binding.wrappedValue.photo.photoIDs.append(id) }
                }
            }
        }
    }
}

func pickFiles(multiple: Bool) -> [URL] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = multiple
    panel.canChooseDirectories = false
    panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
    panel.message = "Wybierz zdjęcia do widżetu"
    guard panel.runModal() == .OK else { return [] }
    return panel.urls
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
            Text("Zdjęcia dodajesz w zakładce **Zdjęcia** (przeciągnij, z biblioteki Zdjęć albo z plików). Kilka zdjęć = album, który sam się zmienia.")
                .foregroundStyle(.secondary)
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
