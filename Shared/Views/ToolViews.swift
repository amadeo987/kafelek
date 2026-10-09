import SwiftUI

// MARK: - Skróty i akcje

/// Adres, który widżet otwiera po kliknięciu – obsługuje go aplikacja Kafelek.
enum ActionURL {
    static func make(design: UUID, action: UUID) -> URL {
        URL(string: "kafelek://action?d=\(design.uuidString)&a=\(action.uuidString)")!
    }
}

struct ShortcutsTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    private var columns: Int {
        switch ctx.size {
        case .small: 2
        case .medium: 4
        case .large: 3
        case .extraLarge: 6
        }
    }

    private var maxCount: Int {
        switch ctx.size {
        case .small: 4
        case .medium: 8
        case .large: 9
        case .extraLarge: 12
        }
    }

    private var rows: [[ActionItem]] {
        let list = Array(d.shortcuts.actions.prefix(maxCount))
        return stride(from: 0, to: list.count, by: columns).map { Array(list[$0..<min($0 + columns, list.count)]) }
    }

    var body: some View {
        if d.shortcuts.actions.isEmpty {
            TileMessage(symbol: "bolt.square", title: "Dodaj akcje", detail: "skróty, aplikacje, linki – w aplikacji Kafelek", style: s)
        } else {
            VStack(spacing: 8) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(rows[r]) { a in
                            if ctx.interactive {
                                Link(destination: ActionURL.make(design: d.id, action: a.id)) { cell(a) }
                            } else {
                                cell(a)
                            }
                        }
                        if rows[r].count < columns {
                            ForEach(0..<(columns - rows[r].count), id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cell(_ a: ActionItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if let id = a.iconID, let img = ctx.photos[id] {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: a.colorHex))
                    Image(systemName: a.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            if d.shortcuts.showLabels {
                Text(a.title)
                    .font(s.caption(10, .medium))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - System Maca

struct SystemTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    private struct Item: Identifiable {
        let metric: SystemMetric
        let value: Double?
        let detail: String
        let color: Color
        var id: String { metric.rawValue }
    }

    private func gb(_ bytes: Double) -> String {
        let g = bytes / 1_000_000_000
        return g >= 100 ? Fmt.number(g, decimals: 0) : Fmt.number(g, decimals: 1)
    }

    private var items: [Item] {
        let st = ctx.snapshot.system
        let b = ctx.snapshot.battery
        return d.system.metrics.map { m in
            switch m {
            case .cpu:
                return Item(metric: m, value: st?.cpu, detail: "procesor", color: Color(hex: "#64D2FF"))
            case .memory:
                return Item(metric: m, value: st?.memoryPercent,
                            detail: st.map { "\(gb($0.memoryUsed)) z \(gb($0.memoryTotal)) GB" } ?? "RAM",
                            color: Color(hex: "#BF5AF2"))
            case .disk:
                return Item(metric: m, value: st?.diskUsedPercent,
                            detail: st.map { "\(gb($0.diskFree)) GB wolne" } ?? "dysk",
                            color: Color(hex: "#FFD60A"))
            case .battery:
                let low = (b?.percent ?? 100) <= 20 && !(b?.charging ?? false)
                return Item(metric: m, value: b.map { Double($0.percent) },
                            detail: b.map { $0.charging ? "ładowanie" : ($0.onAC ? "zasilacz" : "bateria") } ?? "brak baterii",
                            color: low ? Color(hex: "#FF453A") : Color(hex: "#30D158"))
            }
        }
    }

    var body: some View {
        let list = items
        if list.isEmpty {
            TileMessage(symbol: "cpu", title: "Wybierz, co pokazać", style: s)
        } else if d.system.display == .rings {
            rings(list)
        } else {
            bars(list)
        }
    }

    private func ring(_ it: Item, diameter: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(s.text.opacity(0.12), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.002, min(1, (it.value ?? 0) / 100)))
                .stroke(it.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: it.metric.symbol)
                .font(.system(size: diameter * 0.28, weight: .medium))
                .foregroundStyle(s.secondary)
        }
        .frame(width: diameter, height: diameter)
    }

    private func percent(_ it: Item) -> String {
        it.value.map(Fmt.percent) ?? "–"
    }

    @ViewBuilder private func rings(_ list: [Item]) -> some View {
        switch ctx.size {
        case .small:
            let cols = list.count == 1 ? 1 : 2
            let dia: CGFloat = list.count == 1 ? 96 : (list.count <= 2 ? 58 : 44)
            let chunks = stride(from: 0, to: list.count, by: cols).map { Array(list[$0..<min($0 + cols, list.count)]) }
            VStack(spacing: 8) {
                ForEach(chunks.indices, id: \.self) { r in
                    HStack(spacing: 14) {
                        ForEach(chunks[r]) { it in
                            VStack(spacing: 3) {
                                ring(it, diameter: dia, line: dia > 50 ? 7 : 5)
                                Text(percent(it))
                                    .font(s.font(dia > 50 ? 16 : 12, .semibold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .medium:
            HStack(spacing: 0) {
                ForEach(list) { it in
                    VStack(spacing: 5) {
                        ring(it, diameter: 62, line: 6)
                        Text(percent(it)).font(s.font(16, .semibold)).monospacedDigit()
                        Text(it.metric.title).font(s.caption(9.5, .medium)).foregroundStyle(s.tertiary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .large, .extraLarge:
            VStack(spacing: 14) {
                ForEach(list) { it in
                    HStack(spacing: 14) {
                        ring(it, diameter: 58, line: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(it.metric.title).font(s.caption(12, .medium)).foregroundStyle(s.secondary)
                            Text(percent(it)).font(s.font(24, .semibold)).monospacedDigit()
                            Text(it.detail).font(s.caption(10)).foregroundStyle(s.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func bars(_ list: [Item]) -> some View {
        VStack(alignment: .leading, spacing: ctx.size == .small ? 9 : 12) {
            ForEach(list) { it in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(it.metric.title).font(s.caption(10.5, .medium)).foregroundStyle(s.secondary).lineLimit(1)
                        if ctx.size != .small {
                            Text("· " + it.detail).font(s.caption(10)).foregroundStyle(s.tertiary).lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        Text(percent(it)).font(s.font(14, .semibold)).monospacedDigit()
                    }
                    BarView(progress: (it.value ?? 0) / 100, color: it.color, track: s.text.opacity(0.12), height: 4)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
