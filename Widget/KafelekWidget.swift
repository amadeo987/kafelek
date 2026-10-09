import WidgetKit
import SwiftUI
import AppIntents
import AppKit

@main
struct KafelekWidgetBundle: WidgetBundle {
    var body: some Widget {
        KafelekWidget()
        PhotoWidget()
        AILimitsWidget()
    }
}

private let allFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]

// MARK: - Widżety

struct KafelekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KafelekWidget", intent: SelectKafelekIntent.self, provider: KafelekProvider()) { entry in
            EntryView(entry: entry)
        }
        .configurationDisplayName("Kafelek")
        .description("Twój widżet zaprojektowany w aplikacji Kafelek. Prawy klik → Edytuj widżet, żeby wybrać który.")
        .supportedFamilies(allFamilies)
        .contentMarginsDisabled()
    }
}

struct PhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KafelekPhotos", intent: SelectAlbumIntent.self, provider: PhotoProvider()) { entry in
            EntryView(entry: entry)
        }
        .configurationDisplayName("Zdjęcia")
        .description("Zdjęcie albo album, który sam się zmienia. Zdjęcia dodajesz w aplikacji Kafelek.")
        .supportedFamilies(allFamilies)
        .contentMarginsDisabled()
    }
}

struct AILimitsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KafelekAI", intent: AILimitsIntent.self, provider: AILimitsProvider()) { entry in
            EntryView(entry: entry)
        }
        .configurationDisplayName("Limity AI")
        .description("Limity Claude i Codex – sesja i tydzień.")
        .supportedFamilies(allFamilies)
        .contentMarginsDisabled()
    }
}

// MARK: - Konfiguracja: Kafelek

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
        return identifiers.map { id in all.first { $0.id == id } ?? KafelekEntity(id: id, name: "Kafelek", subtitle: "") }
    }

    func suggestedEntities() async throws -> [KafelekEntity] {
        await WidgetStore.entities()
    }
}

struct SelectKafelekIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Wybierz kafelek"
    static var description = IntentDescription("Który z Twoich kafelków ma pokazywać ten widżet.")

    @Parameter(title: "Kafelek")
    var kafelek: KafelekEntity?

    init() {}
}

// MARK: - Konfiguracja: Zdjęcia

struct AlbumEntity: AppEntity {
    let id: String
    let name: String
    let count: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Album"
    static var defaultQuery = AlbumQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(count) zdj.")
    }
}

struct AlbumQuery: EntityQuery {
    func entities(for identifiers: [AlbumEntity.ID]) async throws -> [AlbumEntity] {
        let all = await WidgetStore.albums()
        return identifiers.map { id in all.first { $0.id == id } ?? AlbumEntity(id: id, name: "Album", count: 0) }
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        await WidgetStore.albums()
    }
}

struct SelectAlbumIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Wybierz zdjęcia"
    static var description = IntentDescription("Które zdjęcie lub album pokazać.")

    @Parameter(title: "Zdjęcia")
    var album: AlbumEntity?

    init() {}
}

// MARK: - Konfiguracja: Limity AI

enum AIProviderParam: String, AppEnum {
    case claude, codex, both
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Konto"
    static var caseDisplayRepresentations: [AIProviderParam: DisplayRepresentation] = [
        .claude: "Claude", .codex: "Codex", .both: "Claude + Codex",
    ]
}

enum AIMetricParam: String, AppEnum {
    case both, session, weekly
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Limit"
    static var caseDisplayRepresentations: [AIMetricParam: DisplayRepresentation] = [
        .both: "Sesja + tydzień", .session: "Sesja (5 h)", .weekly: "Tydzień",
    ]
}

enum AIStyleParam: String, AppEnum {
    case bars, rings
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Wygląd"
    static var caseDisplayRepresentations: [AIStyleParam: DisplayRepresentation] = [
        .bars: "Paski", .rings: "Pierścienie",
    ]
}

enum AIBackgroundParam: String, AppEnum {
    case black, glass
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tło"
    static var caseDisplayRepresentations: [AIBackgroundParam: DisplayRepresentation] = [
        .black: "Czarne", .glass: "Szkło (przezroczyste)",
    ]
}

