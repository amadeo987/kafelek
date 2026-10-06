import AppKit
import SwiftUI
import Combine

/// Kafelki pływające na pulpicie – własne okna nad tapetą, bez limitów i ograniczeń WidgetKit.
@MainActor
final class FloatingManager {
    static let shared = FloatingManager()

    private var panels: [UUID: DesktopPanel] = [:]
    private var cancellables: Set<AnyCancellable> = []

    private var store: LibraryStore { LibraryStore.shared }

    func start() {
        store.$library
            .map { ($0.desktop, $0.settings.desktopLocked) }
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.sync(items: value.0, locked: value.1) }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sync(items: self.store.library.desktop, locked: self.store.library.settings.desktopLocked)
            }
        }
    }

    private func sync(items: [DesktopItem], locked: Bool) {
        let ids = Set(items.map(\.id))
        for (id, panel) in panels where !ids.contains(id) {
            panel.orderOut(nil)
            panel.close()
            panels[id] = nil
        }
        for item in items {
            let panel = panels[item.id] ?? makePanel(item)
            panels[item.id] = panel
            panel.apply(item: item, locked: locked)
        }
    }

    private func makePanel(_ item: DesktopItem) -> DesktopPanel {
        let panel = DesktopPanel(itemID: item.id)
        let host = NSHostingView(rootView: FloatingTileHost(itemID: item.id))
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host
        panel.onMoved = { [weak self] origin in
            guard let self, var it = self.store.library.desktop.first(where: { $0.id == item.id }) else { return }
            it.x = (origin.x / 4).rounded() * 4
            it.y = (origin.y / 4).rounded() * 4
            self.store.updateDesktop(it)
        }
        panel.orderFront(nil)
        return panel
    }
}

final class DesktopPanel: NSPanel {
    let itemID: UUID
    var onMoved: ((CGPoint) -> Void)?
    private var applying = false

    init(itemID: UUID) {
        self.itemID = itemID
        super.init(contentRect: CGRect(x: 0, y: 0, width: 170, height: 170),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        NotificationCenter.default.addObserver(self, selector: #selector(didMove), name: NSWindow.didMoveNotification, object: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func apply(item: DesktopItem, locked: Bool) {
        applying = true
        let size = CGSize(width: item.size.points.width * item.scale, height: item.size.points.height * item.scale)
        var origin = CGPoint(x: item.x, y: item.y)
        // Gdy kafelek wypadł poza ekrany (np. odłączony monitor) – wróć na główny ekran.
        let frame = CGRect(origin: origin, size: size)
        if !NSScreen.screens.contains(where: { $0.frame.intersects(frame) }), let main = NSScreen.main {
            origin = CGPoint(x: main.visibleFrame.minX + 40, y: main.visibleFrame.maxY - size.height - 40)
        }
        setFrame(CGRect(origin: origin, size: size), display: true)
        isMovableByWindowBackground = !locked
        isMovable = !locked
        applying = false
    }

    @objc private func didMove(_ note: Notification) {
        guard !applying else { return }
        onMoved?(frame.origin)
    }
}

/// Zawartość okna kafelka.
struct FloatingTileHost: View {
    @ObservedObject var store = LibraryStore.shared
    @ObservedObject var hub = DataHub.shared
    let itemID: UUID

    var body: some View {
        if let item = store.library.desktop.first(where: { $0.id == itemID }) {
            let initial = store.library.resolve(ref: item.ref, at: Date())
            let seconds = (initial?.kind == .clock && initial?.clock.showSeconds == true)
            TimelineView(TickSchedule(interval: seconds ? 1 : 60)) { tl in
                let design = store.library.resolve(ref: item.ref, at: tl.date)
                ZStack {
                    if let design {
                        KafelekTile(design: design,
                                    ctx: RenderContext(now: tl.date, size: item.size, snapshot: hub.snapshot,
                                                       photos: PhotoStore.images(for: [design]), isWidget: false))
                            .scaleEffect(item.scale, anchor: .topLeading)
                            .frame(width: item.size.points.width * item.scale,
                                   height: item.size.points.height * item.scale,
                                   alignment: .topLeading)
                    } else {
                        RoundedRectangle(cornerRadius: 22).fill(.black.opacity(0.6))
                            .overlay(Text("Kafelek usunięty").foregroundStyle(.white))
                    }
                    if !store.library.settings.desktopLocked {
                        RoundedRectangle(cornerRadius: 22 * item.scale, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundStyle(Color.accentColor)
                            .allowsHitTesting(false)
                    }
                }
            }
            .contextMenu {
                Button("Edytuj kafelek…") { AppDelegate.shared?.openMain(selecting: item.ref) }
                Menu("Rozmiar") {
                    ForEach(KafelekSize.allCases) { size in
                        Button(size.label + " – " + size.name) {
                            var it = item
                            it.size = size
                            store.updateDesktop(it)
                        }
                    }
                }
                Menu("Skala") {
                    ForEach([0.75, 0.9, 1.0, 1.15, 1.3, 1.5], id: \.self) { sc in
                        Button(Fmt.percent(sc * 100)) {
                            var it = item
                            it.scale = sc
                            store.updateDesktop(it)
                        }
                    }
                }
                Divider()
                Button(store.library.settings.desktopLocked ? "Odblokuj układ (przesuwanie)" : "Zablokuj układ") {
                    store.library.settings.desktopLocked.toggle()
                }
                Button("Usuń z pulpitu", role: .destructive) { store.removeFromDesktop(item.id) }
            }
        }
    }
}

/// Harmonogram odświeżania wyrównany do pełnych sekund/minut.
struct TickSchedule: TimelineSchedule {
    let interval: TimeInterval

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next = startDate
        let step = interval
        var first = true
        return AnyIterator {
            if first {
                first = false
                return startDate
            }
            let t = (next.timeIntervalSinceReferenceDate / step).rounded(.down) * step + step
            next = Date(timeIntervalSinceReferenceDate: t)
            return next
        }
    }
}
