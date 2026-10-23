import Foundation

/// Calendar-agnostic meeting model (the app maps EventKit events into this).
public struct Meeting: Identifiable, Equatable {
    public struct RGB: Equatable {
        public var red, green, blue: Double
        public init(red: Double, green: Double, blue: Double) {
            self.red = red; self.green = green; self.blue = blue
        }
    }

    public var id: String
    /// EventKit identifier (shared by all occurrences of a recurring event), used to open it in Calendar.
    public var eventIdentifier: String?
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var url: URL?
    public var calendarColor: RGB?

    public init(id: String, eventIdentifier: String? = nil, title: String, start: Date, end: Date, isAllDay: Bool = false,
                location: String? = nil, notes: String? = nil, url: URL? = nil, calendarColor: RGB? = nil) {
        self.id = id; self.eventIdentifier = eventIdentifier; self.title = title; self.start = start; self.end = end; self.isAllDay = isAllDay
        self.location = location; self.notes = notes; self.url = url; self.calendarColor = calendarColor
    }

    /// Video call link from the event URL, location, or notes.
    public var joinURL: URL? {
        VideoLinkDetector.firstLink(in: [url?.absoluteString, location, notes])
    }
}

public enum MeetingStatus: Equatable {
    case inProgress(minutesLeft: Int)
    case upcoming(minutesUntil: Int)

    public var label: String {
        switch self {
        case .inProgress(let left): return left <= 1 ? "Ending" : "Now · \(left)m left"
        case .upcoming(let until):
            if until < 1 { return "Starting" }
            if until < 60 { return "in \(until)m" }
            let h = until / 60, m = until % 60
            return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
        }
    }
}

public enum MeetingSchedule {
    /// Timed meetings that haven't ended yet and start before the end of `now`'s day, sorted by start.
    public static func upcomingToday(_ meetings: [Meeting], now: Date, calendar: Calendar = .current) -> [Meeting] {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        return meetings
            .filter { !$0.isAllDay && $0.end > now && $0.start < startOfTomorrow }
            .sorted { $0.start == $1.start ? $0.title < $1.title : $0.start < $1.start }
    }

    public static func status(of meeting: Meeting, now: Date) -> MeetingStatus {
        if meeting.start <= now {
            return .inProgress(minutesLeft: Int(ceil(meeting.end.timeIntervalSince(now) / 60)))
        }
        return .upcoming(minutesUntil: Int(ceil(meeting.start.timeIntervalSince(now) / 60)))
    }
}

public enum VideoLinkDetector {
    static let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "whereby.com"]

    private static let regex = try! NSRegularExpression(pattern: #"https?://[^\s<>"')]+"#, options: .caseInsensitive)

    public static func firstLink(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range, in: text), let url = URL(string: String(text[r])),
                      let host = url.host?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}
