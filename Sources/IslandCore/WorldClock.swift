import Foundation

public struct City: Codable, Hashable, Identifiable {
    public var name: String
    public var timeZoneID: String
    // Several cities share a zone (New Delhi, Mumbai -> Asia/Kolkata), so the name is part of the id.
    public var id: String { "\(name)|\(timeZoneID)" }

    public init(name: String, timeZoneID: String) {
        self.name = name
        self.timeZoneID = timeZoneID
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    public static let newDelhi = City(name: "New Delhi", timeZoneID: "Asia/Kolkata")
}

public enum DayRelation: Equatable {
    case yesterday, today, tomorrow

    public var label: String {
        switch self {
        case .yesterday: return "Yesterday"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        }
    }

}

public enum WorldClock {
    /// "HH:mm" or "HH:mm:ss" (24-hour) in the given time zone.
    public static func timeString(_ date: Date, in timeZone: TimeZone, showSeconds: Bool = false) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hm = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        return showSeconds ? hm + String(format: ":%02d", c.second ?? 0) : hm
    }

    /// Difference of `remote` relative to `local`, e.g. "+3h 30m", "-5h", "Same time".
    public static func offsetDescription(from local: TimeZone, to remote: TimeZone, at date: Date) -> String {
        let diff = remote.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
        if diff == 0 { return "Same time" }
        let sign = diff > 0 ? "+" : "-"
        let minutes = abs(diff) / 60
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }

    /// Whether the calendar date in `remote` is the day before/same/after the date in `local`.
    public static func dayRelation(at date: Date, local: TimeZone, remote: TimeZone) -> DayRelation {
        func dayNumber(_ tz: TimeZone) -> Int {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let midnight = utc.date(from: c)!
            return Int(midnight.timeIntervalSince1970 / 86_400)
        }
        switch dayNumber(remote) - dayNumber(local) {
        case ..<0: return .yesterday
        case 0: return .today
        default: return .tomorrow
        }
    }

    /// Human name from an identifier: "America/New_York" -> "New York".
    public static func displayName(forTimeZoneID id: String) -> String {
        let last = id.split(separator: "/").last.map(String.init) ?? id
        return last.replacingOccurrences(of: "_", with: " ")
    }
}

/// Finds cities for the "Add city" search in Settings.
public enum CitySearch {
    /// Common cities whose name isn't the time zone identifier.
    static let aliases: [City] = [
        .newDelhi,
        City(name: "Mumbai", timeZoneID: "Asia/Kolkata"),
        City(name: "Bengaluru", timeZoneID: "Asia/Kolkata"),
        City(name: "San Francisco", timeZoneID: "America/Los_Angeles"),
        City(name: "Seattle", timeZoneID: "America/Los_Angeles"),
        City(name: "Washington DC", timeZoneID: "America/New_York"),
        City(name: "Boston", timeZoneID: "America/New_York"),
        City(name: "Munich", timeZoneID: "Europe/Berlin"),
        City(name: "Frankfurt", timeZoneID: "Europe/Berlin"),
        City(name: "Beijing", timeZoneID: "Asia/Shanghai"),
        City(name: "Abu Dhabi", timeZoneID: "Asia/Dubai"),
        City(name: "Osaka", timeZoneID: "Asia/Tokyo"),
    ]

    public static func search(_ query: String,
                              identifiers: [String] = TimeZone.knownTimeZoneIdentifiers,
                              limit: Int = 30) -> [City] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let fromIDs = identifiers
            .filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
            .map { City(name: WorldClock.displayName(forTimeZoneID: $0), timeZoneID: $0) }
        let all = aliases + fromIDs
        var seen = Set<String>()
        let matches = all.filter {
            ($0.name.lowercased().contains(q) || $0.timeZoneID.lowercased().contains(q))
                && seen.insert($0.name + "|" + $0.timeZoneID).inserted
        }
        // Names that start with the query first.
        let sorted = matches.sorted {
            let a = $0.name.lowercased().hasPrefix(q), b = $1.name.lowercased().hasPrefix(q)
            return a != b ? a : $0.name < $1.name
        }
        return Array(sorted.prefix(limit))
    }
}
