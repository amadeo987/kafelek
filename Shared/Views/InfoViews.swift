import SwiftUI

// MARK: - Notatka / cytat

struct NoteTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    private var base: CGFloat {
        let scale: Double = switch ctx.size {
        case .small: 1
        case .medium: 1.25
        case .large: 1.6
        case .extraLarge: 2
        }
        return CGFloat(d.note.baseSize * scale)
    }

    var body: some View {
        VStack(alignment: s.align.horizontal, spacing: 8) {
            Text(d.note.text)
                .font(s.font(base))
                .multilineTextAlignment(s.align.textAlignment)
                .lineSpacing(base * 0.06)
                .minimumScaleFactor(0.3)
            if !d.note.author.isEmpty {
                Text("— " + d.note.author)
                    .font(s.font(max(9, base * 0.38), .regular).italic())
                    .foregroundStyle(s.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.align.frameAlignment)
    }
}

// MARK: - Odliczanie

struct CountdownTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }
    private var o: CountdownOptions { d.countdown }

    var body: some View {
        let diff = o.target.timeIntervalSince(ctx.now)
        let past = diff < 0
        let secs = Int(abs(diff))
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let minutes = (secs % 3600) / 60
        VStack(alignment: s.align.horizontal, spacing: 2) {
            Text(o.title.uppercased())
                .font(s.caption(12, .bold))
                .foregroundStyle(s.accent)
                .lineLimit(1)
            Spacer(minLength: 0)
            if days > 0 || !o.showTime {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(past ? "+\(days)" : "\(days)")
                        .font(s.font(ctx.size == .small ? 58 : 76))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(dayWord(days))
                        .font(s.caption(15, .semibold))
                        .foregroundStyle(s.secondary)
                }
                if o.showTime || ctx.size != .small {
                    Text("\(hours) h \(minutes) min")
                        .font(s.caption(13, .medium))
                        .foregroundStyle(s.secondary)
                }
            } else {
                Text(String(format: "%02d:%02d", hours, minutes))
                    .font(s.font(ctx.size == .small ? 48 : 70))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Text(past ? "minęło od " + Fmt.string(o.target, "d MMM yyyy") : Fmt.string(o.target, o.showTime ? "d MMMM yyyy, HH:mm" : "d MMMM yyyy"))
                .font(s.caption(11))
                .foregroundStyle(s.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.align.frameAlignment)
    }

    private func dayWord(_ n: Int) -> String {
        if n == 1 { return "dzień" }
        return "dni"
    }
}

// MARK: - Zdjęcie

