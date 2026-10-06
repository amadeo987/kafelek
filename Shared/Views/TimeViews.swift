import SwiftUI

// MARK: - Zegar

struct ClockTile: View {
    let d: Design
    let ctx: RenderContext

    private var o: ClockOptions { d.clock }
    private var s: Style { d.style }
    private var tz: TimeZone { o.timeZone.isEmpty ? .current : (TimeZone(identifier: o.timeZone) ?? .current) }
    private var seconds: Bool { o.showSeconds && ctx.showSeconds }

    var body: some View {
        switch o.style {
        case .digital: digital
        case .analog: analog
        case .stacked: stacked
        case .dual: dual
        }
    }

    private var timeText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(Fmt.time(ctx.now, use24h: o.use24h, seconds: seconds, tz: tz))
                .monospacedDigit()
            if !o.use24h {
                Text(Fmt.ampm(ctx.now, tz: tz))
                    .font(s.caption(ctx.size == .small ? 12 : 16, .semibold))
                    .foregroundStyle(s.secondary)
            }
        }
    }

    private var label: String {
        o.label.isEmpty ? (o.timeZone.isEmpty ? "" : Fmt.timeZoneName(o.timeZone)) : o.label
    }

    private var bigSize: CGFloat {
        switch ctx.size {
        case .small: seconds ? 34 : 46
        case .medium: seconds ? 58 : 72
        case .large: 84
        case .extraLarge: 120
        }
    }

    private var digital: some View {
        VStack(alignment: s.align.horizontal, spacing: 4) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(s.caption(11, .bold))
                    .foregroundStyle(s.accent)
            }
            Spacer(minLength: 0)
            timeText
                .font(s.font(bigSize))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if o.showDate {
                Text(ctx.size == .small ? Fmt.shortDate(ctx.now, tz: tz) : Fmt.longDate(ctx.now, tz: tz))
                    .font(s.caption(ctx.size == .small ? 12 : 15, .medium))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
            }
            if ctx.size.isTall {
                Spacer(minLength: 0)
                YearProgress(now: ctx.now, style: s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: s.align.horizontal, vertical: .center))
    }

    @ViewBuilder private var analog: some View {
        if ctx.size == .small || ctx.size == .large {
            VStack(spacing: 6) {
                AnalogClockFace(date: ctx.now, tz: tz, fg: s.text, tint: s.accent, showSeconds: seconds)
                if ctx.size == .large && o.showDate {
                    Text(Fmt.longDate(ctx.now, tz: tz))
                        .font(s.font(18, .semibold))
                        .foregroundStyle(s.secondary)
                }
            }
        } else {
            HStack(spacing: 16) {
                AnalogClockFace(date: ctx.now, tz: tz, fg: s.text, tint: s.accent, showSeconds: seconds)
                VStack(alignment: .leading, spacing: 4) {
                    if !label.isEmpty {
                        Text(label.uppercased()).font(s.caption(11, .bold)).foregroundStyle(s.accent)
                    }
                    timeText.font(s.font(40)).lineLimit(1).minimumScaleFactor(0.5)
                    if o.showDate {
                        Text(Fmt.longDate(ctx.now, tz: tz))
                            .font(s.caption(13))
                            .foregroundStyle(s.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var stacked: some View {
        let hh = Fmt.string(ctx.now, o.use24h ? "HH" : "hh", tz: tz)
        let mm = Fmt.string(ctx.now, "mm", tz: tz)
        if ctx.size == .small || ctx.size == .large {
            VStack(spacing: -8) {
                Text(hh)
                Text(mm).foregroundStyle(s.accent)
            }
            .font(s.font(ctx.size == .small ? 64 : 140))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 6) {
                Text(hh)
                Text(":").foregroundStyle(s.tertiary)
                Text(mm).foregroundStyle(s.accent)
            }
            .font(s.font(ctx.size == .medium ? 96 : 180))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var dual: some View {
        let other = TimeZone(identifier: o.secondTimeZone) ?? .current
        let zones: [(String, TimeZone)] = [(label.isEmpty ? "Tutaj" : label, tz), (Fmt.timeZoneName(o.secondTimeZone), other)]
        if ctx.size == .small {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(zones.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(zones[i].0.uppercased())
                            .font(s.caption(10, .bold))
                            .foregroundStyle(i == 0 ? s.accent : s.secondary)
                            .lineLimit(1)
                        Text(Fmt.time(ctx.now, use24h: o.use24h, tz: zones[i].1))
                            .font(s.font(32))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 12) {
                ForEach(zones.indices, id: \.self) { i in
                    VStack(spacing: 6) {
                        if ctx.size != .medium {
                            AnalogClockFace(date: ctx.now, tz: zones[i].1, fg: s.text, tint: s.accent, showSeconds: seconds)
                        }
                        Text(Fmt.time(ctx.now, use24h: o.use24h, tz: zones[i].1))
                            .font(s.font(ctx.size == .medium ? 40 : 32))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(zones[i].0)
                            .font(s.caption(12, .semibold))
                            .foregroundStyle(i == 0 ? s.accent : s.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct AnalogClockFace: View {
    let date: Date
    let tz: TimeZone
    let fg: Color
    let tint: Color
    let showSeconds: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let parts = components
            ZStack {
                Circle().stroke(fg.opacity(0.18), lineWidth: side * 0.02)
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(fg.opacity(i % 3 == 0 ? 0.9 : 0.35))
                        .frame(width: side * (i % 3 == 0 ? 0.03 : 0.018), height: side * (i % 3 == 0 ? 0.09 : 0.06))
                        .offset(y: -side * 0.40)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                hand(side: side, length: 0.25, width: 0.05, angle: parts.hour, color: fg)
                hand(side: side, length: 0.36, width: 0.032, angle: parts.minute, color: fg)
                if showSeconds {
                    hand(side: side, length: 0.40, width: 0.012, angle: parts.second, color: tint)
                }
                Circle().fill(tint).frame(width: side * 0.065, height: side * 0.065)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private var components: (hour: Double, minute: Double, second: Double) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = Double((c.hour ?? 0) % 12), m = Double(c.minute ?? 0), sec = Double(c.second ?? 0)
        return (h * 30 + m * 0.5, m * 6 + sec * 0.1, sec * 6)
    }

    private func hand(side: CGFloat, length: CGFloat, width: CGFloat, angle: Double, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: side * width, height: side * length)
            .offset(y: -side * length / 2)
            .rotationEffect(.degrees(angle))
    }
}

struct YearProgress: View {
    let now: Date
    let style: Style

    var body: some View {
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
        let p = now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Rok \(String(year))").font(style.caption(11, .semibold))
                Spacer()
                Text(Fmt.percent(p * 100)).font(style.caption(11, .semibold)).foregroundStyle(style.accent)
            }
            BarView(progress: p, color: style.accent, track: style.text.opacity(0.15))
        }
    }
}

// MARK: - Data

struct DateTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    var body: some View {
        switch d.date.style {
        case .dayBig: dayBig
        case .full: full
        case .week: week
        }
    }

    @ViewBuilder private var dayBig: some View {
        if ctx.size == .small {
            VStack(alignment: s.align.horizontal, spacing: 0) {
                Text(Fmt.weekday(ctx.now).uppercased())
                    .font(s.caption(12, .bold))
                    .foregroundStyle(s.accent)
                Text(Fmt.dayNumber(ctx.now))
                    .font(s.font(78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(Fmt.monthName(ctx.now).capitalized)
                    .font(s.caption(14, .semibold))
                    .foregroundStyle(s.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.align.frameAlignment)
        } else {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.weekday(ctx.now).uppercased())
                        .font(s.caption(13, .bold))
                        .foregroundStyle(s.accent)
                    Text(Fmt.dayNumber(ctx.now))
                        .font(s.font(ctx.size == .medium ? 84 : 120))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(Fmt.monthName(ctx.now).capitalized + " " + Fmt.string(ctx.now, "yyyy"))
                        .font(s.caption(15, .semibold))
                        .foregroundStyle(s.secondary)
                }
                MonthGrid(now: ctx.now, style: s, events: [], compact: ctx.size == .medium)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var full: some View {
        VStack(alignment: s.align.horizontal, spacing: 4) {
            Text(Fmt.weekday(ctx.now).capitalized)
                .font(s.font(ctx.size == .small ? 26 : 40))
                .foregroundStyle(s.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(Fmt.string(ctx.now, "d MMMM"))
                .font(s.font(ctx.size == .small ? 22 : 34))
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(s.align.textAlignment)
            Text(Fmt.string(ctx.now, "yyyy"))
                .font(s.caption(14, .semibold))
                .foregroundStyle(s.secondary)
            if ctx.size.isTall {
                Spacer(minLength: 0)
                YearProgress(now: ctx.now, style: s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.align.frameAlignment)
    }

    private var week: some View {
        let cal = Fmt.calendar
        let week = cal.component(.weekOfYear, from: ctx.now)
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: ctx.now) ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            Text("TYDZIEŃ")
                .font(s.caption(12, .bold))
                .foregroundStyle(s.accent)
            Text("\(week)")
                .font(s.font(ctx.size == .small ? 64 : 90))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("dzień \(dayOfYear) roku")
                .font(s.caption(12))
                .foregroundStyle(s.secondary)
            Spacer(minLength: 0)
            YearProgress(now: ctx.now, style: s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Siatka miesiąca (pon–niedz) z kropkami dni z wydarzeniami.
struct MonthGrid: View {
    let now: Date
    let style: Style
    let events: [EventItem]
    var compact = false
    var showTitle = true

    var body: some View {
        let cal = Fmt.calendar
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let days = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let weekday = cal.component(.weekday, from: monthStart) // 1 = niedziela
        let offset = (weekday + 5) % 7
        let cells: [Int?] = Array(repeating: nil, count: offset) + (1...days).map { Optional($0) }
        let rows = Int(ceil(Double(cells.count) / 7.0))
        let today = cal.component(.day, from: now)
        let eventDays = Set(events.compactMap { e -> Int? in
            guard cal.isDate(e.start, equalTo: now, toGranularity: .month) else { return nil }
            return cal.component(.day, from: e.start)
        })
        let fs: CGFloat = compact ? 9 : 11
        VStack(spacing: compact ? 2 : 4) {
            if showTitle {
                Text(Fmt.monthName(now).uppercased())
                    .font(style.caption(fs + 1, .bold))
                    .foregroundStyle(style.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 0) {
                ForEach(["P", "W", "Ś", "C", "P", "S", "N"].indices, id: \.self) { i in
                    Text(["P", "W", "Ś", "C", "P", "S", "N"][i])
                        .font(style.caption(fs, .bold))
                        .foregroundStyle(i >= 5 ? style.tertiary : style.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        let idx = r * 7 + c
                        let day: Int? = idx < cells.count ? cells[idx] : nil
                        ZStack {
                            if let day {
                                if day == today {
                                    Circle().fill(style.accent)
                                }
                                Text("\(day)")
                                    .font(style.caption(fs, day == today ? .bold : .medium))
                                    .foregroundStyle(day == today ? Color.white : (c >= 5 ? style.secondary : style.text))
                                if eventDays.contains(day) && day != today {
                                    Circle().fill(style.accent)
                                        .frame(width: 3, height: 3)
                                        .offset(y: fs * 0.85)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: fs * 1.75)
                    }
                }
            }
        }
    }
}
