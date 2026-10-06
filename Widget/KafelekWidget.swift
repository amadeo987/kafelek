import WidgetKit
import SwiftUI
import AppIntents
import AppKit

@main
struct KafelekWidgetBundle: WidgetBundle {
    var body: some Widget {
        KafelekWidget()
    }
}

struct KafelekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KafelekWidget", intent: SelectKafelekIntent.self, provider: KafelekProvider()) { entry in
            KafelekWidgetView(entry: entry)
        }
        .configurationDisplayName("Kafelek")
        .description("Twój kafelek z aplikacji Kafelek. Kliknij prawym → Edytuj widżet, żeby wybrać który.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Konfiguracja (wybór kafelka w „Edytuj widżet”)

struct KafelekEntity: AppEntity {
    let id: String
    let name: String
    let subtitle: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Kafelek"
    static var defaultQuery = KafelekQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct KafelekQuery: EntityQuery {
    func entities(for identifiers: [KafelekEntity.ID]) async throws -> [KafelekEntity] {
        let all = await WidgetStore.entities()
        return identifiers.map { id in
            all.first { $0.id == id } ?? KafelekEntity(id: id, name: "Kafelek", subtitle: "")
        }
    }

    func suggestedEntities() async throws -> [KafelekEntity] {
        await WidgetStore.entities()
    }

    func defaultResult() async -> KafelekEntity? {
        await WidgetStore.entities().first
    }
}

struct SelectKafelekIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Wybierz kafelek"
    static var description = IntentDescription("Który z Twoich kafelków ma pokazywać ten widżet.")

    @Parameter(title: "Kafelek")
    var kafelek: KafelekEntity?

    init() {}
}

// MARK: - Dane dla widżetu (z aplikacji przez 127.0.0.1, z kopią zapasową w pamięci podręcznej)

enum WidgetStore {
    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("KafelekWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func library() async -> (Library?, Bool) {
        if let data = await LocalAPI.get("/v1/library"), let lib = try? KJSON.decoder.decode(Library.self, from: data) {
            try? data.write(to: cacheDir.appendingPathComponent("library.json"), options: .atomic)
            return (lib, true)
        }
        if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("library.json")),
           let lib = try? KJSON.decoder.decode(Library.self, from: data) {
            return (lib, false)
        }
        return (nil, false)
    }

    static func snapshot() async -> Snapshot {
        if let data = await LocalAPI.get("/v1/snapshot"), let snap = try? KJSON.decoder.decode(Snapshot.self, from: data) {
            try? data.write(to: cacheDir.appendingPathComponent("snapshot.json"), options: .atomic)
            return snap
        }
        if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("snapshot.json")),
           let snap = try? KJSON.decoder.decode(Snapshot.self, from: data) {
            return snap
        }
        return Snapshot()
    }

    static func photo(_ id: String) async -> NSImage? {
        let file = cacheDir.appendingPathComponent("photo-" + id.filter { $0.isLetter || $0.isNumber || $0 == "-" } + ".jpg")
        if let img = NSImage(contentsOf: file) { return img }
        if let data = await LocalAPI.get("/v1/photo?id=" + LocalAPI.query(id), timeout: 5), let img = NSImage(data: data) {
            try? data.write(to: file, options: .atomic)
            return img
        }
        return nil
    }

    static func entities() async -> [KafelekEntity] {
        let (lib, _) = await library()
        guard let lib else { return [] }
        let designs = lib.designs.map {
            KafelekEntity(id: SlotRef.design($0.id).raw, name: $0.name, subtitle: $0.kind.title)
        }
        let schedules = lib.schedules.map {
            KafelekEntity(id: SlotRef.schedule($0.id).raw, name: "⏱ " + $0.name, subtitle: "Harmonogram – zmienia się o różnych porach")
        }
        return designs + schedules
    }
}

// MARK: - Oś czasu

