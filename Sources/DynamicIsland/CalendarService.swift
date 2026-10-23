import AppKit
import EventKit
import IslandCore

/// Reads today's events from Apple Calendar (includes Google/Outlook/iCloud accounts added in System Settings).
@MainActor
final class CalendarService: ObservableObject {
    enum Access { case notDetermined, granted, denied }

    @Published private(set) var access: Access
    /// All of today's events; the view filters to upcoming ones as time passes.
    @Published private(set) var todaysMeetings: [Meeting] = []

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    init() {
        access = Self.currentAccess()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        Task {
            _ = try? await store.requestFullAccessToEvents()
            access = Self.currentAccess()
            refresh()
        }
    }

    func refresh() {
        access = Self.currentAccess()
        guard access == .granted else { todaysMeetings = []; return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        todaysMeetings = store.events(matching: predicate).map(Self.meeting(from:))
    }

    private static func meeting(from event: EKEvent) -> Meeting {
        let rgb = event.calendar?.color.usingColorSpace(.sRGB).map {
            Meeting.RGB(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent)
        }
        let identifier = event.eventIdentifier
        return Meeting(id: "\(identifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)",
                       eventIdentifier: identifier,
                       title: event.title ?? "Untitled",
                       start: event.startDate,
                       end: event.endDate,
                       isAllDay: event.isAllDay,
                       location: event.location,
                       notes: event.notes,
                       url: event.url,
                       calendarColor: rgb)
    }

    /// Join the video call if there is one, otherwise show the event in Calendar.
    func open(_ meeting: Meeting) {
        if let join = meeting.joinURL {
            NSWorkspace.shared.open(join)
        } else if let id = meeting.eventIdentifier?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
