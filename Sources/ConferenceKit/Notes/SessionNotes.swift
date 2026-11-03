import Foundation
import Observation

public enum SessionNoteKind: String, Codable, Hashable, Sendable, CaseIterable {
    case text
    case timestamp
    case takeaway
    case photo
}

public struct SessionNote: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sessionID: String
    public var conferenceID: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var kind: SessionNoteKind
    public var isStarred: Bool
    public var isTakeaway: Bool
    /// Seconds from the session start. Negative means the note was taken early.
    public var offsetFromStart: TimeInterval?
    public var photoFilename: String?

    public init(
        id: UUID = UUID(),
        sessionID: String,
        conferenceID: String,
        body: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: SessionNoteKind = .text,
        isStarred: Bool = false,
        isTakeaway: Bool = false,
        offsetFromStart: TimeInterval? = nil,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.conferenceID = conferenceID
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kind = kind
        self.isStarred = isStarred
        self.isTakeaway = isTakeaway
        self.offsetFromStart = offsetFromStart
        self.photoFilename = photoFilename
    }
}

public enum NotesMarkdown {
    public static func render(notes: [SessionNote], manifest: ConferenceManifest) -> String {
        let clock = manifest.clock
        var lines: [String] = ["# \(manifest.conference.name)", ""]
        if let tagline = manifest.conference.tagline, !tagline.isEmpty {
            lines.append(tagline)
            lines.append("")
        }
        let grouped = Dictionary(grouping: notes, by: \.sessionID)
        let sessions = manifest.sessions
            .filter { grouped[$0.id]?.isEmpty == false }
            .sorted { $0.startTime < $1.startTime }
        var currentDay: Date?
        for session in sessions {
            let day = clock.startOfDay(for: session.startTime)
            if currentDay != day {
                currentDay = day
                lines.append("## \(clock.dayString(day))")
                lines.append("")
            }
            lines.append("### \(session.title)")
            lines.append("")
            let when = clock.rangeString(from: session.startTime, to: session.endTime)
            let room = session.roomID.flatMap { manifest.room(id: $0)?.name }
            let speakers = manifest.speakers(ids: session.speakerIDs).map(\.name).joined(separator: ", ")
            var meta = [when, room, session.kind.label].compactMap { $0 }
            lines.append(meta.joined(separator: " · "))
            if !speakers.isEmpty { lines.append("Speakers: \(speakers)") }
            lines.append("")
            let sessionNotes = (grouped[session.id] ?? []).sorted { $0.createdAt < $1.createdAt }
            for note in sessionNotes {
                lines.append(bullet(note))
            }
            lines.append("")
        }
        let known = Set(manifest.sessions.map(\.id))
        let orphans = notes.filter { !known.contains($0.sessionID) }.sorted { $0.createdAt < $1.createdAt }
        if !orphans.isEmpty {
            lines.append("## Other")
            lines.append("")
            for note in orphans { lines.append(bullet(note)) }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func bullet(_ note: SessionNote) -> String {
        let stamp = note.offsetFromStart.map { " (\(SessionProgress.offsetLabel($0)))" } ?? ""
        let star = note.isStarred ? "★ " : ""
        let prefix = note.isTakeaway ? "**Takeaway** " : ""
        switch note.kind {
        case .photo:
            let name = note.photoFilename ?? "slide"
            let caption = note.body.isEmpty ? "Slide" : note.body
            return "- \(star)\(prefix)\(caption)\(stamp) ![](photos/\(name))"
        case .timestamp:
            return "- \(star)\(prefix)• \(note.body)\(stamp)"
        case .takeaway, .text:
            return "- \(star)\(prefix)\(note.body)\(stamp)"
        }
    }
}

@Observable
@MainActor
public final class NotesStore {
    public private(set) var notes: [SessionNote] = []
    public let conferenceID: String
    public let directory: URL

    public init(conferenceID: String, directory: URL) {
        self.conferenceID = conferenceID
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        reload()
    }

    public convenience init(conferenceID: String, configuration: ConferenceKitConfiguration = .shared) {
        self.init(conferenceID: conferenceID, directory: configuration.notesDirectory(conferenceID: conferenceID))
    }

    public func notes(for sessionID: String) -> [SessionNote] {
        notes.filter { $0.sessionID == sessionID }.sorted { $0.createdAt < $1.createdAt }
    }

    public func note(id: UUID) -> SessionNote? {
        notes.first { $0.id == id }
    }

    public func search(_ query: String, manifest: ConferenceManifest? = nil) -> [SessionNote] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notes.sorted { $0.createdAt < $1.createdAt } }
        return notes.filter { note in
            if note.body.localizedStandardContains(trimmed) { return true }
            if note.isTakeaway && "takeaway".localizedStandardContains(trimmed) { return true }
            guard let manifest, let session = manifest.session(id: note.sessionID) else { return false }
            if session.title.localizedStandardContains(trimmed) { return true }
            return manifest.speakers(ids: session.speakerIDs).contains { $0.name.localizedStandardContains(trimmed) }
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    public func add(
        body: String,
        session: Session,
        kind: SessionNoteKind = .text,
        starred: Bool = false,
        takeaway: Bool = false,
        now: Date = .now
    ) -> SessionNote {
        let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = SessionNote(
            sessionID: session.id,
            conferenceID: conferenceID,
            body: cleaned,
            createdAt: now,
            updatedAt: now,
            kind: takeaway ? .takeaway : kind,
            isStarred: starred,
            isTakeaway: takeaway || kind == .takeaway,
            offsetFromStart: SessionProgress.offset(from: session.startTime, to: now)
        )
        notes.append(note)
        persist()
        return note
    }

    @discardableResult
    public func addPhoto(data: Data, session: Session, caption: String = "", now: Date = .now) throws -> SessionNote {
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        try data.write(to: photosDirectory.appendingPathComponent(filename), options: .atomic)
        let note = SessionNote(
            id: id,
            sessionID: session.id,
            conferenceID: conferenceID,
            body: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            kind: .photo,
            offsetFromStart: SessionProgress.offset(from: session.startTime, to: now),
            photoFilename: filename
        )
        notes.append(note)
        persist()
        return note
    }

    public func photoURL(for note: SessionNote) -> URL? {
        guard let photoFilename = note.photoFilename else { return nil }
        return photosDirectory.appendingPathComponent(photoFilename)
    }

    public func toggleStar(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isStarred.toggle()
        notes[index].updatedAt = .now
        persist()
    }

    public func toggleTakeaway(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isTakeaway.toggle()
        if notes[index].isTakeaway { notes[index].kind = .takeaway }
        notes[index].updatedAt = .now
        persist()
    }

    public func delete(_ id: UUID) {
        if let note = note(id: id), let filename = note.photoFilename {
            try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(filename))
        }
        notes.removeAll { $0.id == id }
        persist()
    }

    public func markdown(manifest: ConferenceManifest) -> String {
        NotesMarkdown.render(notes: notes, manifest: manifest)
    }

    public func reload() {
        guard let data = try? Data(contentsOf: fileURL) else {
            notes = []
            return
        }
        notes = (try? JSONDecoder().decode([SessionNote].self, from: data)) ?? []
    }

    private var fileURL: URL { directory.appendingPathComponent("notes.json") }
    private var photosDirectory: URL { directory.appendingPathComponent("photos", isDirectory: true) }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
