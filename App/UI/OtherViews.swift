import SwiftUI

// MARK: - Harmonogramy

struct SchedulesView: View {
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        Form {
            Section {
                Text("Harmonogram to „kafelek”, który sam zmienia się w ciągu dnia – np. rano kalendarz, w pracy limity AI, wieczorem przypomnienia. Wybierasz go w widżecie tak samo jak zwykły kafelek.")
                    .foregroundStyle(.secondary)
                Button {
                    store.addSchedule()
                } label: {
                    Label("Nowy harmonogram", systemImage: "plus")
                }
            }
            ForEach(store.library.schedules) { s in
                ScheduleEditor(schedule: s)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Harmonogramy")
    }
}

struct ScheduleEditor: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var draft: Schedule

    init(schedule: Schedule) {
        _draft = State(initialValue: schedule)
    }

    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    private static let weekdayShort = [1: "Nd", 2: "Pn", 3: "Wt", 4: "Śr", 5: "Cz", 6: "Pt", 7: "So"]

    var body: some View {
        Section {
            TextField("Nazwa", text: $draft.name)
            ForEach($draft.rules) { $rule in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        DatePicker("Od", selection: Binding(
                            get: { Self.date(minutes: rule.startMinutes) },
                            set: { rule.startMinutes = Self.minutes(of: $0) }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(width: 90)
                        Picker("Kafelek", selection: $rule.designID) {
                            Text("—").tag(UUID?.none)
                            ForEach(store.library.designs) { d in Text(d.name).tag(UUID?.some(d.id)) }
                        }
                        .labelsHidden()
                        Button(role: .destructive) {
                            draft.rules.removeAll { $0.id == rule.id }
                        } label: { Image(systemName: "minus.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    HStack(spacing: 4) {
                        Text("Dni:").font(.caption).foregroundStyle(.secondary)
                        ForEach(Self.weekdayOrder, id: \.self) { wd in
                            let on = rule.weekdays.isEmpty || rule.weekdays.contains(wd)
                            Button(Self.weekdayShort[wd] ?? "") {
                                var days = rule.weekdays.isEmpty ? Set(1...7) : rule.weekdays
                                if days.contains(wd) { days.remove(wd) } else { days.insert(wd) }
                                rule.weekdays = (days.count == 7 || days.isEmpty) ? [] : days
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(on ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.15)))
                            .foregroundStyle(on ? Color.white : Color.primary)
                        }
                    }
                }
            }
            HStack {
                Button {
                    var r = ScheduleRule()
                    r.startMinutes = ((draft.rules.map(\.startMinutes).max() ?? 480) + 120) % (24 * 60)
                    r.designID = store.library.designs.first?.id
                    draft.rules.append(r)
                } label: { Label("Dodaj porę", systemImage: "plus") }
                Spacer()
                Picker("Domyślnie", selection: $draft.fallbackDesignID) {
                    Text("—").tag(UUID?.none)
                    ForEach(store.library.designs) { d in Text(d.name).tag(UUID?.some(d.id)) }
                }
                .frame(maxWidth: 260)
            }
            HStack {
                let current = store.library.design(draft.designID(at: Date()))
                Text("Teraz pokazuje: **\(current?.name ?? "—")**").font(.callout)
                Spacer()
                Menu("Na pulpit") {
                    ForEach(KafelekSize.allCases) { size in
                        Button(size.label + " – " + size.name) {
                            store.addToDesktop(ref: SlotRef.schedule(draft.id).raw, size: size)
                        }
                    }
                }
                .frame(width: 110)
                Button("Usuń", role: .destructive) { store.deleteSchedule(draft.id) }
            }
        } header: {
            Text("⏱ " + draft.name)
        }
        .onChange(of: draft) { _, new in store.upsert(new) }
    }

    static func date(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - Kafelki pływające

struct DesktopView: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var newRef = ""
    @State private var newSize: KafelekSize = .small

    private struct RefOption: Identifiable {
        let id: String
        let name: String
    }

    private var refs: [RefOption] {
        store.library.designs.map { RefOption(id: SlotRef.design($0.id).raw, name: $0.name) } +
        store.library.schedules.map { RefOption(id: SlotRef.schedule($0.id).raw, name: "⏱ " + $0.name) }
    }

    var body: some View {
        Form {
            Section {
                Text("Kafelki pływające to okienka Kafelka leżące na tapecie. Nie mają żadnych limitów macOS: dowolna liczba, dowolna skala, zegar z sekundami. Natywne widżety macOS dodajesz osobno (patrz „Jak dodać widżet?”) – obie metody możesz łączyć.")
                    .foregroundStyle(.secondary)
                Toggle("Układ zablokowany (odblokuj, żeby przeciągać kafelki myszką)", isOn: $store.library.settings.desktopLocked)
            }
            Section("Dodaj na pulpit") {
                Picker("Kafelek", selection: $newRef) {
                    Text("Wybierz…").tag("")
                    ForEach(refs) { r in Text(r.name).tag(r.id) }
                }
                Picker("Rozmiar", selection: $newSize) {
                    ForEach(KafelekSize.allCases) { s in Text("\(s.label) \(s.name)").tag(s) }
                }
                .pickerStyle(.segmented)
                Button {
                    store.addToDesktop(ref: newRef, size: newSize)
                    store.library.settings.desktopLocked = false
                } label: {
                    Label("Połóż na pulpicie", systemImage: "macwindow.badge.plus")
                }
                .disabled(newRef.isEmpty)
            }
            Section("Na pulpicie (\(store.library.desktop.count))") {
                if store.library.desktop.isEmpty {
                    Text("Pusto. Dodaj coś powyżej.").foregroundStyle(.secondary)
                }
                ForEach(store.library.desktop) { item in
                    HStack {
                        Text(store.library.title(for: item.ref))
                        Text(item.size.label).foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { item.size },
                            set: { var it = item; it.size = $0; store.updateDesktop(it) }
                        )) {
                            ForEach(KafelekSize.allCases) { s in Text(s.label).tag(s) }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        Button(role: .destructive) {
                            store.removeFromDesktop(item.id)
                        } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Kafelki na pulpicie")
    }
}

// MARK: - Konta AI

struct AccountsView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @State private var sessionKey = Secrets.load().claudeSessionKey

    var body: some View {
        Form {
            Section("Claude") {
                AIStatusRow(usage: hub.snapshot.claude, name: "Stan")
                Picker("Źródło", selection: $store.library.settings.claudeSource) {
                    ForEach(ClaudeSource.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Czytaj logowanie Claude Code z Pęku kluczy", isOn: $store.library.settings.claudeKeychainEnabled)
                Text("Kafelek używa tego samego logowania co Claude Code (jak CodexBar). Przy pierwszym odczycie macOS zapyta o dostęp do pozycji „Claude Code-credentials” – kliknij **Zawsze pozwalaj**. Wymaga zalogowania w Claude Code (`claude` w Terminalu).")
                    .font(.caption).foregroundStyle(.secondary)
                SecureField("sessionKey z claude.ai (opcjonalnie)", text: $sessionKey)
                    .onSubmit { saveKey() }
                Text("Zapasowo: Safari/Chrome → claude.ai → Narzędzia deweloperskie → Ciasteczka → `sessionKey`. Zapisywany tylko lokalnie w pliku z uprawnieniami 600.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Zapisz i połącz") {
                        saveKey()
                        Task { await hub.refreshAI(userInitiated: true) }
                    }
                    if hub.aiRefreshing { ProgressView().controlSize(.small) }
                }
            }
            Section("Codex") {
                AIStatusRow(usage: hub.snapshot.codex, name: "Stan")
                Text("Czytane z `~/.codex/auth.json` (logowanie Codex CLI kontem ChatGPT). Gdy token wygaśnie, wystarczy raz uruchomić `codex` w Terminalu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Odświeżanie") {
                Picker("Co ile", selection: $store.library.settings.aiRefreshMinutes) {
                    Text("2 min").tag(2)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }
                if let t = hub.lastAIRefresh {
                    Text("Ostatnio: \(Fmt.time(t, seconds: true))").foregroundStyle(.secondary)
                }
                Button("Odśwież teraz") { Task { await hub.refreshAI(userInitiated: true) } }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Konta AI")
    }

    private func saveKey() {
        var s = Secrets.load()
        s.claudeSessionKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        s.save()
    }
}

// MARK: - Ustawienia

struct SettingsView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var updater = Updater.shared
    @State private var loginEnabled = LoginItem.enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Ogólne") {
                Toggle("Pokazuj ikonkę na pasku menu", isOn: $store.library.settings.showMenuBarIcon)
                Text("Kafelek nie musi być widoczny – działa po cichu w tle i tylko dostarcza dane widżetom. Okno otworzysz z Launchpada albo Spotlight (⌘ Spacja → Kafelek).")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Uruchamiaj przy logowaniu (potrzebne, żeby widżety miały świeże dane)", isOn: Binding(
                    get: { loginEnabled },
                    set: { on in
                        loginError = LoginItem.set(on)
                        loginEnabled = LoginItem.enabled
                    }
                ))
                if let loginError { Text(loginError).foregroundStyle(.red).font(.caption) }
                Button("Odśwież wszystkie widżety") {
                    DataHub.shared.refreshAll()
                    DataHub.shared.scheduleWidgetReload(urgent: true)
                }
                Button("Pokaż folder z danymi") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppPaths.library])
                }
            }
            Section("Aktualizacje") {
                LabeledContent("Wersja", value: updater.currentVersion)
                Toggle("Sprawdzaj automatycznie", isOn: $store.library.settings.autoUpdateCheck)
                HStack {
                    Button("Sprawdź teraz") { Task { await updater.check(silent: false) } }
                        .disabled(updater.busy)
                    if updater.available != nil {
                        Button("Zainstaluj") { Task { await updater.install() } }
                            .buttonStyle(.borderedProminent)
                    }
                    if updater.busy { ProgressView().controlSize(.small) }
                }
                if !updater.status.isEmpty { Text(updater.status).foregroundStyle(.secondary) }
                Text("Nowe wersje pobierają się z GitHuba (\(Updater.repo)). Bez Xcode, bez App Store, nic nie wygasa.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Lekkość") {
                Text("Kafelek odświeża tylko to, czego używają Twoje kafelki: limity AI co kilka minut, kalendarz po każdej zmianie, pogodę co 30 min, krypto co 2 min. Widżety macOS rysuje system – aplikacja w tle prawie nic nie robi.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ustawienia")
        .onAppear { loginEnabled = LoginItem.enabled }
    }
}

// MARK: - Pomoc

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Jak dodać widżet Kafelek").font(.largeTitle.bold())
                step(1, "Zaprojektuj kafelek", "Galeria wzorów → kliknij wzór → zmień kolory, czcionkę, opcje. Kafelków możesz mieć dowolnie dużo.")
                step(2, "Otwórz edycję widżetów", "Kliknij prawym przyciskiem na pustym miejscu tapety → **Edytuj widżety…**")
                step(3, "Znajdź Kafelek", "Wpisz „Kafelek” w wyszukiwarce. Są trzy rodzaje: **Kafelek** (Twoje projekty), **Zdjęcia** (zdjęcie lub album) i **Limity AI**. Przeciągnij wybrany rozmiar na pulpit.")
                step(4, "Wybierz swój kafelek", "Kliknij prawym na nowym widżecie → **Edytuj „Kafelek”** → w polu **Kafelek** wybierz projekt albo harmonogram.")
                step(5, "Powtarzaj", "Każdy widżet może pokazywać inny projekt – dodaj ich tyle, ile chcesz.")
                Divider()
                Text("Wskazówki").font(.title2.bold())
                Text("""
                • Kafelek działa niewidocznie w tle i odświeża dane (limity AI, kalendarz). Zdjęcia, notatki i zegary działają nawet gdy jest wyłączony.
                • Okno otworzysz z Launchpada albo przez Spotlight (⌘ Spacja → Kafelek).
                • Gdy pulpit jest „przygaszony” (aktywne okno aplikacji), macOS może pokazywać widżety w odcieniach szarości. W Ustawieniach systemowych → Biurko i Dock → Styl widżetów wybierz **Pełny kolor**.
                • Jeśli widżet Kafelek nie pojawia się w galerii, uruchom aplikację raz z folderu Aplikacje i odczekaj chwilę – albo użyj „Kafelków na pulpicie”, które działają zawsze.
                • Kółko przy przypomnieniu odhacza je od razu.
                """)
                .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Pomoc")
    }

    private func step(_ n: Int, _ title: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.title2.bold())
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
