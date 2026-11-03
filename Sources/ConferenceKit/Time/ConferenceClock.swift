import Foundation

/// Calendar math pinned to the conference time zone.
///
/// Session instants are absolute. Day buckets, "today", and the strings
/// an attendee reads on a badge follow the conference zone, not the device
/// zone, unless the attendee asks for device time.
public struct ConferenceClock: Hashable, Sendable {
    public let timeZone: TimeZone
    public let usedFallback: Bool

    public init(timeZone: TimeZone) {
        self.timeZone = timeZone
        self.usedFallback = false
    }

    public init(timeZoneIdentifier: String) {
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            self.timeZone = timeZone
            self.usedFallback = false
        } else {
            self.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            self.usedFallback = true
        }
    }

    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    public func day(from dayString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayString)
    }

    /// Inclusive conference span from the start of `startDate` through the end of `endDate`.
    public func interval(startDay: String, endDay: String) -> DateInterval? {
        guard let start = day(from: startDay) else { return nil }
        guard let endDayStart = day(from: endDay) else { return nil }
        guard let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endDayStart) else {
            return nil
        }
        guard end >= start else { return nil }
        return DateInterval(start: start, end: end)
    }

    public enum Phase: String, Sendable, Hashable {
        case before
        case during
        case after
    }

    public func phase(interval: DateInterval?, at date: Date) -> Phase {
        guard let interval else { return .during }
        if date < interval.start { return .before }
        if date > interval.end { return .after }
        return .during
    }

    public func timeString(_ date: Date, style: TimeDisplay = .conference) -> String {
        date.formatted(timeStyle(style))
    }

    public func dayString(_ date: Date, style: TimeDisplay = .conference) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
                .timeZone(zone(for: style))
                .locale(Locale.current)
        )
    }

    public func rangeString(from start: Date, to end: Date, style: TimeDisplay = .conference) -> String {
        let format = timeStyle(style)
        return "\(start.formatted(format)) – \(end.formatted(format))"
    }

    private func timeStyle(_ style: TimeDisplay) -> Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened)
            .timeZone(zone(for: style))
            .locale(Locale.current)
    }

    private func zone(for style: TimeDisplay) -> TimeZone {
        switch style {
        case .conference: timeZone
        case .device: .current
        }
    }
}

public enum TimeDisplay: String, Codable, Hashable, Sendable, CaseIterable {
    case conference
    case device

    public var label: String {
        switch self {
        case .conference: "Conference time"
        case .device: "Device time"
        }
    }
}

public struct ConferenceDay: Identifiable, Hashable, Sendable {
    public var start: Date
    public var sessions: [Session]

    public var id: Date { start }

    public init(start: Date, sessions: [Session]) {
        self.start = start
        self.sessions = sessions
    }
}
