import SwiftUI
import AppIntents

// MARK: - Kalendarz

struct CalendarTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }
    private var o: CalendarOptions { d.calendar }

    private var upcoming: [EventItem] {
        let horizon = Calendar.current.date(byAdding: .day, value: max(1, o.daysAhead), to: Calendar.current.startOfDay(for: ctx.now)) ?? ctx.now
        return ctx.snapshot.events
            .filter { $0.end > ctx.now && $0.start < horizon }
            .filter { o.calendarIDs.isEmpty || o.calendarIDs.contains($0.calendarID) }
            .filter { !(o.hideAllDay && $0.allDay) }
            .sorted { a, b in
                let cal = Calendar.current
                return (cal.startOfDay(for: a.start), a.allDay ? 0 : 1, a.start) < (cal.startOfDay(for: b.start), b.allDay ? 0 : 1, b.start)
            }
    }

    private var monthEvents: [EventItem] {
        ctx.snapshot.events.filter { o.calendarIDs.isEmpty || o.calendarIDs.contains($0.calendarID) }
    }

    var body: some View {
        if ctx.snapshot.calendarAccess == .denied {
            TileMessage(symbol: "calendar.badge.exclamationmark", title: "Brak dostępu do Kalendarza",
                        detail: "Ustawienia systemowe → Prywatność → Kalendarze → Kafelek", style: s)
        } else {
            switch o.style {
            case .next: next
            case .agenda: agenda
            case .month: month
            }
        }
    }

    @ViewBuilder private var next: some View {
        if let e = upcoming.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: e.colorHex)).frame(width: 8, height: 8)
                    Text(e.start <= ctx.now && !e.allDay ? "TERAZ" : Fmt.dayLabel(e.start, now: ctx.now).uppercased())
                        .font(s.caption(11, .bold))
                        .foregroundStyle(s.accent)
                    Spacer(minLength: 0)
                    if !e.allDay && e.start > ctx.now {
                        Text(Fmt.until(e.start, now: ctx.now))
                            .font(s.caption(10, .semibold))
                            .foregroundStyle(s.secondary)
                    }
                }
                Text(e.title)
                    .font(s.font(ctx.size == .small ? 19 : 24))
                    .lineLimit(ctx.size == .small ? 3 : 2)
                    .minimumScaleFactor(0.7)
                Text(Fmt.eventTime(e))
                    .font(s.caption(13, .medium))
                    .foregroundStyle(s.secondary)
                if (o.showLocation || ctx.size != .small), let loc = e.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.and.ellipse")
                        .font(s.caption(11))
                        .foregroundStyle(s.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if ctx.size != .small {
                    let rest = Array(upcoming.dropFirst().prefix(ctx.size.isTall ? 6 : 1))
                    ForEach(rest) { ev in EventRow(e: ev, style: s, now: ctx.now, showDay: true) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.weekday(ctx.now).uppercased())
                    .font(s.caption(11, .bold))
                    .foregroundStyle(s.accent)
                Text(Fmt.dayNumber(ctx.now))
                    .font(s.font(54))
                Spacer(minLength: 0)
                Text("Brak wydarzeń")
                    .font(s.caption(13, .semibold))
                    .foregroundStyle(s.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var maxRows: Int {
        switch ctx.size {
        case .small: 3
        case .medium: 4
        case .large, .extraLarge: 9
        }
    }

    @ViewBuilder private var agenda: some View {
        let items = Array(upcoming.prefix(maxRows))
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.weekday(ctx.now).uppercased())
                    .font(s.caption(11, .bold))
                    .foregroundStyle(s.accent)
                Spacer()
                Text(Fmt.dayNumber(ctx.now))
                    .font(s.font(ctx.size == .small ? 22 : 26))
            }
            if items.isEmpty {
                Spacer(minLength: 0)
                Text("Nic w kalendarzu 🎉")
                    .font(s.caption(13, .semibold))
                    .foregroundStyle(s.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                    let newDay = i == 0 || !Calendar.current.isDate(items[i - 1].start, inSameDayAs: e.start)
                    if newDay && ctx.size != .small && !Calendar.current.isDate(e.start, inSameDayAs: ctx.now) {
                        Text(Fmt.dayLabel(e.start, now: ctx.now).uppercased())
                            .font(s.caption(10, .bold))
                            .foregroundStyle(s.tertiary)
                            .padding(.top, 2)
                    }
                    EventRow(e: e, style: s, now: ctx.now, showDay: ctx.size == .small && !Calendar.current.isDate(e.start, inSameDayAs: ctx.now))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var month: some View {
        switch ctx.size {
        case .small:
            MonthGrid(now: ctx.now, style: s, events: monthEvents, compact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .medium:
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Fmt.weekday(ctx.now).uppercased())
                        .font(s.caption(11, .bold))
                        .foregroundStyle(s.accent)
                    Text(Fmt.dayNumber(ctx.now))
                        .font(s.font(36))
                    ForEach(Array(upcoming.prefix(2))) { e in
                        EventRow(e: e, style: s, now: ctx.now, showDay: !Calendar.current.isDate(e.start, inSameDayAs: ctx.now))
                    }
                    if upcoming.isEmpty {
                        Text("Brak wydarzeń").font(s.caption(12)).foregroundStyle(s.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MonthGrid(now: ctx.now, style: s, events: monthEvents, compact: true)
                    .frame(width: 150)
            }
        case .large, .extraLarge:
            VStack(alignment: .leading, spacing: 10) {
                MonthGrid(now: ctx.now, style: s, events: monthEvents, compact: false)
                Divider().overlay(s.tertiary)
                ForEach(Array(upcoming.prefix(4))) { e in
                    EventRow(e: e, style: s, now: ctx.now, showDay: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct EventRow: View {
    let e: EventItem
    let style: Style
    let now: Date
    var showDay = false

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: e.colorHex))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(e.title)
                    .font(style.font(13, .semibold))
                    .lineLimit(1)
                Text((showDay ? Fmt.dayLabel(e.start, now: now) + " · " : "") + Fmt.eventTime(e))
                    .font(style.caption(10.5))
                    .foregroundStyle(style.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(e.end < now ? 0.45 : 1)
    }
}

// MARK: - Przypomnienia

struct CompleteReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Odhacz przypomnienie"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Przypomnienie")
    var reminderID: String

    init() {}

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    func perform() async throws -> some IntentResult {
        await LocalAPI.post("/v1/reminders/complete?id=" + LocalAPI.query(reminderID))
        return .result()
    }
}

struct RemindersTile: View {
    let d: Design
    let ctx: RenderContext

    private var s: Style { d.style }
    private var o: RemindersOptions { d.reminders }

    private var items: [ReminderItem] {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: ctx.now)) ?? ctx.now
        return ctx.snapshot.reminders
            .filter { o.listIDs.isEmpty || o.listIDs.contains($0.listID) }
            .filter { !o.onlyDueToday || ($0.due.map { $0 < endOfToday } ?? false) }
            .sorted { a, b in
                switch (a.due, b.due) {
                case let (x?, y?): return x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.priority > b.priority
                }
            }
    }

    private var title: String {
        if !o.title.isEmpty { return o.title }
        if o.listIDs.count == 1, let l = ctx.snapshot.reminderLists.first(where: { $0.id == o.listIDs[0] }) { return l.title }
        return "Przypomnienia"
    }

    private var maxRows: Int {
        switch ctx.size {
        case .small: 4
        case .medium: 4
        case .large, .extraLarge: 10
        }
    }

    var body: some View {
        if ctx.snapshot.remindersAccess == .denied {
            TileMessage(symbol: "checklist", title: "Brak dostępu do Przypomnień",
                        detail: "Ustawienia systemowe → Prywatność → Przypomnienia → Kafelek", style: s)
        } else if o.style == .count {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "checklist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(s.accent)
                Spacer(minLength: 0)
                Text("\(items.count)")
                    .font(s.font(ctx.size == .small ? 58 : 72))
                    .lineLimit(1)
                Text(title)
                    .font(s.caption(13, .semibold))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: ctx.size == .small ? 5 : 7) {
                HStack {
                    Text(title.uppercased())
                        .font(s.caption(11, .bold))
                        .foregroundStyle(s.accent)
                        .lineLimit(1)
                    Spacer()
                    Text("\(items.count)")
                        .font(s.font(18, .bold))
                }
                if items.isEmpty {
                    Spacer(minLength: 0)
                    Label("Wszystko zrobione", systemImage: "checkmark.circle.fill")
                        .font(s.caption(13, .semibold))
                        .foregroundStyle(s.secondary)
                    Spacer(minLength: 0)
                } else {
                    let columns = ctx.size == .extraLarge ? 2 : 1
                    let shown = Array(items.prefix(maxRows * columns))
                    if columns == 2 {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(shown.prefix(maxRows))) { r in row(r) }
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(shown.dropFirst(maxRows))) { r in row(r) }
                            }
                        }
                    } else {
                        ForEach(shown) { r in row(r) }
                    }
                    Spacer(minLength: 0)
                    if items.count > shown.count {
                        Text("+ \(items.count - shown.count) więcej")
                            .font(s.caption(10, .semibold))
                            .foregroundStyle(s.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder private func row(_ r: ReminderItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if ctx.interactive {
                Button(intent: CompleteReminderIntent(reminderID: r.id)) {
                    Image(systemName: "circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: r.colorHex))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: r.colorHex))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(r.title)
                    .font(s.font(13, .medium))
                    .lineLimit(ctx.size == .small ? 1 : 2)
                if o.showDue, let due = r.due, ctx.size != .small {
                    Text(dueText(due, hasTime: r.dueHasTime))
                        .font(s.caption(10))
                        .foregroundStyle(due < ctx.now ? Color.red : s.secondary)
                }
            }
        }
    }

    private func dueText(_ due: Date, hasTime: Bool) -> String {
        let day = Fmt.dayLabel(due, now: ctx.now)
        return hasTime ? day + ", " + Fmt.time(due) : day
    }
}
