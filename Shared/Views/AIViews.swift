import SwiftUI

// MARK: - Limity Claude / Codex – minimalistycznie

private struct AIItem: Identifiable {
    let provider: AIProvider
    let isSession: Bool
    let usage: ProviderUsage?

    var id: String { provider.rawValue + (isSession ? "-s" : "-w") }
    var window: LimitWindow? { isSession ? usage?.session : usage?.weekly }
    var metricName: String { isSession ? "Sesja" : "Tydzień" }
    var metricShort: String { isSession ? "5h" : "7d" }
    var color: Color { Color(hex: provider.colorHex) }
}

struct AITile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }
    private var o: AIOptions { d.ai }

    private var providers: [AIProvider] {
        switch o.providers {
        case .both: [.claude, .codex]
        case .claude: [.claude]
        case .codex: [.codex]
        }
    }

    private var metrics: [Bool] {
        switch o.metric {
        case .both: [true, false]
        case .session: [true]
        case .weekly: [false]
        }
    }

    private func usage(_ p: AIProvider) -> ProviderUsage? {
        p == .claude ? ctx.snapshot.claude : ctx.snapshot.codex
    }

    private func items(_ p: AIProvider) -> [AIItem] {
        metrics.map { AIItem(provider: p, isSession: $0, usage: usage(p)) }
    }

    private var allItems: [AIItem] { providers.flatMap { items($0) } }

    private func value(_ w: LimitWindow?) -> Double {
        guard let w else { return 0 }
        return o.showRemaining ? w.remainingPercent : w.usedPercent
    }

    private func valueText(_ w: LimitWindow?) -> String {
        guard w != nil else { return "–" }
        return Fmt.percent(value(w))
    }

    /// Kolor liczby – ostrzega dopiero przy niskim zapasie.
    private func valueColor(_ w: LimitWindow?) -> Color {
        guard let w else { return s.tertiary }
        if w.remainingPercent < 10 { return Color(hex: "#FF453A") }
        return s.text
    }

    private func resetLong(_ w: LimitWindow?) -> String {
        guard o.showResets, let r = w?.resetsAt else { return "" }
        return "reset " + Fmt.until(r, now: ctx.now)
    }

    private func resetShort(_ w: LimitWindow?) -> String {
        guard o.showResets, let r = w?.resetsAt else { return "" }
        return Fmt.compactUntil(r, now: ctx.now)
    }

    var body: some View {
        if allItems.allSatisfy({ $0.usage == nil }) {
            TileMessage(symbol: "gauge.with.dots.needle.33percent", title: "Brak danych",
                        detail: "Otwórz Kafelek → Konta AI", style: s)
        } else {
            switch o.display {
            case .bars: bars
            case .rings: rings
            }
        }
    }

    // MARK: - Paski

    private func bar(_ it: AIItem, height: CGFloat) -> some View {
        BarView(progress: value(it.window) / 100, color: it.color, track: s.text.opacity(0.12), height: height)
    }

    private func providerName(_ p: AIProvider, size: CGFloat) -> some View {
        Text(p.title)
            .font(s.caption(size, .semibold))
            .foregroundStyle(Color(hex: p.colorHex))
            .lineLimit(1)
    }

    /// Wiersz: „Sesja · 2h 4m        72%” + cienki pasek.
    private func compactRow(_ it: AIItem, label: String? = nil, barHeight: CGFloat = 4) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label ?? it.metricName)
                    .font(s.caption(10.5, .medium))
                    .foregroundStyle(s.secondary)
                if !resetShort(it.window).isEmpty {
                    Text("· " + resetShort(it.window))
                        .font(s.caption(10))
                        .foregroundStyle(s.tertiary)
                }
                Spacer(minLength: 2)
                Text(valueText(it.window))
                    .font(s.font(14, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor(it.window))
            }
            bar(it, height: barHeight)
        }
    }

    /// Kolumna: etykieta, duża liczba, pasek, reset.
    private func bigColumn(_ it: AIItem, number: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(it.metricName)
                .font(s.caption(11, .medium))
                .foregroundStyle(s.secondary)
            Text(valueText(it.window))
                .font(s.font(number, .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor(it.window))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            bar(it, height: 5)
            Text(resetLong(it.window).isEmpty ? " " : resetLong(it.window))
                .font(s.caption(10))
                .foregroundStyle(s.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var bars: some View {
        switch ctx.size {
        case .small: barsSmall
        case .medium: barsMedium
        case .large, .extraLarge: barsLarge
        }
    }

    @ViewBuilder private var barsSmall: some View {
        if providers.count == 1, let p = providers.first {
            let list = items(p)
            VStack(alignment: .leading, spacing: 0) {
                providerName(p, size: 13)
                Spacer(minLength: 0)
                if list.count == 1, let it = list.first {
                    Text(valueText(it.window))
                        .font(s.font(42, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(valueColor(it.window))
                    Text(it.metricName.lowercased() + (resetShort(it.window).isEmpty ? "" : " · " + resetShort(it.window)))
                        .font(s.caption(11))
                        .foregroundStyle(s.secondary)
                        .padding(.bottom, 8)
                    bar(it, height: 5)
                } else {
                    VStack(spacing: 12) {
                        ForEach(list) { it in compactRow(it) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: metrics.count == 1 ? 14 : 9) {
                ForEach(providers, id: \.self) { p in
                    if metrics.count == 1, let it = items(p).first {
                        compactRow(it, label: p.title)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            providerName(p, size: 11)
                            ForEach(items(p)) { it in
                                HStack(spacing: 6) {
                                    Text(it.metricShort)
                                        .font(s.caption(9.5, .medium))
                                        .foregroundStyle(s.tertiary)
                                        .frame(width: 16, alignment: .leading)
                                    bar(it, height: 4)
                                    Text(valueText(it.window))
                                        .font(s.caption(11, .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(valueColor(it.window))
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var barsMedium: some View {
        if providers.count == 1, let p = providers.first {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    providerName(p, size: 14)
                    Spacer()
                    if let plan = usage(p)?.plan, !plan.isEmpty {
                        Text(plan.capitalized).font(s.caption(10, .medium)).foregroundStyle(s.tertiary)
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 22) {
                    ForEach(items(p)) { it in bigColumn(it, number: 34) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 18) {
                ForEach(providers, id: \.self) { p in
                    VStack(alignment: .leading, spacing: 10) {
                        providerName(p, size: 13)
                        Spacer(minLength: 0)
                        ForEach(items(p)) { it in compactRow(it, barHeight: 5) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var barsLarge: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(providers.enumerated()), id: \.element) { index, p in
                if index > 0 {
                    Rectangle().fill(s.text.opacity(0.1)).frame(height: 0.5).padding(.vertical, 14)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        providerName(p, size: 14)
                        Spacer()
                        if let plan = usage(p)?.plan, !plan.isEmpty {
                            Text(plan.capitalized).font(s.caption(10, .medium)).foregroundStyle(s.tertiary)
                        }
                    }
                    HStack(alignment: .bottom, spacing: 22) {
                        ForEach(items(p)) { it in bigColumn(it, number: providers.count == 1 ? 48 : 34) }
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Pierścienie (jak systemowy widżet baterii)

    private func ring(_ it: AIItem, diameter: CGFloat, lineWidth: CGFloat, center: String, centerSize: CGFloat, centerColor: Color? = nil) -> some View {
        ZStack {
            Circle().stroke(s.text.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.002, min(1, value(it.window) / 100)))
                .stroke(it.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(center)
                .font(s.caption(centerSize, .semibold))
                .monospacedDigit()
                .foregroundStyle(centerColor ?? it.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(lineWidth + 2)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Pierścień z oznaczeniem w środku i procentem pod spodem.
    private func ringCell(_ it: AIItem, diameter: CGFloat, lineWidth: CGFloat, caption: Bool) -> some View {
        VStack(spacing: 5) {
            ring(it, diameter: diameter, lineWidth: lineWidth, center: it.metricShort, centerSize: diameter * 0.2)
            Text(valueText(it.window))
                .font(s.font(diameter * 0.24, .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor(it.window))
            if caption {
                Text(it.provider.title)
                    .font(s.caption(9.5, .medium))
                    .foregroundStyle(s.tertiary)
            }
        }
    }

    @ViewBuilder private var rings: some View {
        let list = allItems
        switch ctx.size {
        case .small:
            if list.count == 1, let it = list.first {
                VStack(spacing: 8) {
                    ring(it, diameter: 96, lineWidth: 9, center: valueText(it.window), centerSize: 24, centerColor: valueColor(it.window))
                    Text(it.provider.title + " · " + it.metricName.lowercased())
                        .font(s.caption(11, .medium))
                        .foregroundStyle(s.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if list.count == 2 {
                HStack(spacing: 14) {
                    ForEach(list) { it in ringCell(it, diameter: 58, lineWidth: 6, caption: providers.count > 1) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(providers, id: \.self) { p in
                        HStack(spacing: 18) {
                            ForEach(items(p)) { it in
                                VStack(spacing: 3) {
                                    ring(it, diameter: 44, lineWidth: 5, center: valueText(it.window), centerSize: 11, centerColor: s.text)
                                    Text(it.metricShort)
                                        .font(s.caption(9, .medium))
                                        .foregroundStyle(s.tertiary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .medium:
            HStack(spacing: 0) {
                ForEach(list) { it in
                    ringCell(it, diameter: list.count > 2 ? 62 : 74, lineWidth: list.count > 2 ? 6 : 7, caption: providers.count > 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 16) {
                ForEach(providers, id: \.self) { p in
                    VStack(alignment: .leading, spacing: 10) {
                        providerName(p, size: 13)
                        HStack(spacing: 0) {
                            ForEach(items(p)) { it in
                                HStack(spacing: 12) {
                                    ring(it, diameter: 74, lineWidth: 7, center: valueText(it.window), centerSize: 18, centerColor: valueColor(it.window))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(it.metricName).font(s.caption(12, .medium))
                                        Text(resetLong(it.window))
                                            .font(s.caption(10))
                                            .foregroundStyle(s.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        let dates = providers.compactMap { usage($0)?.updatedAt }
        let errors = providers.compactMap { p -> String? in
            guard let u = usage(p), u.session == nil, let e = u.error else { return nil }
            return p.title + ": " + e
        }
        return Text(errors.first ?? dates.min().map { "aktualizacja " + Fmt.time($0) } ?? "")
            .font(s.caption(9.5))
            .foregroundStyle(s.tertiary)
            .lineLimit(1)
    }
}