struct AILimitsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Limity AI"
    static var description = IntentDescription("Które limity pokazać i jak.")

    @Parameter(title: "Konto", default: .claude)
    var provider: AIProviderParam

    @Parameter(title: "Limit", default: .both)
    var metric: AIMetricParam

    @Parameter(title: "Wygląd", default: .bars)
    var style: AIStyleParam

    @Parameter(title: "Tło", default: .black)
    var background: AIBackgroundParam

    @Parameter(title: "Pokazuj ile zostało", default: true)
    var remaining: Bool

    init() {}

    func design(size: KafelekSize) -> Design {
        var d = Design()
        d.name = "Limity AI"
        d.kind = .ai
        d.size = size
        if let preset = ThemePreset.all.first(where: { $0.id == (background == .glass ? "glass" : "black") }) {
            preset.apply(to: &d.style)
        }
        switch provider {
        case .claude: d.ai.providers = .claude
        case .codex: d.ai.providers = .codex
        case .both: d.ai.providers = .both
        }
        switch metric {
        case .both: d.ai.metric = .both
        case .session: d.ai.metric = .session
        case .weekly: d.ai.metric = .weekly
        }
        d.ai.display = style == .rings ? .rings : .bars
        d.ai.showRemaining = remaining
        return d
    }
}

// MARK: - Dane: najpierw pliki aplikacji, potem lokalny serwer, na końcu własna kopia

enum WidgetStore {
    /// Prawdziwy katalog domowy (w piaskownicy NSHomeDirectory() wskazuje na kontener).
    private static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    private static var appDir: URL {
        URL(fileURLWithPath: realHome).appendingPathComponent("Library/Application Support/Kafelek", isDirectory: true)
    }

    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("KafelekWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func library() async -> Library? {
        if let data = try? Data(contentsOf: appDir.appendingPathComponent("library.json")),
           let lib = try? KJSON.decoder.decode(Library.self, from: data) {
            return lib
        }
        if let data = await LocalAPI.get("/v1/library"), let lib = try? KJSON.decoder.decode(Library.self, from: data) {
            try? data.write(to: cacheDir.appendingPathComponent("library.json"), options: .atomic)
            return lib
        }
        if let data = try? Data(contentsOf: cacheDir.appendingPathComponent("library.json")) {
            return try? KJSON.decoder.decode(Library.self, from: data)
        }
        return nil
    }

    static func snapshot() async -> Snapshot {
        if let data = try? Data(contentsOf: appDir.appendingPathComponent("snapshot-cache.json")),
           let snap = try? KJSON.decoder.decode(Snapshot.self, from: data) {
            return snap
        }
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

    static func photo(_ id: String, maxPixel: Int) async -> NSImage? {
        let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        if let img = ImageLoader.thumbnail(at: appDir.appendingPathComponent("Photos/\(safe).jpg"), maxPixel: maxPixel) {
            return img
        }
        let cached = cacheDir.appendingPathComponent("photo-\(safe).jpg")
        if let img = ImageLoader.thumbnail(at: cached, maxPixel: maxPixel) { return img }
        if let data = await LocalAPI.get("/v1/photo?id=" + LocalAPI.query(id), timeout: 5) {
            try? data.write(to: cached, options: .atomic)
            return ImageLoader.thumbnail(data: data, maxPixel: maxPixel)
        }
        return nil
    }

    static func entities() async -> [KafelekEntity] {
        guard let lib = await library() else { return [] }
        let designs = lib.designs.map {
            KafelekEntity(id: SlotRef.design($0.id).raw, name: $0.name, subtitle: $0.kind.title + " · " + $0.size.label)
        }
        let schedules = lib.schedules.map {
            KafelekEntity(id: SlotRef.schedule($0.id).raw, name: "⏱ " + $0.name, subtitle: "Harmonogram")
        }
        return designs + schedules
    }

    static func albums() async -> [AlbumEntity] {
        guard let lib = await library() else { return [] }
        return lib.designs.filter { $0.kind == .photo }.map {
            AlbumEntity(id: SlotRef.design($0.id).raw, name: $0.name, count: $0.photo.photoIDs.count)
        }
    }
}

// MARK: - Oś czasu

struct KafelekEntry: TimelineEntry {
    let date: Date
    let design: Design?
    let snapshot: Snapshot
    let photos: [String: NSImage]
    let message: String?
    var gallery = false
}

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

