import Foundation

public struct CalendarEventDraft: Hashable, Sendable {
    public var sessionID: String
    public var title: String
    public var start: Date
    public var end: Date
    public var notes: String
    public var location: String?
    public var url: URL?

    public init(
        sessionID: String,
        title: String,
        start: Date,
        end: Date,
        notes: String,
        location: String? = nil,
        url: URL? = nil
    ) {
        self.sessionID = sessionID
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.location = location
        self.url = url
    }
}

public enum CalendarDrafts {
    public static func make(session: Session, manifest: ConferenceManifest) -> CalendarEventDraft {
        let speakers = manifest.speakers(ids: session.speakerIDs).map(\.name).joined(separator: ", ")
        let room = session.roomID.flatMap { manifest.room(id: $0)?.name }
        let venue = manifest.conference.venue
        let location = [room, venue?.name].compactMap { $0 }.joined(separator: ", ")
        var notes = session.synopsis
        if !speakers.isEmpty {
            notes += "\n\n\(speakers)"
        }
        return CalendarEventDraft(
            sessionID: session.id,
            title: "\(manifest.conference.name): \(session.title)",
            start: session.startTime,
            end: session.endTime,
            notes: notes,
            location: location.isEmpty ? venue?.postalAddress : location,
            url: ConferenceLink.session(session.id).url(conference: manifest.conference)
        )
    }

    public static func make(sessions: [Session], manifest: ConferenceManifest) -> [CalendarEventDraft] {
        sessions.map { make(session: $0, manifest: manifest) }
    }
}

public enum CalendarServiceError: LocalizedError, Sendable {
    case unavailable
    case denied
    case noCalendar
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Calendar isn’t available on this platform."
        case .denied:
            "Calendar access was denied."
        case .noCalendar:
            "No calendar is available to save into."
        case .saveFailed(let message):
            message
        }
    }
}

// watchOS EventKit is read-only (no save), so Add to Calendar is iOS, macOS, and visionOS.
#if canImport(EventKit) && !os(tvOS) && !os(watchOS)
import EventKit

public actor EventCalendarWriter {
    public static let shared = EventCalendarWriter()
    private let store = EKEventStore()

    public func add(drafts: [CalendarEventDraft]) async throws -> Int {
        let granted = try await requestAccess()
        guard granted else { throw CalendarServiceError.denied }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarServiceError.noCalendar
        }
        var saved = 0
        for draft in drafts {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = draft.title
            event.startDate = draft.start
            event.endDate = draft.end
            event.notes = draft.notes
            event.location = draft.location
            event.url = draft.url
            do {
                try store.save(event, span: .thisEvent)
                saved += 1
            } catch {
                throw CalendarServiceError.saveFailed(error.localizedDescription)
            }
        }
        return saved
    }

    private func requestAccess() async throws -> Bool {
        #if os(iOS) || os(visionOS)
        return try await store.requestWriteOnlyAccessToEvents()
        #elseif os(macOS)
        return try await store.requestFullAccessToEvents()
        #else
        throw CalendarServiceError.unavailable
        #endif
    }
}
#else
public actor EventCalendarWriter {
    public static let shared = EventCalendarWriter()

    public func add(drafts: [CalendarEventDraft]) async throws -> Int {
        throw CalendarServiceError.unavailable
    }
}
#endif
