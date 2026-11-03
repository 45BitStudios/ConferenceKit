import AppIntents
import ConferenceKit
import Foundation

public struct OpenSessionIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Session"
    public static let description = IntentDescription("Open a session in the conference app.")
    public static let openAppWhenRun = true

    @Parameter(title: "Session")
    public var target: SessionEntity

    public init() {}

    public init(target: SessionEntity) {
        self.target = target
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        ConferenceNavigation.shared.openSession(id: target.id)
        return .result()
    }
}

public struct OpenSpeakerIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Speaker"
    public static let description = IntentDescription("Open a speaker bio.")
    public static let openAppWhenRun = true

    @Parameter(title: "Speaker")
    public var target: SpeakerEntity

    public init() {}

    public init(target: SpeakerEntity) {
        self.target = target
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        ConferenceNavigation.shared.openSpeaker(id: target.id)
        return .result()
    }
}

public struct WhatsNextIntent: AppIntent {
    public static let title: LocalizedStringResource = "What's Next"
    public static let description = IntentDescription("Report the live session, or the next one if nothing is on.")

    @Parameter(title: "Favorites Only", default: false)
    public var favoritesOnly: Bool

    public init() {}

    public init(favoritesOnly: Bool) {
        self.favoritesOnly = favoritesOnly
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("What's next") { \.$favoritesOnly }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        let favorites = await IntentCatalog.favoriteSessionIDs()
        let pool = favoritesOnly ? manifest.sessions.filter { favorites.contains($0.id) } : manifest.sessions
        if let live = ConferenceSearch.liveSessions(in: pool).first {
            ConferenceNavigation.shared.openSession(id: live.id)
            return .result(dialog: IntentDialog(stringLiteral: "\(live.title) is on now."))
        }
        if let next = ConferenceSearch.nextUp(in: pool).first {
            ConferenceNavigation.shared.openSession(id: next.id)
            let when = manifest.clock.timeString(next.startTime)
            return .result(dialog: IntentDialog(stringLiteral: "Next is \(next.title) at \(when)."))
        }
        return .result(dialog: IntentDialog("Nothing else is scheduled."))
    }
}

public struct MyScheduleTodayIntent: AppIntent {
    public static let title: LocalizedStringResource = "My Schedule Today"
    public static let description = IntentDescription("List favorited sessions on today's conference day.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[SessionEntity]> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: [], dialog: IntentDialog("No conference is loaded."))
        }
        ConferenceNavigation.shared.show(.favorites)
        let favorites = await IntentCatalog.favoriteSessionIDs()
        let today = manifest.sessions(on: .now).filter { favorites.contains($0.id) }
        let entities = today.map { SessionEntity($0, manifest: manifest) }
        let dialog = entities.isEmpty
            ? "Nothing saved for today."
            : "You have \(entities.count) saved today."
        return .result(value: entities, dialog: IntentDialog(stringLiteral: dialog))
    }
}

public struct SearchSessionsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search Sessions"
    public static let description = IntentDescription("Find sessions, speakers, rooms, or tracks.")
    public static let openAppWhenRun = true

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public init(query: String) {
        self.query = query
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Search sessions for \(\.$query)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[SessionEntity]> & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(value: [], dialog: IntentDialog("No conference is loaded."))
        }
        ConferenceNavigation.shared.search(query)
        let matches = ConferenceSearch.sessions(in: manifest, matching: SessionFilter(query: query))
        let entities = matches.prefix(15).map { SessionEntity($0, manifest: manifest) }
        return .result(
            value: Array(entities),
            dialog: IntentDialog(stringLiteral: "Found \(matches.count) sessions.")
        )
    }
}

public struct SetSessionFavoriteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Set Session Favorite"
    public static let description = IntentDescription("Save or remove a session from My Schedule.")

    @Parameter(title: "Session")
    public var session: SessionEntity

    @Parameter(title: "Favorite")
    public var favorite: Bool

    public init() {}

    public init(session: SessionEntity, favorite: Bool) {
        self.session = session
        self.favorite = favorite
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$session) favorite to \(\.$favorite)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await FavoriteMutator.setSession(id: session.id, favorite: favorite)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

