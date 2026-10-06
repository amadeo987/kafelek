import Foundation
import AppKit
import ServiceManagement

/// Aktualizacje z GitHub Releases – bez App Store, bez Xcode.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    static let repo = "amadeo987/kafelek"

    struct Release {
        let tag: String
        let build: Int
        let zipURL: URL
        let notes: String
    }

    @Published var status = ""
    @Published var available: Release?
    @Published var busy = false

    var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }

    var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "\(v) (\(currentBuild))"
    }

    func check(silent: Bool) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !silent { status = "Sprawdzam…" }
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Kafelek", forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: req),
              let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let zip = assets.first(where: { ($0["name"] as? String) == "Kafelek.zip" }),
              let zipString = zip["browser_download_url"] as? String,
              let zipURL = URL(string: zipString) else {
            if !silent { status = "Nie udało się sprawdzić aktualizacji." }
            return
        }
        let build = Int(tag.split(separator: ".").last.map(String.init) ?? "") ?? 0
        if build > currentBuild {
            available = Release(tag: tag, build: build, zipURL: zipURL, notes: json["body"] as? String ?? "")
            status = "Dostępna nowa wersja \(tag)"
        } else {
            available = nil
            if !silent { status = "Masz najnowszą wersję ✓" }
        }
    }

    func install() async {
        guard let rel = available, !busy else { return }
        busy = true
        status = "Pobieram \(rel.tag)…"
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("kafelek-update-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let (tmp, _) = try await URLSession.shared.download(from: rel.zipURL)
            let zip = work.appendingPathComponent("Kafelek.zip")
            try fm.moveItem(at: tmp, to: zip)
            status = "Rozpakowuję…"
            let unzip = Shell.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path], timeout: 120)
            let newApp = work.appendingPathComponent("Kafelek.app")
            guard unzip.status == 0, fm.fileExists(atPath: newApp.path) else {
                status = "Błąd rozpakowania"
                busy = false
                return
            }
            let dest = Bundle.main.bundlePath
            let pid = ProcessInfo.processInfo.processIdentifier
            let script = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(dest)"
            mv "\(newApp.path)" "\(dest)"
            xattr -dr com.apple.quarantine "\(dest)" 2>/dev/null
            open "\(dest)"
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", script]
            try p.run()
            status = "Uruchamiam ponownie…"
            NSApp.terminate(nil)
        } catch {
            status = "Błąd: \(error.localizedDescription)"
            busy = false
        }
    }
}

enum LoginItem {
    static var enabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
