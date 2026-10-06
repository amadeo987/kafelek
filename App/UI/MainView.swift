import SwiftUI

struct MainView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @ObservedObject private var nav = Navigation.shared
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.selection) {
                Section {
                    Label("Galeria wzorów", systemImage: "sparkles.rectangle.stack")
                        .tag(SidebarItem.gallery)
                }
                Section("Moje kafelki") {
                    ForEach(store.library.designs) { d in
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color(hex: d.style.color1))
                                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.15)))
                                Image(systemName: d.kind.symbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: d.style.accentColor))
                            }
                            .frame(width: 22, height: 22)
                            Text(d.name).lineLimit(1)
                        }
                        .tag(SidebarItem.design(d.id))
                        .contextMenu {
                            Button("Duplikuj") {
                                if let c = store.duplicate(d.id) { nav.selection = .design(c.id) }
                            }
                            Button("Usuń", role: .destructive) {
                                store.delete(d.id)
                                nav.selection = .gallery
                            }
                        }
                    }
                    .onMove { store.move(from: $0, to: $1) }
                }
                Section("Więcej") {
                    Label("Harmonogramy", systemImage: "clock.arrow.2.circlepath").tag(SidebarItem.schedules)
                    Label("Kafelki na pulpicie", systemImage: "macwindow.on.rectangle").tag(SidebarItem.desktop)
                    Label("Konta AI", systemImage: "gauge.with.dots.needle.67percent").tag(SidebarItem.accounts)
                    Label("Ustawienia", systemImage: "gearshape").tag(SidebarItem.settings)
                    Label("Jak dodać widżet?", systemImage: "questionmark.circle").tag(SidebarItem.help)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
            .safeAreaInset(edge: .bottom) {
                if let rel = updater.available {
                    Button {
                        Task { await updater.install() }
                    } label: {
                        Label("Aktualizuj do \(rel.tag)", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(10)
                }
            }
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nav.selection = .gallery
                } label: {
                    Label("Nowy kafelek", systemImage: "plus")
                }
                .help("Nowy kafelek z galerii")
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch nav.selection ?? .gallery {
        case .gallery:
            GalleryView()
        case .design(let id):
            if store.design(id) != nil {
                EditorView(designID: id).id(id)
            } else {
                GalleryView()
            }
        case .schedules:
            SchedulesView()
        case .desktop:
            DesktopView()
        case .accounts:
            AccountsView()
        case .settings:
            SettingsView()
        case .help:
            HelpView()
        }
    }
}

// MARK: - Galeria

struct GalleryView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @State private var filter: DesignKind?

    private func previewSize(_ t: Design) -> KafelekSize {
        switch t.kind {
        case .ai, .weather: return .medium
        case .calendar: return t.calendar.style == .month ? .medium : .small
        case .crypto: return t.crypto.symbols.count > 1 ? .medium : .small
        default: return .small
        }
    }

    private var templates: [Design] {
        Templates.all.filter { filter == nil || $0.kind == filter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Galeria wzorów").font(.largeTitle.bold())
                    Text("Kliknij wzór, żeby dodać go do swoich kafelków i dowolnie przerobić. Kafelków możesz mieć ile chcesz.")
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "Wszystkie", selected: filter == nil) { filter = nil }
                        ForEach(DesignKind.allCases) { k in
                            FilterChip(title: k.title, symbol: k.symbol, selected: filter == k) { filter = k }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 400), spacing: 18)], spacing: 22) {
                    ForEach(templates) { t in
                        Button {
                            let d = store.add(from: t)
                            Navigation.shared.selection = .design(d.id)
                        } label: {
                            VStack(spacing: 8) {
                                let size = previewSize(t)
                                KafelekTile(design: t, ctx: RenderContext(now: Date(), size: size, snapshot: hub.snapshot,
                                                                         photos: [:], isWidget: false, interactive: false))
                                    .scaleEffect(0.62)
                                    .frame(width: size.points.width * 0.62, height: size.points.height * 0.62)
                                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                                Text(t.name).font(.callout.weight(.medium))
                                Text(t.kind.title).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct FilterChip: View {
    let title: String
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.callout)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.15)))
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