public struct SetSessionFavoriteByIDIntent: AppIntent {
    public static let title: LocalizedStringResource = "Set Session Favorite by ID"
    public static let description = IntentDescription("Save or remove a session. Used by widgets.")
    public static let isDiscoverable: Bool = false

    @Parameter(title: "Session ID")
    public var sessionID: String

    @Parameter(title: "Favorite")
    public var favorite: Bool

    public init() {
        sessionID = ""
        favorite = true
    }

    public init(sessionID: String, favorite: Bool) {
        self.sessionID = sessionID
        self.favorite = favorite
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        _ = await FavoriteMutator.setSession(id: sessionID, favorite: favorite)
        return .result()
    }
}

public struct FavoriteNextSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Favorite Next Session"
    public static let description = IntentDescription("Save the next session that has not started.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        guard let next = ConferenceSearch.nextUp(in: manifest.sessions).first
            ?? ConferenceSearch.liveSessions(in: manifest.sessions).first else {
            return .result(dialog: IntentDialog("Nothing is coming up."))
        }
        let message = await FavoriteMutator.setSession(id: next.id, favorite: true)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

public struct UnfavoriteSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Unfavorite Session"
    public static let description = IntentDescription("Remove a session from My Schedule.")

    @Parameter(title: "Session")
    public var session: SessionEntity

    public init() {}

    public init(session: SessionEntity) {
        self.session = session
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$session) from My Schedule")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await FavoriteMutator.setSession(id: session.id, favorite: false)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

public struct AddSessionToCalendarIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Session to Calendar"
    public static let description = IntentDescription("Add one session to the default calendar.")

    @Parameter(title: "Session")
    public var session: SessionEntity

    public init() {}

    public init(session: SessionEntity) {
        self.session = session
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$session) to Calendar")
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest(), let model = manifest.session(id: session.id) else {
            return .result(dialog: IntentDialog("That session isn’t in the schedule."))
        }
        let count = try await EventCalendarWriter.shared.add(drafts: [CalendarDrafts.make(session: model, manifest: manifest)])
        return .result(dialog: IntentDialog(stringLiteral: "Added \(count) event to Calendar."))
    }
}

public struct AddFavoritesToCalendarIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add My Schedule to Calendar"
    public static let description = IntentDescription("Add every favorited session to the default calendar.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        let favorites = await IntentCatalog.favoriteSessionIDs()
        let sessions = manifest.sessions.filter { favorites.contains($0.id) }
        guard !sessions.isEmpty else {
            return .result(dialog: IntentDialog("My Schedule is empty."))
        }
        let count = try await EventCalendarWriter.shared.add(drafts: CalendarDrafts.make(sessions: sessions, manifest: manifest))
        return .result(dialog: IntentDialog(stringLiteral: "Added \(count) events to Calendar."))
    }
}

public struct SetSessionReminderIntent: AppIntent {
    public static let title: LocalizedStringResource = "Set Session Reminder"
    public static let description = IntentDescription("Save a session and schedule a reminder before it starts.")

    @Parameter(title: "Session")
    public var session: SessionEntity

    @Parameter(title: "Lead Time", default: .tenMinutes)
    public var lead: ReminderLeadAppEnum

    public init() {}

    public init(session: SessionEntity, lead: ReminderLeadAppEnum) {
        self.session = session
        self.lead = lead
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Remind me \(\.$lead) about \(\.$session)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = await SessionReminderCenter.shared.requestAuthorization()
        guard let manifest = await IntentCatalog.manifest() else {
            return .result(dialog: IntentDialog("No conference is loaded."))
        }
        if let store = ConferenceRuntime.shared.store {
            store.setRemindersEnabled(true)
            store.setReminderLeadTime(lead.seconds)
            store.favorites.set(session.id, favorite: true)
            store.publishFavorites()
            _ = await SessionReminderCenter.shared.sync(
                manifest: manifest,
                favoriteIDs: store.favorites.ids,
                preferences: store.reminderPreferences,
                defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
            )
        } else {
            _ = await FavoriteMutator.setSession(id: session.id, favorite: true)
        }
        let phrase = status == .authorized ? "Reminder set." : "Saved. Reminders need permission before they can alert."
        return .result(dialog: IntentDialog(stringLiteral: phrase))
    }
}
