import SwiftUI
import AppKit

/// Wszystko, czego potrzebuje widok kafelka do narysowania się.
struct RenderContext {
    var now: Date
    var size: KafelekSize
    var snapshot: Snapshot
    var photos: [String: NSImage] = [:]
    /// true = natywny widżet WidgetKit (bez sekund, interakcja przez AppIntent).
    var isWidget: Bool
    var interactive = true

    var showSeconds: Bool { !isWidget }
}

/// Treść kafelka (bez tła). Ta sama dla widżetu, podglądu i kafelka pływającego.
struct KafelekContent: View {
    let design: Design
    let ctx: RenderContext

    var body: some View {
        content
            .foregroundStyle(design.style.text)
            .tint(design.style.accent)
            .padding(design.kind == .photo ? 0 : design.style.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch design.kind {
        case .clock: ClockTile(d: design, ctx: ctx)
        case .date: DateTile(d: design, ctx: ctx)
        case .calendar: CalendarTile(d: design, ctx: ctx)
        case .reminders: RemindersTile(d: design, ctx: ctx)
        case .ai: AITile(d: design, ctx: ctx)
        case .note: NoteTile(d: design, ctx: ctx)
        case .countdown: CountdownTile(d: design, ctx: ctx)
        case .photo: PhotoTile(d: design, ctx: ctx)
        case .weather: WeatherTile(d: design, ctx: ctx)
        case .crypto: CryptoTile(d: design, ctx: ctx)
        case .battery: BatteryTile(d: design, ctx: ctx)
        case .astronomy: AstronomyTile(d: design, ctx: ctx)
        }
    }
}

struct KafelekBackground: View {
    let style: Style
    let ctx: RenderContext

    var body: some View {
        ZStack {
            switch style.background {
            case .solid:
                Color(hex: style.color1)
            case .gradient:
                LinearGradient(colors: [Color(hex: style.color1), Color(hex: style.color2)],
                               startPoint: startPoint, endPoint: endPoint)
            case .photo:
                if let id = style.photoID, let img = ctx.photos[id] {
                    Color(hex: style.color1)
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                    Color.black.opacity(style.photoDim)
                } else {
                    Color(hex: style.color1)
                }
            }
            if style.borderWidth > 0 {
                if ctx.isWidget {
                    ContainerRelativeShape()
                        .strokeBorder(Color(hex: style.borderColor), lineWidth: style.borderWidth)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(hex: style.borderColor), lineWidth: style.borderWidth)
                }
            }
        }
    }

    private var radians: Double { style.gradientAngle * .pi / 180 }
    private var startPoint: UnitPoint {
        UnitPoint(x: 0.5 - cos(radians) * 0.5, y: 0.5 - sin(radians) * 0.5)
    }
    private var endPoint: UnitPoint {
        UnitPoint(x: 0.5 + cos(radians) * 0.5, y: 0.5 + sin(radians) * 0.5)
    }
}

/// Kompletny kafelek z tłem i zaokrągleniem – do podglądu w aplikacji i na pulpicie.
struct KafelekTile: View {
    let design: Design
    let ctx: RenderContext
    var cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            KafelekBackground(style: design.style, ctx: ctx)
            KafelekContent(design: design, ctx: ctx)
        }
        .frame(width: ctx.size.points.width, height: ctx.size.points.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Komunikat w kafelku, gdy brakuje danych.
struct TileMessage: View {
    let symbol: String
    let title: String
    var detail: String = ""
    let style: Style

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(style.accent)
            Text(title)
                .font(style.caption(13, .semibold))
                .multilineTextAlignment(.center)
            if !detail.isEmpty {
                Text(detail)
                    .font(style.caption(10))
                    .foregroundStyle(style.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Pierścień postępu.
struct RingView: View {
    let progress: Double
    let color: Color
    var track: Color = .white.opacity(0.15)
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Pasek postępu.
struct BarView: View {
    let progress: Double
    let color: Color
    var track: Color = .white.opacity(0.15)
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(height, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: height)
    }
}

/// Wykres liniowy (np. kurs krypto, temperatura).
struct SparklineView: View {
    let values: [Double]
    let color: Color
    var lineWidth: CGFloat = 2
    var fill = true

    var body: some View {
        GeometryReader { geo in
            if values.count > 1, let minV = values.min(), let maxV = values.max() {
                let range = max(maxV - minV, 0.000001)
                let w = geo.size.width, h = geo.size.height
                let points: [CGPoint] = values.enumerated().map { i, v in
                    CGPoint(x: w * Double(i) / Double(values.count - 1), y: h - h * (v - minV) / range)
                }
                ZStack {
                    if fill {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h))
                            for pt in points { p.addLine(to: pt) }
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    }
                    Path { p in
                        p.move(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
