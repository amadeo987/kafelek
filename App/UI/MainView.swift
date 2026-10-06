import SwiftUI

struct MainView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var nav = Navigation.shared
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.selection) {
                Label("Moje widżety", systemImage: "square.grid.2x2").tag(SidebarItem.gallery)
                Label("Harmonogramy", systemImage: "clock.arrow.2.circlepath").tag(SidebarItem.schedules)
                Label("Kafelki pływające", systemImage: "macwindow.on.rectangle").tag(SidebarItem.desktop)
                Label("Konta AI", systemImage: "gauge.with.dots.needle.67percent").tag(SidebarItem.accounts)
                Label("Ustawienia", systemImage: "gearshape").tag(SidebarItem.settings)
                Label("Jak dodać widżet?", systemImage: "questionmark.circle").tag(SidebarItem.help)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 210)
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
    }

    @ViewBuilder private var detail: some View {
        switch nav.selection ?? .gallery {
        case .gallery:
            HomeView()
        case .design(let id):
            if store.design(id) != nil {
                EditorView(designID: id).id(id)
            } else {
                HomeView()
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

// MARK: - Moje widżety

struct HomeView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    @State private var showNew = false

    private let scale: CGFloat = 0.62

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Moje widżety").font(.largeTitle.bold())
                        Text("Kliknij widżet, żeby go edytować. Na pulpit: prawy klik na tapecie → Edytuj widżety → Kafelek.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    .help("Nowy widżet")
                    .keyboardShortcut("n", modifiers: .command)
                }

                if store.library.designs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("Nie masz jeszcze widżetów").font(.title3.weight(.semibold))
                        Button("Utwórz pierwszy widżet") { showNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                }

                ForEach(KafelekSize.allCases) { size in
                    let list = store.library.designs.filter { $0.size == size }
                    if !list.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(size.name) \(size.label)")
                                .font(.title3.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: size.points.width * scale, maximum: size.points.width * scale + 30),
                                                         spacing: 18, alignment: .leading)],
                                      alignment: .leading, spacing: 18) {
                                ForEach(list) { d in cell(d) }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showNew) {
            NewWidgetSheet { design in
                Navigation.shared.selection = .design(design.id)
            }
        }
    }

    private func cell(_ d: Design) -> some View {
        Button {
            Navigation.shared.selection = .design(d.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                KafelekTile(design: d, ctx: RenderContext(now: Date(), size: d.size, snapshot: hub.snapshot,
                                                          photos: PhotoStore.images(for: [d]), isWidget: false, interactive: false))
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: d.size.points.width * scale, height: d.size.points.height * scale, alignment: .topLeading)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                Text(d.name)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(width: d.size.points.width * scale, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edytuj") { Navigation.shared.selection = .design(d.id) }
            Button("Duplikuj") { store.duplicate(d.id) }
            Divider()
            Button("Usuń", role: .destructive) { store.delete(d.id) }
        }
    }
}

// MARK: - Nowy widżet: rozmiar → rodzaj

struct NewWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var hub = DataHub.shared
    let onCreate: (Design) -> Void

    @State private var size: KafelekSize?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if size != nil {
                    Button { size = nil } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                } else {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                }
                Spacer()
                Text(size.map { "Wybierz widżet – \($0.name) \($0.label)" } ?? "Wybierz rozmiar")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .opacity(size == nil ? 0 : 1)
            }
            .padding(16)
            Divider()
            if let size {
                typeList(size)
            } else {
                sizeList
            }
        }
        .frame(width: 600, height: 640)
    }

    private var sizeList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(KafelekSize.allCases) { s in
                    Button {
                        size = s
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.title3.weight(.medium))
                                Text(s.label).foregroundStyle(.secondary)
                            }
                            Spacer()
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.gradient)
                                .frame(width: s.points.width * 0.42, height: s.points.height * 0.42)
                                .overlay(Image(systemName: "square.grid.2x2.fill").foregroundStyle(.white.opacity(0.9)))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private func typeList(_ size: KafelekSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Templates.categories) { cat in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(cat.title, systemImage: cat.symbol)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            ForEach(cat.items) { t in
                                Button {
                                    let d = store.add(from: t, size: size)
                                    onCreate(d)
                                    dismiss()
                                } label: {
                                    row(t, size: size)
                                }
                                .buttonStyle(.plain)
                                if t.id != cat.items.last?.id { Divider().padding(.leading, 84) }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.secondary.opacity(0.08)))
                    }
                }
            }
            .padding(18)
        }
    }

    private func row(_ t: Design, size: KafelekSize) -> some View {
        let box: CGFloat = 60
        let pts = size.points
        let sc = min(box / pts.width, box / pts.height)
        return HStack(spacing: 14) {
            KafelekTile(design: t, ctx: RenderContext(now: Date(), size: size, snapshot: hub.snapshot,
                                                     photos: [:], isWidget: false, interactive: false))
                .scaleEffect(sc)
                .frame(width: pts.width * sc, height: pts.height * sc)
                .frame(width: 70, height: box)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(.body.weight(.medium))
                Text(t.kind.title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
