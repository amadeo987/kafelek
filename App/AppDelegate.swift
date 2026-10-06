import AppKit
import SwiftUI
import WidgetKit

@main
enum KafelekMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Wspólny stan nawigacji okna głównego.
@MainActor
final class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var selection: SidebarItem? = .gallery
}

enum SidebarItem: Hashable {
    case gallery
    case design(UUID)
    case schedules
    case desktop
    case accounts
    case settings
    case help
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private let server = LocalServer()

    private var store: LibraryStore { LibraryStore.shared }
    private var hub: DataHub { DataHub.shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        buildMainMenu()
        setupStatusItem()

        store.onChange = { [weak self] in
            self?.hub.libraryChanged()
        }
        server.handler = { req in await AppDelegate.route(req) }
        server.start()
        hub.start()
        FloatingManager.shared.start()

        if !store.library.settings.launchAtLoginAsked {
            store.library.settings.launchAtLoginAsked = true
            LoginItem.set(true)
        }
        if !store.library.settings.firstRunDone {
            store.library.settings.firstRunDone = true
            openMain(selecting: nil)
        }
        if store.library.settings.autoUpdateCheck {
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await Updater.shared.check(silent: true)
            }
            Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
                Task { @MainActor in
                    if LibraryStore.shared.library.settings.autoUpdateCheck {
                        await Updater.shared.check(silent: true)
                    }
                }
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMain(selecting: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    // MARK: Serwer dla widżetu

    private static func route(_ req: LocalServer.Request) async -> LocalServer.Response {
        await MainActor.run { () -> LocalServer.Response in
            let store = LibraryStore.shared
            let hub = DataHub.shared
            switch (req.method, req.path) {
            case ("GET", "/v1/ping"):
                return .json(Data("{\"ok\":true}".utf8))
            case ("GET", "/v1/library"):
                var lib = store.library
                lib.desktop = []
                return .json(try? KJSON.encoder.encode(lib))
            case ("GET", "/v1/snapshot"):
                return .json(try? KJSON.encoder.encode(hub.snapshot))
            case ("GET", "/v1/photo"):
                guard let id = req.query["id"], let data = PhotoStore.data(id) else { return .notFound }
                return LocalServer.Response(status: 200, contentType: "image/jpeg", body: data)
            case ("POST", "/v1/reminders/complete"):
                guard let id = req.query["id"], hub.completeReminder(id: id) else {
                    return LocalServer.Response(status: 400, contentType: "text/plain", body: Data("fail".utf8))
                }
                return .json(Data("{\"ok\":true}".utf8))
            case ("POST", "/v1/refresh"):
                hub.refreshAll()
                return .json(Data("{\"ok\":true}".utf8))
            default:
                return .notFound
            }
        }
    }

    // MARK: Okno główne

    func openMain(selecting ref: String?) {
        if let ref, let slot = SlotRef(ref) {
            switch slot {
            case .design(let id): Navigation.shared.selection = .design(id)
            case .schedule: Navigation.shared.selection = .schedules
            }
        }
        if window == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1080, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Kafelek"
            w.titlebarAppearsTransparent = false
            w.isReleasedWhenClosed = false
            w.minSize = CGSize(width: 900, height: 600)
            w.contentViewController = NSHostingController(rootView: MainView())
            w.setFrameAutosaveName("KafelekMain")
            if !w.setFrameUsingName("KafelekMain") { w.center() }
            w.delegate = self
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === window {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: Pasek menu

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Kafelek")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()

        let header = NSMenuItem(title: "Kafelek", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for usage in [hub.snapshot.claude, hub.snapshot.codex].compactMap({ $0 }) {
            var parts: [String] = []
            if let s = usage.session { parts.append("sesja \(Fmt.percent(s.remainingPercent))") }
            if let w = usage.weekly { parts.append("tydzień \(Fmt.percent(w.remainingPercent))") }
            let text = usage.provider.title + ": " + (parts.isEmpty ? (usage.error ?? "brak danych") : parts.joined(separator: " · "))
            let mi = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            mi.isEnabled = false
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Otwórz Kafelek…", action: #selector(openFromMenu), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Odśwież dane", action: #selector(refreshFromMenu), keyEquivalent: "r").target = self
        let lockTitle = store.library.settings.desktopLocked ? "Odblokuj kafelki na pulpicie" : "Zablokuj kafelki na pulpicie"
        menu.addItem(withTitle: lockTitle, action: #selector(toggleLock), keyEquivalent: "").target = self
        if let rel = Updater.shared.available {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Zainstaluj aktualizację \(rel.tag)", action: #selector(installUpdate), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Zakończ Kafelek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func openFromMenu() { openMain(selecting: nil) }

    @objc private func refreshFromMenu() {
        hub.refreshAll()
        Task { await hub.refreshAI(userInitiated: true) }
    }

    @objc private func toggleLock() { store.library.settings.desktopLocked.toggle() }

    @objc private func installUpdate() { Task { await Updater.shared.install() } }

    /// Menu główne – potrzebne m.in. żeby działało ⌘C / ⌘V w polach tekstowych.
    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "O Kafelku", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ukryj Kafelek", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Zakończ Kafelek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edycja")
        edit.addItem(withTitle: "Cofnij", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Powtórz", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Wytnij", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopiuj", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Wklej", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Zaznacz wszystko", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Okno")
        windowMenu.addItem(withTitle: "Zamknij", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Zminimalizuj", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}