    var photoPixels: Int {
        switch self {
        case .small: 420
        case .medium, .large: 800
        case .extraLarge: 1100
        }
    }
}

enum TimelineBuilder {
    /// Buduje wpisy osi czasu dla projektu (albo harmonogramu) – zegary co minutę, zmiany zdjęć, przełączenia harmonogramu.
    static func entries(lib: Library, snap: Snapshot, ref: String, size: KafelekSize, single: Bool) async -> [KafelekEntry] {
        let now = Date()
        guard let first = lib.resolve(ref: ref, at: now) else {
            return [KafelekEntry(date: now, design: nil, snapshot: snap, photos: [:], message: "Wybierz kafelek: prawy klik → Edytuj widżet")]
        }
        var dates: [Date] = [now]
        if !single {
            let minuteStart = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
            if first.ticksEveryMinute {
                for i in 1..<60 { dates.append(minuteStart.addingTimeInterval(Double(i) * 60)) }
            }
            if first.kind == .photo {
                dates.append(contentsOf: first.photo.switchDates(from: now, count: first.ticksEveryMinute ? 0 : 6))
            }
            dates.append(contentsOf: lib.switchDates(for: ref, from: now, hours: first.ticksEveryMinute ? 1 : 12))
        }
        dates = Array(Set(dates)).sorted()

        var photos: [String: NSImage] = [:]
        var ids: [String] = []
        for date in dates {
            guard let d = lib.resolve(ref: ref, at: date) else { continue }
            for id in d.photoIDs(at: date) where !ids.contains(id) { ids.append(id) }
        }
        for id in ids.prefix(8) {
            if let img = await WidgetStore.photo(id, maxPixel: size.photoPixels) { photos[id] = img }
        }
        return dates.map { date in
            KafelekEntry(date: date, design: lib.resolve(ref: ref, at: date), snapshot: snap, photos: photos, message: nil)
        }
    }

    static func timeline(_ list: [KafelekEntry]) -> Timeline<KafelekEntry> {
        let ticks = list.contains { $0.design?.ticksEveryMinute ?? false }
        let last = list.last?.date ?? Date()
        let refresh = ticks ? Date().addingTimeInterval(3600) : max(last, Date().addingTimeInterval(15 * 60))
        return Timeline(entries: list, policy: .after(refresh))
    }
}

struct KafelekProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KafelekEntry {
        KafelekEntry(date: Date(), design: Templates.all.first { $0.kind == .clock }, snapshot: Snapshot(), photos: [:], message: nil)
    }

    func snapshot(for configuration: SelectKafelekIntent, in context: Context) async -> KafelekEntry {
        // W galerii widżetów: czysty podgląd jak w Widgetsmith – wybór projektu dopiero po dodaniu.
        if context.isPreview && configuration.kafelek == nil {
            return KafelekEntry(date: Date(), design: nil, snapshot: Snapshot(), photos: [:], message: nil, gallery: true)
        }
        return await entries(configuration, context, single: true).first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectKafelekIntent, in context: Context) async -> Timeline<KafelekEntry> {
        TimelineBuilder.timeline(await entries(configuration, context, single: false))
    }

    private func entries(_ configuration: SelectKafelekIntent, _ context: Context, single: Bool) async -> [KafelekEntry] {
        let size = KafelekSize(context.family)
        guard let lib = await WidgetStore.library() else {
            return [KafelekEntry(date: Date(), design: Templates.all.first { $0.kind == .clock }, snapshot: Snapshot(), photos: [:],
                                 message: "Otwórz aplikację Kafelek")]
        }
        let snap = await WidgetStore.snapshot()
        // Bez wyboru: pierwszy projekt w pasującym rozmiarze.
        let fallback = (lib.designs.first { $0.size == size } ?? lib.designs.first).map { SlotRef.design($0.id).raw } ?? ""
        let ref = configuration.kafelek?.id ?? fallback
        return await TimelineBuilder.entries(lib: lib, snap: snap, ref: ref, size: size, single: single)
    }
}

