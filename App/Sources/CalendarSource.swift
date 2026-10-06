import Foundation
import EventKit
import AppKit

/// Kalendarz i Przypomnienia Apple (EventKit).
final class CalendarSource {
    let store = EKEventStore()

    func access(_ type: EKEntityType) -> AccessState {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess, .authorized: return .granted
        case .notDetermined: return .unknown
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .unknown
        }
    }

    func requestAccess(_ type: EKEntityType) async -> Bool {
        do {
            if type == .event {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestFullAccessToReminders()
            }
        } catch {
            return false
        }
    }

    func loadEvents(daysAhead: Int = 40) -> ([SourceList], [EventItem]) {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
        let end = cal.date(byAdding: .day, value: daysAhead, to: start) ?? Date()
        let calendars = store.calendars(for: .event)
        let lists = calendars.map { SourceList(id: $0.calendarIdentifier, title: $0.title, colorHex: $0.color.hexString) }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(400)
            .map { e in
                EventItem(id: (e.eventIdentifier ?? UUID().uuidString) + "@" + String(Int(e.startDate.timeIntervalSince1970)),
                          title: e.title ?? "(bez tytułu)",
                          start: e.startDate,
                          end: e.endDate,
                          allDay: e.isAllDay,
                          calendarID: e.calendar?.calendarIdentifier ?? "",
                          colorHex: e.calendar?.color.hexString ?? "#0A84FF",
                          location: e.location)
            }
        return (lists, Array(events))
    }

    func loadReminders() async -> ([SourceList], [ReminderItem]) {
        let calendars = store.calendars(for: .reminder)
        let lists = calendars.map { SourceList(id: $0.calendarIdentifier, title: $0.title, colorHex: $0.color.hexString) }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let reminders: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { result in
                cont.resume(returning: result ?? [])
            }
        }
        let items = reminders.prefix(300).map { r -> ReminderItem in
            let comps = r.dueDateComponents
            let due = comps.flatMap { Calendar.current.date(from: $0) }
            return ReminderItem(id: r.calendarItemIdentifier,
                                title: r.title ?? "(bez tytułu)",
                                due: due,
                                dueHasTime: comps?.hour != nil,
                                listID: r.calendar?.calendarIdentifier ?? "",
                                colorHex: r.calendar?.color.hexString ?? "#FF9F0A",
                                priority: r.priority)
        }
        return (lists, Array(items))
    }

    func complete(id: String) -> Bool {
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        r.isCompleted = true
        do {
            try store.save(r, commit: true)
            return true
        } catch {
            return false
        }
    }
}