struct PhotoTile: View {
    let d: Design
    let ctx: RenderContext

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let id = d.photo.photoID, let img = ctx.photos[id] {
                GeometryReader { geo in
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: d.photo.fill ? .fill : .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                TileMessage(symbol: "photo.badge.plus", title: "Wybierz zdjęcie", detail: "w edytorze kafelka", style: d.style)
            }
            if !d.photo.caption.isEmpty {
                Text(d.photo.caption)
                    .font(d.style.font(ctx.size == .small ? 15 : 20))
                    .foregroundStyle(d.style.text)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(d.style.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

// MARK: - Pogoda

struct WeatherTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    var body: some View {
        if let w = ctx.snapshot.weather[d.weather.key] {
            content(w)
        } else {
            TileMessage(symbol: "cloud.sun", title: d.weather.placeName, detail: "Pobieram pogodę…", style: s)
        }
    }

    @ViewBuilder private func content(_ w: WeatherData) -> some View {
        let header = VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(d.weather.placeName)
                    .font(s.caption(13, .bold))
                    .lineLimit(1)
                Image(systemName: "location.fill").font(.system(size: 8)).foregroundStyle(s.secondary)
            }
            Text(Fmt.temp(w.temperature))
                .font(s.font(ctx.size == .small ? 44 : 50, .light))
                .lineLimit(1)
        }
        let summary = VStack(alignment: .leading, spacing: 2) {
            Image(systemName: WeatherCode.symbol(w.code, isDay: w.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 17))
            Text(WeatherCode.name(w.code))
                .font(s.caption(12, .semibold))
                .lineLimit(1)
            Text("H: \(Fmt.temp(w.high))  L: \(Fmt.temp(w.low))")
                .font(s.caption(12, .medium))
                .foregroundStyle(s.secondary)
        }
        switch ctx.size {
        case .small:
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 0)
                summary
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .medium:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    header
                    Spacer()
                    summary.frame(width: 140, alignment: .leading)
                }
                Spacer(minLength: 0)
                hourly(w, count: 6)
            }
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    header
                    Spacer()
                    summary.frame(width: 150, alignment: .leading)
                }
                hourly(w, count: ctx.size == .extraLarge ? 12 : 6)
                Divider().overlay(s.tertiary)
                daily(w)
                Spacer(minLength: 0)
            }
        }
    }

    private func hourly(_ w: WeatherData, count: Int) -> some View {
        let points = Array(w.hourly.filter { $0.time > ctx.now.addingTimeInterval(-3600) }.prefix(count))
        return HStack(spacing: 0) {
            ForEach(points, id: \.time) { h in
                VStack(spacing: 4) {
                    Text(Fmt.string(h.time, "HH"))
                        .font(s.caption(11, .semibold))
                        .foregroundStyle(s.secondary)
                    Image(systemName: WeatherCode.symbol(h.code, isDay: h.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                        .frame(height: 18)
                    Text(Fmt.temp(h.temperature))
                        .font(s.caption(13, .semibold))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func daily(_ w: WeatherData) -> some View {
        let days = Array(w.daily.prefix(5))
        let minT = days.map(\.low).min() ?? 0
        let maxT = days.map(\.high).max() ?? 1
        return VStack(spacing: 6) {
            ForEach(days, id: \.date) { day in
                HStack(spacing: 10) {
                    Text(Calendar.current.isDateInToday(day.date) ? "Dziś" : Fmt.weekdayShort(day.date).capitalized)
                        .font(s.caption(13, .semibold))
                        .frame(width: 44, alignment: .leading)
                    Image(systemName: WeatherCode.symbol(day.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14))
                        .frame(width: 24)
                    Text(Fmt.temp(day.low)).font(s.caption(12)).foregroundStyle(s.secondary).frame(width: 32, alignment: .trailing)
                    GeometryReader { geo in
                        let range = max(1, maxT - minT)
                        let x0 = geo.size.width * (day.low - minT) / range
                        let x1 = geo.size.width * (day.high - minT) / range
                        ZStack(alignment: .leading) {
                            Capsule().fill(s.text.opacity(0.12))
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#64D2FF"), Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, x1 - x0))
                                .offset(x: x0)
                        }
                    }
                    .frame(height: 5)
                    Text(Fmt.temp(day.high)).font(s.caption(12, .semibold)).frame(width: 32, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Krypto

struct CryptoTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    private struct Row: Identifiable {
        let id: String
        let quote: CryptoQuote?
    }

    private var quotes: [Row] {
        var seen = Set<String>()
        return d.crypto.symbols.compactMap { sym in
            let n = Fmt.normalizeCryptoSymbol(sym)
            guard !n.isEmpty, seen.insert(n).inserted else { return nil }
            return Row(id: n, quote: ctx.snapshot.crypto[n])
        }
    }

    var body: some View {
        let list = quotes
        if list.isEmpty {
            TileMessage(symbol: "bitcoinsign.circle", title: "Dodaj symbol", detail: "np. BTC, ETH, SOL", style: s)
        } else if ctx.size == .small || list.count == 1 {
            single(list[0].id, list[0].quote)
        } else {
            let rows = Array(list.prefix(ctx.size == .medium ? 3 : 7))
            VStack(spacing: ctx.size == .medium ? 6 : 10) {
                ForEach(rows) { item in row(item.id, item.quote) }
                Spacer(minLength: 0)
            }
        }
    }

    private func changeColor(_ q: CryptoQuote?) -> Color {
        guard let q else { return s.secondary }
        return q.changePercent >= 0 ? Color(hex: "#30D158") : Color(hex: "#FF453A")
    }

    private func changeText(_ q: CryptoQuote?) -> String {
        guard let q else { return "" }
        return (q.changePercent >= 0 ? "▲ " : "▼ ") + Fmt.number(abs(q.changePercent), decimals: 2) + "%"
    }

    private func single(_ sym: String, _ q: CryptoQuote?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(changeText(q).prefix(1))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(changeColor(q))
                Text(Fmt.cryptoName(sym))
                    .font(s.caption(13, .bold))
                Spacer(minLength: 0)
                if ctx.size != .small {
                    Text(changeText(q)).font(s.caption(12, .semibold)).foregroundStyle(changeColor(q))
                }
            }
            Text(q.map { Fmt.price($0.price) } ?? "—")
                .font(s.font(ctx.size == .small ? 26 : 36, .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if ctx.size == .small {
                Text(changeText(q)).font(s.caption(11, .semibold)).foregroundStyle(changeColor(q))
            }
            if d.crypto.showChart, let q, q.sparkline.count > 1 {
                SparklineView(values: q.sparkline, color: changeColor(q))
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 0)
            }
            Text("24 h · Binance")
                .font(s.caption(9))
                .foregroundStyle(s.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ sym: String, _ q: CryptoQuote?) -> some View {
        HStack(spacing: 10) {
            Text(Fmt.cryptoName(sym))
                .font(s.caption(13, .bold))
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)
            if d.crypto.showChart, let q, q.sparkline.count > 1 {
                SparklineView(values: q.sparkline, color: changeColor(q), lineWidth: 1.5, fill: false)
                    .frame(height: 22)
            } else {
                Spacer()
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text(q.map { Fmt.price($0.price) } ?? "—")
                    .font(s.font(14, .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(changeText(q))
                    .font(s.caption(10, .semibold))
                    .foregroundStyle(changeColor(q))
            }
            .frame(width: 96, alignment: .trailing)
        }
    }
}

// MARK: - Bateria

struct BatteryTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    var body: some View {
        if let b = ctx.snapshot.battery {
            let color: Color = b.percent <= 20 && !b.charging ? Color(hex: "#FF453A") : (b.charging ? Color(hex: "#30D158") : s.accent)
            let status = b.charging ? "Ładowanie" : (b.onAC ? "Zasilacz" : "Na baterii")
            if ctx.size == .small {
                VStack(spacing: 6) {
                    ZStack {
                        RingView(progress: Double(b.percent) / 100, color: color, track: s.text.opacity(0.13), lineWidth: 10)
                        VStack(spacing: 0) {
                            Image(systemName: b.charging ? "bolt.fill" : "laptopcomputer")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(color)
                            Text("\(b.percent)%").font(s.font(24, .bold)).monospacedDigit()
                        }
                    }
                    .frame(width: 100, height: 100)
                    Text(status).font(s.caption(11, .semibold)).foregroundStyle(s.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        RingView(progress: Double(b.percent) / 100, color: color, track: s.text.opacity(0.13), lineWidth: 12)
                        Image(systemName: b.charging ? "bolt.fill" : "laptopcomputer")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacBook").font(s.caption(12, .bold)).foregroundStyle(s.accent)
                        Text("\(b.percent)%").font(s.font(48, .bold)).monospacedDigit()
                        Text(status).font(s.caption(13, .semibold)).foregroundStyle(s.secondary)
                        if let m = b.minutesRemaining, m > 0 {
                            Text(b.charging ? "pełna za \(m / 60) h \(m % 60) min" : "zostało \(m / 60) h \(m % 60) min")
                                .font(s.caption(12))
                                .foregroundStyle(s.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            TileMessage(symbol: "battery.0percent", title: "Brak baterii", detail: "Ten Mac nie ma baterii", style: s)
        }
    }
}

// MARK: - Słońce i Księżyc

struct AstronomyTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }

    var body: some View {
        let moon = MoonPhase(date: ctx.now)
        let w = ctx.snapshot.weather[d.weather.key]
        if ctx.size == .small {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: moon.symbol)
                        .font(.system(size: 34))
                        .foregroundStyle(s.text)
                    Spacer()
                    Text(Fmt.percent(moon.illumination * 100))
                        .font(s.caption(12, .semibold))
                        .foregroundStyle(s.secondary)
                }
                Text(moon.name).font(s.font(15, .semibold)).lineLimit(2)
                Spacer(minLength: 0)
                if let w, let rise = w.sunrise, let sunset = w.sunset {
                    Label(Fmt.time(rise), systemImage: "sunrise.fill").font(s.caption(12, .semibold))
                    Label(Fmt.time(sunset), systemImage: "sunset.fill").font(s.caption(12, .semibold))
                } else {
                    Text("pełnia za \(moon.daysToFull) d").font(s.caption(11)).foregroundStyle(s.secondary)
                }
            }
            .symbolRenderingMode(.multicolor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: moon.symbol)
                        .font(.system(size: ctx.size == .medium ? 64 : 96))
                    Text(moon.name).font(s.font(14, .semibold))
                    Text("oświetlenie \(Fmt.percent(moon.illumination * 100)) · pełnia za \(moon.daysToFull) d")
                        .font(s.caption(10))
                        .foregroundStyle(s.secondary)
                }
                .frame(maxWidth: .infinity)
                if let w, let rise = w.sunrise, let sunset = w.sunset {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(d.weather.placeName.uppercased()).font(s.caption(11, .bold)).foregroundStyle(s.accent)
                        Label(Fmt.time(rise), systemImage: "sunrise.fill").font(s.font(18, .semibold))
                        Label(Fmt.time(sunset), systemImage: "sunset.fill").font(s.font(18, .semibold))
                        let len = Int(sunset.timeIntervalSince(rise)) / 60
                        Text("dzień trwa \(len / 60) h \(len % 60) min")
                            .font(s.caption(11))
                            .foregroundStyle(s.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .symbolRenderingMode(.multicolor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
