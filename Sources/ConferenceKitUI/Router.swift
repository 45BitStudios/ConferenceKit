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
    case news
    case newsItem(String)
    case resources
    case resource(String)
    case pass
    case sponsors
    case organizers
    case workshops
    case notes
    case conduct
    case settings
}

extension ConferenceDestination {
    var route: ConferenceRoute {
        switch self {
        case .news: .news
        case .resources: .resources
        case .pass: .pass
        }
    }
}

enum InfoRoute: String, CaseIterable, Identifiable {
    case venue, wifi, announcements, news, resources, pass, sponsors, organizers, workshops, notes, conduct, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .venue: "Venue"
        case .wifi: "Wi-Fi"
        case .announcements: "Announcements"
        case .news: "News"
        case .resources: "Resources"
        case .pass: "Pass"
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
        case .news: "newspaper"
        case .resources: "doc"
        case .pass: "ticket"
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
        case .news: .news
        case .resources: .resources
        case .pass: .pass
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
    /// Bumped by the macOS Find command to focus the toolbar search field.
    var searchRequest = 0

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
        SiriDonations.favorite(store, sessionID: sessionID)
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
