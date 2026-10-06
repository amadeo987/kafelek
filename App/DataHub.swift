import Foundation
import EventKit
import WidgetKit

/// Zbiera dane tylko dla tych źródeł, których używają Twoje kafelki, i tylko tak często jak trzeba.
@MainActor
final class DataHub: ObservableObject {
    static let shared = DataHub()

    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var lastAIRefresh: Date?
    @Published private(set) var aiRefreshing = false

    let calendar = CalendarSource()
    let ai = AISource()

    private var store: LibraryStore { LibraryStore.shared }
    private var timer: Timer?
    private var lastRun: [String: Date] = [:]
    private var lastWidgetReload = Date.distantPast
    private var reloadWork: DispatchWorkItem?
    private var calendarObserver: NSObjectProtocol?

    private init() {
        if let data = try? Data(contentsOf: AppPaths.snapshotCache),
           let snap = try? KJSON.decoder.decode(Snapshot.self, from: data) {
            snapshot = snap
        }
    }

    func start() {
        calendarObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: calendar.store, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCalendar()
                await self?.refreshReminders()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 10
        tick(force: true)
    }

    // MARK: Zapotrzebowanie

    private struct Demand {
        var calendar = false
        var reminders = false
        var ai = false
        var battery = false
        var weather: [String: WeatherOptions] = [:]
        var crypto: Set<String> = []
    }

    private var demand: Demand {
        var d = Demand()
        for design in store.library.designs {
            switch design.kind {
            case .calendar: d.calendar = true
            case .reminders: d.reminders = true
            case .ai: d.ai = true
            case .battery: d.battery = true
            case .weather, .astronomy: d.weather[design.weather.key] = design.weather
            case .crypto:
                for s in design.crypto.symbols {
                    let n = Fmt.normalizeCryptoSymbol(s)
                    if !n.isEmpty { d.crypto.insert(n) }
                }
            default: break
            }
        }
        return d
    }

    private func due(_ key: String, every seconds: TimeInterval, force: Bool) -> Bool {
        if force { lastRun[key] = Date(); return true }
        if let last = lastRun[key], Date().timeIntervalSince(last) < seconds { return false }
        lastRun[key] = Date()
        return true
    }

    /// Wywoływane co 30 s; większość razy nic nie robi.
    func tick(force: Bool = false) {
        let d = demand
        let settings = store.library.settings
        if d.calendar && due("calendar", every: 15 * 60, force: force) {
            Task { await refreshCalendar() }
        }
        if d.reminders && due("reminders", every: 10 * 60, force: force) {
            Task { await refreshReminders() }
        }
        if d.ai && due("ai", every: Double(max(1, settings.aiRefreshMinutes)) * 60, force: force) {
            Task { await refreshAI() }
        }
        if d.battery && due("battery", every: 120, force: force) {
            snapshot.battery = BatterySource.read()
            published(urgent: false)
        }
        if !d.weather.isEmpty && due("weather", every: 30 * 60, force: force) {
            let locations = Array(d.weather.values)
            Task { await refreshWeather(locations) }
        }
        if !d.crypto.isEmpty && due("crypto", every: 120, force: force) {
            let symbols = Array(d.crypto)
            Task { await refreshCrypto(symbols) }
        }
    }

    /// Po zmianie biblioteki: dociągnij brakujące dane od razu.
    func libraryChanged() {
        let d = demand
        if d.calendar && snapshot.events.isEmpty && snapshot.calendarAccess != .denied { Task { await refreshCalendar() } }
        if d.reminders && snapshot.reminders.isEmpty && snapshot.remindersAccess != .denied { Task { await refreshReminders() } }
        if d.ai && snapshot.claude == nil && snapshot.codex == nil { Task { await refreshAI() } }
        if d.battery && snapshot.battery == nil { snapshot.battery = BatterySource.read() }
        let missingWeather = d.weather.filter { snapshot.weather[$0.key] == nil }.map(\.value)
        if !missingWeather.isEmpty { Task { await refreshWeather(missingWeather) } }
        let missingCrypto = d.crypto.filter { snapshot.crypto[$0] == nil }
        if !missingCrypto.isEmpty { Task { await refreshCrypto(Array(missingCrypto)) } }
        scheduleWidgetReload(urgent: true)
    }

    // MARK: Odświeżanie

    func refreshAll() {
        tick(force: true)
    }

    func refreshCalendar() async {
        var state = calendar.access(.event)
        if state == .unknown {
            state = await calendar.requestAccess(.event) ? .granted : .denied
        }
        snapshot.calendarAccess = state
        if state == .granted {
            let (lists, events) = calendar.loadEvents()
            snapshot.calendars = lists
            snapshot.events = events
        }
        published(urgent: true)
    }

    func refreshReminders() async {
        var state = calendar.access(.reminder)
        if state == .unknown {
            state = await calendar.requestAccess(.reminder) ? .granted : .denied
        }
        snapshot.remindersAccess = state
        if state == .granted {
            let (lists, items) = await calendar.loadReminders()
            snapshot.reminderLists = lists
            snapshot.reminders = items
        }
        published(urgent: true)
    }

    func refreshAI(userInitiated: Bool = false) async {
        guard !aiRefreshing else { return }
        aiRefreshing = true
        defer { aiRefreshing = false }
        let settings = store.library.settings
        let key = Secrets.load().claudeSessionKey
        let source = ai
        async let claude = source.fetchClaude(settings: settings, sessionKey: key, userInitiated: userInitiated)
        async let codex = source.fetchCodex()
        let (c, x) = await (claude, codex)
        // Przy błędzie zostaw ostatnie dobre wartości, tylko dopisz komunikat.
        snapshot.claude = merge(old: snapshot.claude, new: c)
        snapshot.codex = merge(old: snapshot.codex, new: x)
        lastAIRefresh = Date()
        published(urgent: false)
    }

    private func merge(old: ProviderUsage?, new: ProviderUsage) -> ProviderUsage {
        guard new.error != nil, var old, old.session != nil || old.weekly != nil else { return new }
        if Date().timeIntervalSince(old.updatedAt) > 6 * 3600 { return new }
        old.error = new.error
        return old
    }

    func refreshWeather(_ locations: [WeatherOptions]) async {
        for loc in locations {
            if let w = await WeatherSource.fetch(loc) {
                snapshot.weather[loc.key] = w
            }
        }
        published(urgent: false)
    }

    func refreshCrypto(_ symbols: [String]) async {
        for s in symbols {
            if let q = await CryptoSource.fetch(s) {
                snapshot.crypto[s] = q
            }
        }
        published(urgent: false)
    }

    func completeReminder(id: String) -> Bool {
        let ok = calendar.complete(id: id)
        if ok {
            snapshot.reminders.removeAll { $0.id == id }
            published(urgent: true)
        }
        return ok
    }

    // MARK: Publikacja

    private func published(urgent: Bool) {
        snapshot.generatedAt = Date()
        if let data = try? KJSON.encoder.encode(snapshot) {
            try? data.write(to: AppPaths.snapshotCache, options: .atomic)
        }
        scheduleWidgetReload(urgent: urgent)
    }

    /// WidgetKit ma dzienny budżet przeładowań – grupujemy zmiany.
    func scheduleWidgetReload(urgent: Bool) {
        let minGap: TimeInterval = urgent ? 3 : 120
        let since = Date().timeIntervalSince(lastWidgetReload)
        reloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.lastWidgetReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
        reloadWork = work
        let delay = since >= minGap ? 1.2 : (minGap - since)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
