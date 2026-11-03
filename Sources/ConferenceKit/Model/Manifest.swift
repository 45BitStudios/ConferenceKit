import Foundation
import SwiftUI

/// Top-level document an organizer drops in. Versioned so later kit
/// releases can evolve fields without breaking existing conference apps.
///
/// Fields added after schema 1.0 are optional. A document that only has
/// conference, theme, tracks, rooms, speakers, and sessions still decodes.
public struct ConferenceManifest: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var conference: ConferenceInfo
    public var theme: ConferenceTheme
    public var tracks: [Track]
    public var rooms: [Room]
    public var speakers: [Speaker]
    public var sessions: [Session]
    public var sponsors: [Sponsor]
    public var organizers: [Organizer]
    public var announcements: [Announcement]
    public var codeOfConduct: CodeOfConduct?
    public var wifi: WiFiInfo?

    public init(
        schemaVersion: String = ConferenceKit.schemaVersion,
        conference: ConferenceInfo,
        theme: ConferenceTheme = ConferenceTheme(),
        tracks: [Track] = [],
        rooms: [Room] = [],
        speakers: [Speaker] = [],
        sessions: [Session] = [],
        sponsors: [Sponsor] = [],
        organizers: [Organizer] = [],
        announcements: [Announcement] = [],
        codeOfConduct: CodeOfConduct? = nil,
        wifi: WiFiInfo? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.conference = conference
        self.theme = theme
        self.tracks = tracks
        self.rooms = rooms
        self.speakers = speakers
        self.sessions = sessions
        self.sponsors = sponsors
        self.organizers = organizers
        self.announcements = announcements
        self.codeOfConduct = codeOfConduct
        self.wifi = wifi
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

    public func sponsor(id: String) -> Sponsor? {
        sponsors.first { $0.id == id }
    }

    public func session(id: String) -> Session? {
        sessions.first { $0.id == id }
    }

    public var clock: ConferenceClock {
        ConferenceClock(timeZoneIdentifier: conference.timezone)
    }

    public var timeZone: TimeZone {
        clock.timeZone
    }

    public var sessionsByDay: [(day: Date, sessions: [Session])] {
        conferenceDays.map { (day: $0.start, sessions: $0.sessions) }
    }

    public var conferenceDays: [ConferenceDay] {
        let zoneClock = clock
        let grouped = Dictionary(grouping: sessions) { session in
            zoneClock.startOfDay(for: session.startTime)
        }
        return grouped
            .map { ConferenceDay(start: $0.key, sessions: $0.value.sorted { $0.startTime < $1.startTime }) }
            .sorted { $0.start < $1.start }
    }

    public func sessions(for speakerID: String) -> [Session] {
        sessions
            .filter { $0.speakerIDs.contains(speakerID) }
            .sorted { $0.startTime < $1.startTime }
    }

    public func sessions(on day: Date) -> [Session] {
        let zoneClock = clock
        return sessions
            .filter { zoneClock.isSameDay($0.startTime, day) }
            .sorted { $0.startTime < $1.startTime }
    }

    public var workshops: [Session] {
        sessions.filter { $0.kind == .workshop }.sorted { $0.startTime < $1.startTime }
    }

    public var sponsorsByTier: [(tier: SponsorTier, sponsors: [Sponsor])] {
        let grouped = Dictionary(grouping: sponsors, by: \.tier)
        return SponsorTier.allCases.compactMap { tier in
            guard let sponsors = grouped[tier], !sponsors.isEmpty else { return nil }
            return (tier, sponsors.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
    }

    public func validate() -> [ManifestIssue] {
        var issues: [ManifestIssue] = []
        if clock.usedFallback {
            issues.append(ManifestIssue(message: "Unknown time zone “\(conference.timezone)”."))
        }
        if clock.day(from: conference.startDate) == nil {
            issues.append(ManifestIssue(message: "Conference start date “\(conference.startDate)” is not yyyy-MM-dd."))
        }
        if clock.day(from: conference.endDate) == nil {
            issues.append(ManifestIssue(message: "Conference end date “\(conference.endDate)” is not yyyy-MM-dd."))
        }
        var sessionIDs = Set<String>()
        for session in sessions {
            if !sessionIDs.insert(session.id).inserted {
                issues.append(ManifestIssue(message: "Duplicate session id “\(session.id)”."))
            }
            if session.endTime < session.startTime {
                issues.append(ManifestIssue(message: "Session “\(session.title)” ends before it starts."))
            }
            for speakerID in session.speakerIDs where speaker(id: speakerID) == nil {
                issues.append(ManifestIssue(message: "Session “\(session.title)” references unknown speaker “\(speakerID)”."))
            }
            if let trackID = session.trackID, track(id: trackID) == nil {
                issues.append(ManifestIssue(message: "Session “\(session.title)” references unknown track “\(trackID)”."))
            }
            if let roomID = session.roomID, room(id: roomID) == nil {
                issues.append(ManifestIssue(message: "Session “\(session.title)” references unknown room “\(roomID)”."))
            }
        }
        return issues
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, conference, theme, tracks, rooms, speakers, sessions
        case sponsors, organizers, announcements, codeOfConduct, wifi
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? ConferenceKit.minimumSchemaVersion
        conference = try container.decode(ConferenceInfo.self, forKey: .conference)
        theme = try container.decodeIfPresent(ConferenceTheme.self, forKey: .theme) ?? ConferenceTheme()
        tracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        rooms = try container.decodeIfPresent([Room].self, forKey: .rooms) ?? []
        speakers = try container.decodeIfPresent([Speaker].self, forKey: .speakers) ?? []
        sessions = try container.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        sponsors = try container.decodeIfPresent([Sponsor].self, forKey: .sponsors) ?? []
        organizers = try container.decodeIfPresent([Organizer].self, forKey: .organizers) ?? []
        announcements = try container.decodeIfPresent([Announcement].self, forKey: .announcements) ?? []
        codeOfConduct = try container.decodeIfPresent(CodeOfConduct.self, forKey: .codeOfConduct)
        wifi = try container.decodeIfPresent(WiFiInfo.self, forKey: .wifi)
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
    public var latitude: Double?
    public var longitude: Double?
    public var directions: String?
    public var mapURL: URL?

    public init(
        name: String,
        address: String? = nil,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        directions: String? = nil,
        mapURL: URL? = nil
    ) {
        self.name = name
        self.address = address
        self.city = city
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.directions = directions
        self.mapURL = mapURL
    }

    public var displayLine: String {
        [name, city, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public var postalAddress: String {
        [address, city, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    public var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }

    /// Apple Maps directions URL. Falls back to a map search on the address.
    public var directionsURL: URL? {
        if let mapURL { return mapURL }
        if let coordinate {
            let destination = "\(coordinate.latitude),\(coordinate.longitude)"
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "daddr", value: destination)]
            return components?.url
        }
        let query = postalAddress.isEmpty ? name : postalAddress
        guard !query.isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
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

    public var detailLine: String {
        [floor.map { "Floor \($0)" }, capacity.map { "\($0) seats" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
