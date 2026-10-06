import SwiftUI

// MARK: - Limity Claude / Codex

private struct AIItem: Identifiable {
    let provider: AIProvider
    let isSession: Bool
    let usage: ProviderUsage?

    var id: String { provider.rawValue + (isSession ? "-s" : "-w") }
    var window: LimitWindow? { isSession ? usage?.session : usage?.weekly }
    var metricName: String { isSession ? "Sesja" : "Tydzień" }
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

    private var items: [AIItem] {
        providers.flatMap { p in metrics.map { AIItem(provider: p, isSession: $0, usage: usage(p)) } }
    }

    private func value(_ w: LimitWindow?) -> Double? {
        guard let w else { return nil }
        return o.showRemaining ? w.remainingPercent : w.usedPercent
    }

    private func valueText(_ w: LimitWindow?) -> String {
        value(w).map(Fmt.percent) ?? "—"
    }

    private func valueColor(_ w: LimitWindow?) -> Color {
        guard let w else { return s.secondary }
        if w.remainingPercent < 10 { return Color(hex: "#FF453A") }
        if w.remainingPercent < 25 { return Color(hex: "#FF9F0A") }
        return s.text
    }

    private func reset(_ w: LimitWindow?) -> String {
        guard o.showResets, let r = w?.resetsAt else { return "" }
        return "reset " + Fmt.until(r, now: ctx.now)
    }

    private func shortReset(_ w: LimitWindow?) -> String {
        guard o.showResets, let r = w?.resetsAt else { return " " }
        return Fmt.compactUntil(r, now: ctx.now)
    }

    var body: some View {
        if items.allSatisfy({ $0.usage == nil }) {
            TileMessage(symbol: "gauge.with.dots.needle.33percent", title: "Brak danych o limitach",
                        detail: "Otwórz Kafelek → Konta AI", style: s)
        } else {
            switch o.display {
            case .rings: rings
            case .bars: bars
            }
        }
    }

    // MARK: Pierścienie

    @ViewBuilder private var rings: some View {
        let list = items
        if ctx.size == .small {
            if list.count == 1, let it = list.first {
                VStack(spacing: 6) {
                    ringCell(it, diameter: 92, lineWidth: 10, big: true)
                    Text("\(it.provider.title) · \(it.metricName.lowercased())")
                        .font(s.caption(11, .semibold))
                        .foregroundStyle(s.secondary)
                    Text(reset(it.window))
                        .font(s.caption(10))
                        .foregroundStyle(s.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if list.count == 2 {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        ForEach(list) { it in
                            VStack(spacing: 4) {
                                ringCell(it, diameter: 62, lineWidth: 7, big: false)
                                Text(o.providers == .both ? it.provider.title : it.metricName)
                                    .font(s.caption(10, .semibold))
                                    .foregroundStyle(s.secondary)
                                Text(shortReset(it.window))
                                    .font(s.caption(9))
                                    .foregroundStyle(s.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(providers, id: \.self) { p in
                        HStack(spacing: 6) {
                            ForEach(list.filter { $0.provider == p }) { it in
                                ringCell(it, diameter: 48, lineWidth: 5, big: false)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    HStack {
                        ForEach(providers, id: \.self) { p in
                            Label(p.title, systemImage: p.symbol)
                                .font(s.caption(9, .semibold))
                                .foregroundStyle(Color(hex: p.colorHex))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if ctx.size == .medium {
            HStack(spacing: 8) {
                ForEach(list) { it in
                    VStack(spacing: 5) {
                        ringCell(it, diameter: list.count > 2 ? 62 : 84, lineWidth: list.count > 2 ? 7 : 9, big: list.count <= 2)
                        Text(list.count > 2 || o.providers == .both ? "\(it.provider.title) \(it.metricName.lowercased())" : it.metricName)
                            .font(s.caption(10, .semibold))
                            .foregroundStyle(s.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(shortReset(it.window))
                            .font(s.caption(9.5))
                            .foregroundStyle(s.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(providers, id: \.self) { p in
                    VStack(alignment: .leading, spacing: 8) {
                        providerHeader(p)
                        HStack(spacing: 14) {
                            ForEach(list.filter { $0.provider == p }) { it in
                                HStack(spacing: 10) {
                                    ringCell(it, diameter: ctx.size == .extraLarge ? 96 : 76, lineWidth: 9, big: true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(it.metricName).font(s.caption(13, .semibold))
                                        Text(o.showRemaining ? "pozostało" : "zużyte")
                                            .font(s.caption(10))
                                            .foregroundStyle(s.secondary)
                                        Text(reset(it.window))
                                            .font(s.caption(10))
                                            .foregroundStyle(s.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if p != providers.last { Divider().overlay(s.tertiary) }
                }
                Spacer(minLength: 0)
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func ringCell(_ it: AIItem, diameter: CGFloat, lineWidth: CGFloat, big: Bool) -> some View {
        ZStack {
            RingView(progress: (value(it.window) ?? 0) / 100, color: it.color, track: s.text.opacity(0.13), lineWidth: lineWidth)
            Text(valueText(it.window))
                .font(s.font(big ? diameter * 0.26 : diameter * 0.28, .bold))
                .monospacedDigit()
                .foregroundStyle(valueColor(it.window))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(lineWidth + 2)
        }
        .frame(width: diameter, height: diameter)
    }

    // MARK: Paski

    private var bars: some View {
        let list = items
        let compact = ctx.size == .small && list.count > 2
        return VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            if ctx.size != .small {
                HStack {
                    Text("LIMITY AI").font(s.caption(11, .bold)).foregroundStyle(s.accent)
                    Spacer()
                    Text(o.showRemaining ? "pozostało" : "zużyte").font(s.caption(10)).foregroundStyle(s.tertiary)
                }
            }
            ForEach(list) { it in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: it.provider.symbol)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(it.color)
                        Text(o.providers == .both ? "\(it.provider.title) · \(it.metricName.lowercased())" : it.metricName)
                            .font(s.caption(compact ? 10 : 11.5, .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(valueText(it.window))
                            .font(s.font(compact ? 12 : 14, .bold))
                            .monospacedDigit()
                            .foregroundStyle(valueColor(it.window))
                    }
                    BarView(progress: (value(it.window) ?? 0) / 100, color: it.color, track: s.text.opacity(0.13), height: compact ? 4 : 6)
                    if !compact && o.showResets {
                        Text(it.window == nil ? (it.usage?.error ?? "brak danych") : reset(it.window))
                            .font(s.caption(9.5))
                            .foregroundStyle(s.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            if ctx.size.isTall { footer }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func providerHeader(_ p: AIProvider) -> some View {
        HStack(spacing: 6) {
            Image(systemName: p.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: p.colorHex))
            Text(p.title).font(s.font(15, .bold))
            if let plan = usage(p)?.plan, !plan.isEmpty {
                Text(plan.capitalized)
                    .font(s.caption(10, .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(s.text.opacity(0.12)))
            }
            Spacer()
            if let err = usage(p)?.error, usage(p)?.session == nil {
                Text(err).font(s.caption(9)).foregroundStyle(Color(hex: "#FF9F0A")).lineLimit(1)
            }
        }
    }

    private var footer: some View {
        let dates = providers.compactMap { usage($0)?.updatedAt }
        return Text(dates.min().map { "Zaktualizowano " + Fmt.time($0) } ?? "")
            .font(s.caption(9.5))
            .foregroundStyle(s.tertiary)
    }
}