struct PhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KafelekEntry {
        KafelekEntry(date: Date(), design: Templates.all.first { $0.kind == .photo }, snapshot: Snapshot(), photos: [:], message: nil)
    }

    func snapshot(for configuration: SelectAlbumIntent, in context: Context) async -> KafelekEntry {
        await entries(configuration, context, single: true).first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectAlbumIntent, in context: Context) async -> Timeline<KafelekEntry> {
        TimelineBuilder.timeline(await entries(configuration, context, single: false))
    }

    private func entries(_ configuration: SelectAlbumIntent, _ context: Context, single: Bool) async -> [KafelekEntry] {
        let size = KafelekSize(context.family)
        guard let lib = await WidgetStore.library() else { return [placeholder(in: context)] }
        let photoDesigns = lib.designs.filter { $0.kind == .photo && !$0.photo.photoIDs.isEmpty }
        let fallback = (photoDesigns.first { $0.size == size } ?? photoDesigns.first).map { SlotRef.design($0.id).raw }
        guard let ref = configuration.album?.id ?? fallback else { return [placeholder(in: context)] }
        return await TimelineBuilder.entries(lib: lib, snap: Snapshot(), ref: ref, size: size, single: single)
    }
}

struct AILimitsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> KafelekEntry {
        KafelekEntry(date: Date(), design: AILimitsIntent().design(size: KafelekSize(context.family)), snapshot: Snapshot(), photos: [:], message: nil)
    }

    func snapshot(for configuration: AILimitsIntent, in context: Context) async -> KafelekEntry {
        let design = configuration.design(size: KafelekSize(context.family))
        return KafelekEntry(date: Date(), design: design, snapshot: await WidgetStore.snapshot(), photos: [:], message: nil)
    }

    func timeline(for configuration: AILimitsIntent, in context: Context) async -> Timeline<KafelekEntry> {
        let design = configuration.design(size: KafelekSize(context.family))
        let snap = await WidgetStore.snapshot()
        let now = Date()
        // Co minutę przez 15 min (odliczanie do resetu), potem nowe dane.
        let entries = (0..<15).map { i in
            KafelekEntry(date: now.addingTimeInterval(Double(i) * 60), design: design, snapshot: snap, photos: [:], message: nil)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(5 * 60)))
    }
}

// MARK: - Widok

struct EntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KafelekEntry

    var body: some View {
        if let design = entry.design {
            let ctx = RenderContext(now: entry.date, size: KafelekSize(family), snapshot: entry.snapshot,
                                    photos: entry.photos, isWidget: true, interactive: true)
            if design.style.background == .glass {
                KafelekContent(design: design, ctx: ctx)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                KafelekContent(design: design, ctx: ctx)
                    .containerBackground(for: .widget) {
                        KafelekBackground(style: design.style, ctx: ctx)
                    }
            }
        } else if entry.gallery {
            GalleryPlaceholder(size: KafelekSize(family))
                .containerBackground(for: .widget) { Color(hex: "#161617") }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(entry.message ?? "Kafelek")
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}


/// Podgląd w galerii „Edytuj widżety”.
struct GalleryPlaceholder: View {
    let size: KafelekSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white).frame(width: 10, height: 16)
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.35)).frame(width: 10, height: 6.5)
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.8)).frame(width: 10, height: 6.5)
                }
            }
            Spacer(minLength: 0)
            Text("Twój widżet")
                .font(.system(size: size == .small ? 15 : 18, weight: .semibold))
                .foregroundStyle(.white)
            Text(size == .small ? "Po dodaniu wybierz, który pokazać."
                                : "Po dodaniu: prawy klik → Edytuj widżet → wybierz jeden z Twoich widżetów z Kafelka.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
