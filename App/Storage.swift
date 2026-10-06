import Foundation
import AppKit
import SwiftUI
import WidgetKit

enum AppPaths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Kafelek", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var library: URL { support.appendingPathComponent("library.json") }
    static var secrets: URL { support.appendingPathComponent("secrets.json") }
    static var snapshotCache: URL { support.appendingPathComponent("snapshot-cache.json") }

    static var photos: URL {
        let dir = support.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Prawdziwy katalog domowy (np. do ~/.codex, ~/.claude).
    static var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }
}

// MARK: - Zdjęcia

enum PhotoStore {
    private static let cache = NSCache<NSString, NSImage>()

    /// Kopiuje i zmniejsza zdjęcie (max 1600 px), zwraca jego identyfikator.
    static func importImage(from url: URL) -> String? {
        guard let image = ImageLoader.thumbnail(at: url, maxPixel: 1600) ?? NSImage(contentsOf: url) else { return nil }
        return save(image)
    }

    static func importImage(data: Data) -> String? {
        guard let image = ImageLoader.thumbnail(data: data, maxPixel: 1600) ?? NSImage(data: data) else { return nil }
        return save(image)
    }

    private static func save(_ image: NSImage) -> String? {
        let id = UUID().uuidString
        guard let data = jpegData(image, maxSide: 1600) else { return nil }
        do {
            try data.write(to: file(id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    static func delete(_ id: String) {
        cache.removeObject(forKey: id as NSString)
        try? FileManager.default.removeItem(at: file(id))
    }

    static func file(_ id: String) -> URL {
        let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return AppPaths.photos.appendingPathComponent(safe + ".jpg")
    }

    static func data(_ id: String) -> Data? {
        try? Data(contentsOf: file(id))
    }

    static func image(_ id: String) -> NSImage? {
        if let img = cache.object(forKey: id as NSString) { return img }
        guard let img = NSImage(contentsOf: file(id)) else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }

    static func images(for designs: [Design]) -> [String: NSImage] {
        var out: [String: NSImage] = [:]
        for id in designs.flatMap(\.photoIDs) {
            if let img = image(id) { out[id] = img }
        }
        return out
    }

    private static func jpegData(_ image: NSImage, maxSide: CGFloat) -> Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let scale = min(1, maxSide / max(w, h))
        let nw = Int(w * scale), nh = Int(h * scale)
        guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        guard let out = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: out)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}

// MARK: - Sekrety (np. sessionKey claude.ai) – plik tylko dla Ciebie, nigdy nie trafia do widżetu

struct Secrets: Codable {
    var claudeSessionKey = ""

    static func load() -> Secrets {
        guard let data = try? Data(contentsOf: AppPaths.secrets),
              let s = try? JSONDecoder().decode(Secrets.self, from: data) else { return Secrets() }
        return s
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: AppPaths.secrets, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: AppPaths.secrets.path)
    }
}

// MARK: - Biblioteka kafelków

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published var library: Library {
        didSet { changed() }
    }

    /// Wywoływane po każdej zmianie (serwer, widżety, kafelki pływające).
    var onChange: (() -> Void)?

    private var saveWork: DispatchWorkItem?

    private init() {
        if let data = try? Data(contentsOf: AppPaths.library),
           var lib = try? KJSON.decoder.decode(Library.self, from: data) {
            if lib.version < 2 {
                // v1 nie znało rozmiarów – dopasuj je i odśwież wygląd limitów AI.
                for i in lib.designs.indices {
                    let k = lib.designs[i].kind
                    lib.designs[i].size = [.ai, .note, .weather, .astronomy].contains(k) ? .medium : .small
                    if k == .ai, lib.designs[i].style.color1 == "#2B1A14",
                       let black = ThemePreset.all.first(where: { $0.id == "black" }) {
                        black.apply(to: &lib.designs[i].style)
                        lib.designs[i].ai.display = .bars
                    }
                }
                lib.version = 2
            }
            library = lib
        } else {
            var lib = Library()
            lib.version = 2
            lib.designs = Templates.starter
            library = lib
            save()
        }
    }

    private func changed() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        onChange?()
    }

    func save() {
        guard let data = try? KJSON.prettyEncoder.encode(library) else { return }
        try? data.write(to: AppPaths.library, options: .atomic)
    }

    // MARK: Projekty

    func design(_ id: UUID) -> Design? { library.design(id) }

    func upsert(_ design: Design) {
        if let i = library.designs.firstIndex(where: { $0.id == design.id }) {
            if library.designs[i] != design { library.designs[i] = design }
        } else {
            library.designs.append(design)
        }
    }

    @discardableResult
    func add(from template: Design, size: KafelekSize? = nil) -> Design {
        var d = template
        d.id = UUID()
        if let size { d.size = size }
        d.createdAt = Date()
        library.designs.append(d)
        return d
    }

    @discardableResult
    func duplicate(_ id: UUID) -> Design? {
        guard var d = library.design(id) else { return nil }
        d.id = UUID()
        d.name += " (kopia)"
        d.createdAt = Date()
        library.designs.append(d)
        return d
    }

    func delete(_ id: UUID) {
        library.designs.removeAll { $0.id == id }
        let ref = SlotRef.design(id).raw
        library.desktop.removeAll { $0.ref == ref }
        for i in library.schedules.indices {
            for j in library.schedules[i].rules.indices where library.schedules[i].rules[j].designID == id {
                library.schedules[i].rules[j].designID = nil
            }
            if library.schedules[i].fallbackDesignID == id { library.schedules[i].fallbackDesignID = nil }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        library.designs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Harmonogramy

    @discardableResult
    func addSchedule() -> Schedule {
        var s = Schedule()
        s.name = "Harmonogram \(library.schedules.count + 1)"
        var morning = ScheduleRule()
        morning.startMinutes = 7 * 60
        morning.designID = library.designs.first(where: { $0.kind == .calendar })?.id ?? library.designs.first?.id
        var work = ScheduleRule()
        work.startMinutes = 9 * 60
        work.designID = library.designs.first(where: { $0.kind == .ai })?.id ?? library.designs.first?.id
        var evening = ScheduleRule()
        evening.startMinutes = 18 * 60
        evening.designID = library.designs.first(where: { $0.kind == .reminders })?.id ?? library.designs.first?.id
        s.rules = [morning, work, evening]
        s.fallbackDesignID = library.designs.first?.id
        library.schedules.append(s)
        return s
    }

    func upsert(_ schedule: Schedule) {
        if let i = library.schedules.firstIndex(where: { $0.id == schedule.id }) {
            if library.schedules[i] != schedule { library.schedules[i] = schedule }
        } else {
            library.schedules.append(schedule)
        }
    }

    func deleteSchedule(_ id: UUID) {
        library.schedules.removeAll { $0.id == id }
        let ref = SlotRef.schedule(id).raw
        library.desktop.removeAll { $0.ref == ref }
    }

    // MARK: Pulpit

    func addToDesktop(ref: String, size: KafelekSize) {
        var item = DesktopItem()
        item.ref = ref
        item.size = size
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let n = Double(library.desktop.count)
        item.x = frame.minX + 40 + n * 24
        item.y = frame.maxY - 60 - size.points.height - n * 24
        library.desktop.append(item)
    }

    func updateDesktop(_ item: DesktopItem) {
        if let i = library.desktop.firstIndex(where: { $0.id == item.id }), library.desktop[i] != item {
            library.desktop[i] = item
        }
    }

    func removeFromDesktop(_ id: UUID) {
        library.desktop.removeAll { $0.id == id }
    }
}
