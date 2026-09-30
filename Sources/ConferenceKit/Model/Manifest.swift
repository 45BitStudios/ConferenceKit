import Foundation
import SwiftUI

/// Top-level document an organizer drops in. Versioned so later kit
/// releases can evolve fields without breaking existing conference apps.
public struct ConferenceManifest: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var conference: ConferenceInfo
    public var theme: ConferenceTheme
    public var tracks: [Track]
    public var rooms: [Room]
    public var speakers: [Speaker]
    public var sessions: [Session]

    public init(
        schemaVersion: String = ConferenceKit.schemaVersion,
        conference: ConferenceInfo,
        theme: ConferenceTheme = ConferenceTheme(),
        tracks: [Track] = [],
        rooms: [Room] = [],
        speakers: [Speaker] = [],
        sessions: [Session] = []
    ) {
        self.schemaVersion = schemaVersion
        self.conference = conference
        self.theme = theme
        self.tracks = tracks
        self.rooms = rooms
        self.speakers = speakers
        self.sessions = sessions
    }

    public func speaker(id: String) -> Speaker? {
        speakers.first { $0.id == id }
    }

    public func speakers(ids: [String]) -> [Speaker] {
        ids.compactMap(speaker(id:))
    }

    public func track(id: String) -> Track? {
        tracks.first { $0.id == id }
    }

    public func room(id: String) -> Room? {
        rooms.first { $0.id == id }
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: conference.timezone) ?? .current
    }

    public var sessionsByDay: [(day: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startTime < $1.startTime }) }
            .sorted { $0.day < $1.day }
    }

    public func sessions(for speakerID: String) -> [Session] {
        sessions
            .filter { $0.speakerIDs.contains(speakerID) }
            .sorted { $0.startTime < $1.startTime }
    }
}

public struct ConferenceInfo: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var tagline: String?
    public var timezone: String
    public var startDate: String
    public var endDate: String
    public var url: URL?
    public var venue: Venue?

    public init(
        id: String,
        name: String,
        tagline: String? = nil,
        timezone: String,
        startDate: String,
        endDate: String,
        url: URL? = nil,
        venue: Venue? = nil
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.timezone = timezone
        self.startDate = startDate
        self.endDate = endDate
        self.url = url
        self.venue = venue
    }
}

public struct Venue: Codable, Hashable, Sendable {
    public var name: String
    public var address: String?
    public var city: String?
    public var region: String?
    public var country: String?

    public init(
        name: String,
        address: String? = nil,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil
    ) {
        self.name = name
        self.address = address
        self.city = city
        self.region = region
        self.country = country
    }

    public var displayLine: String {
        [name, city, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

public struct Track: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var color: String?

    public init(id: String, name: String, color: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
    }

    public var swiftColor: Color? {
        color.flatMap(Color.init(hex:))
    }
}

public struct Room: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var floor: String?
    public var capacity: Int?

    public init(id: String, name: String, floor: String? = nil, capacity: Int? = nil) {
        self.id = id
        self.name = name
        self.floor = floor
        self.capacity = capacity
    }
}
