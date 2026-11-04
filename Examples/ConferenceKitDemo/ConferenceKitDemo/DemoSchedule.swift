import ConferenceKit
import Foundation

/// The bundled sample is a past conference. The demo moves it so the first
/// session started ten minutes ago: laptop mode has a live session, and
/// favorites have future start times for reminders.
/// Pass `-CKDemoOriginalDates` to keep the sample's real dates.
enum DemoSchedule {
    static func manifest(now: Date = .now) async throws -> ConferenceManifest {
        var manifest = try await ConferenceLoader().load(.sample)
        if ProcessInfo.processInfo.arguments.contains("-CKDemoOriginalDates") { return manifest }
        guard let first = manifest.sessions.map(\.startTime).min() else { return manifest }
        let raw = now.addingTimeInterval(-10 * 60).timeIntervalSince(first)
        let offset = (raw / 300).rounded(.down) * 300
        manifest.sessions = manifest.sessions.map { session in
            var moved = session
            moved.startTime = session.startTime.addingTimeInterval(offset)
            moved.endTime = session.endTime.addingTimeInterval(offset)
            return moved
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: manifest.conference.timezone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        let starts = manifest.sessions.map(\.startTime)
        if let lo = starts.min(), let hi = starts.max() {
            manifest.conference.startDate = formatter.string(from: lo)
            manifest.conference.endDate = formatter.string(from: hi)
        }
        return manifest
    }
}
