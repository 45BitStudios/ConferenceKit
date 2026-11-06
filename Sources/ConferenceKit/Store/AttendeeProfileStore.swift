import Foundation
import Observation

/// This device’s attendee profile. Other people’s private fields never land here.
@Observable
@MainActor
public final class AttendeeProfileStore {
    public private(set) var profile: Attendee
    public let conferenceID: String
    public let fileURL: URL

    public init(conferenceID: String, directory: URL, seed: Attendee) {
        self.conferenceID = conferenceID
        fileURL = directory.appendingPathComponent("profile.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(Attendee.self, from: data) {
            profile = stored
        } else {
            var starting = seed
            starting.isCurrentUser = true
            profile = starting
            persist()
        }
    }

    public convenience init(conferenceID: String, seed: Attendee, configuration: ConferenceKitConfiguration = .shared) {
        self.init(
            conferenceID: conferenceID,
            directory: configuration.attendeeDirectory(conferenceID: conferenceID),
            seed: seed
        )
    }

    public static func seed(in manifest: ConferenceManifest) -> Attendee {
        if let marked = manifest.attendees.first(where: \.isCurrentUser) {
            return marked
        }
        return Attendee(
            id: "local-\(manifest.conference.id)",
            displayName: "",
            bio: "",
            privacy: AttendeePrivacy(),
            messagingConsent: false,
            isCurrentUser: true
        )
    }

    public func edit(_ body: (inout Attendee) -> Void) {
        body(&profile)
        profile.isCurrentUser = true
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