struct KafelekEntry: TimelineEntry {
    let date: Date
    let design: Design?
    let snapshot: Snapshot
    let photos: [String: NSImage]
    let message: String?
}

struct KafelekProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KafelekEntry {
        KafelekEntry(date: Date(), design: Templates.all.first { $0.kind == .clock }, snapshot: Snapshot(), photos: [:], message: nil)
    }

    func snapshot(for configuration: SelectKafelekIntent, in context: Context) async -> KafelekEntry {
        if configuration.kafelek == nil && context.isPreview {
            return KafelekEntry(date: Date(), design: Templates.all.first { $0.kind == .clock }, snapshot: await WidgetStore.snapshot(), photos: [:], message: nil)
        }
        return await entries(for: configuration, count: 1).first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectKafelekIntent, in context: Context) async -> Timeline<KafelekEntry> {
        let list = await entries(for: configuration, count: 60)
        let needsMinutes = list.contains { $0.design?.ticksEveryMinute ?? false }
        let refresh = Date().addingTimeInterval(needsMinutes ? 60 * 60 : 15 * 60)
        return Timeline(entries: list, policy: .after(refresh))
    }

    private func entries(for configuration: SelectKafelekIntent, count: Int) async -> [KafelekEntry] {
        let (lib, online) = await WidgetStore.library()
        let snap = await WidgetStore.snapshot()
        let now = Date()
        guard let lib else {
            return [KafelekEntry(date: now, design: nil, snapshot: snap, photos: [:],
                                 message: "Uruchom aplikację Kafelek")]
        }
        let ref = configuration.kafelek?.id
            ?? lib.designs.first.map { SlotRef.design($0.id).raw }
            ?? ""
        guard lib.resolve(ref: ref, at: now) != nil || SlotRef(ref) != nil else {
            return [KafelekEntry(date: now, design: nil, snapshot: snap, photos: [:],
                                 message: "Dodaj kafelek w aplikacji Kafelek")]
        }

        // Daty wpisów: co minutę (zegary) + momenty przełączenia harmonogramu.
        let minuteStart = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        var dates: [Date] = [now]
        let first = lib.resolve(ref: ref, at: now)
        let perMinute = (first?.ticksEveryMinute ?? false)
        if perMinute && count > 1 {
            for i in 1..<count {
                dates.append(minuteStart.addingTimeInterval(Double(i) * 60))
            }
        }
        if count > 1 {
            dates.append(contentsOf: lib.switchDates(for: ref, from: now, hours: perMinute ? 1 : 24))
        }
        dates = Array(Set(dates)).sorted()

        // Zdjęcia
        var photos: [String: NSImage] = [:]
        let ids = Set(dates.compactMap { lib.resolve(ref: ref, at: $0) }.flatMap(\.photoIDs))
        for id in ids {
            if let img = await WidgetStore.photo(id) { photos[id] = img }
        }

        let message = online ? nil : "Kafelek nie działa – dane mogą być stare"
        return dates.map { date in
            KafelekEntry(date: date, design: lib.resolve(ref: ref, at: date), snapshot: snap, photos: photos, message: message)
        }
    }
}

// MARK: - Widok

extension KafelekSize {
    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        case .systemExtraLarge: self = .extraLarge
        default: self = .small
        }
    }
}

struct KafelekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KafelekEntry

    var body: some View {
        if let design = entry.design {
            let ctx = RenderContext(now: entry.date, size: KafelekSize(family), snapshot: entry.snapshot,
                                    photos: entry.photos, isWidget: true, interactive: true)
            KafelekContent(design: design, ctx: ctx)
                .overlay(alignment: .topTrailing) {
                    if entry.message != nil {
                        Circle().fill(Color.orange).frame(width: 6, height: 6).padding(6)
                    }
                }
                .containerBackground(for: .widget) {
                    KafelekBackground(style: design.style, ctx: ctx)
                }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(entry.message ?? "Kafelek")
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .padding()
            .containerBackground(for: .widget) { Color.black }
        }
    }
}
