import ConferenceKit
import Observation
import SwiftUI

enum ConferenceRoute: Hashable {
    case session(String)
    case speaker(String)
    case venue
    case wifi
    case announcements
    case announcement(String)
    case sponsors
    case organizers
    case workshops
    case notes
    case conduct
    case settings
}

enum InfoRoute: String, CaseIterable, Identifiable {
    case venue, wifi, announcements, sponsors, organizers, workshops, notes, conduct, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .venue: "Venue"
        case .wifi: "Wi-Fi"
        case .announcements: "Announcements"
        case .sponsors: "Sponsors"
        case .organizers: "Organizers"
        case .workshops: "Workshops"
        case .notes: "My Notes"
        case .conduct: "Code of Conduct"
        case .settings: "Settings"
        }
    }
    var systemImage: String {
        switch self {
        case .venue: "mappin.and.ellipse"
        case .wifi: "wifi"
        case .announcements: "megaphone"
        case .sponsors: "heart"
        case .organizers: "person.crop.rectangle.stack"
        case .workshops: "hammer"
        case .notes: "note.text"
        case .conduct: "checkmark.shield"
        case .settings: "gearshape"
        }
    }
    var route: ConferenceRoute {
        switch self {
        case .venue: .venue
        case .wifi: .wifi
        case .announcements: .announcements
        case .sponsors: .sponsors
        case .organizers: .organizers
        case .workshops: .workshops
        case .notes: .notes
        case .conduct: .conduct
        case .settings: .settings
        }
    }
}

@Observable
@MainActor
final class ConferenceRouter {
    var path = NavigationPath()
    var section: ConferenceSection = .schedule
    var selectedSessionID: String?
    var selectedSpeakerID: String?
    var showsNotes = false
    var followLive = false
    var day: Date?
    var trackID: String?
    var roomID: String?
    var statusMessage: String?
    var coverCompanionEnabled = false
    var coverCompanionAvailable = false

    func setFollowLive(_ on: Bool) {
        followLive = on
        FollowLivePreference.save(on, to: ConferenceKitConfiguration.shared.resolvedDefaults())
    }

    func openSession(_ id: String, push: Bool) {
        selectedSessionID = id
        showsNotes = true
        section = .schedule
        if push { path.append(ConferenceRoute.session(id)) }
    }

    func openSpeaker(_ id: String, push: Bool) {
        selectedSpeakerID = id
        section = .speakers
        if push { path.append(ConferenceRoute.speaker(id)) }
    }

    func open(_ route: ConferenceRoute, push: Bool) {
        switch route {
        case .session(let id): openSession(id, push: push)
        case .speaker(let id): openSpeaker(id, push: push)
        default:
            section = .info
            if push { path.append(route) }
            else { infoSelection = route }
        }
    }

    var infoSelection: ConferenceRoute?
}

@MainActor
enum ConferenceActions {
    static func toggleFavorite(_ store: ConferenceStore, sessionID: String) async {
        store.favorites.toggle(sessionID)
        store.publishFavorites()
        await syncReminders(store)
    }

    static func syncReminders(_ store: ConferenceStore) async {
        guard let manifest = store.manifest else { return }
        _ = await SessionReminderCenter.shared.sync(
            manifest: manifest,
            favoriteIDs: store.favorites.ids,
            preferences: store.reminderPreferences,
            defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
        )
    }

    static func addToCalendar(_ store: ConferenceStore, sessions: [Session]) async -> String {
        guard let manifest = store.manifest else { return "No conference is loaded." }
        do {
            let count = try await EventCalendarWriter.shared.add(
                drafts: CalendarDrafts.make(sessions: sessions, manifest: manifest)
            )
            return "Added \(count) to Calendar."
        } catch {
            return error.localizedDescription
        }
    }
}
