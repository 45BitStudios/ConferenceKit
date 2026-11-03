import Foundation

public struct ReminderPlan: Hashable, Sendable {
    public var sessionID: String
    public var conferenceID: String
    public var title: String
    public var fireDate: Date
    public var alarmID: UUID

    public init(sessionID: String, conferenceID: String, title: String, fireDate: Date, alarmID: UUID) {
        self.sessionID = sessionID
        self.conferenceID = conferenceID
        self.title = title
        self.fireDate = fireDate
        self.alarmID = alarmID
    }

    public var notificationIdentifier: String {
        "conferencekit.reminder.\(conferenceID).\(sessionID)"
    }
}

public struct ScheduledReminderRecord: Codable, Hashable, Sendable {
    public var sessionID: String
    public var alarmID: UUID
    public var fireDate: Date
    public var backend: String

    public init(sessionID: String, alarmID: UUID, fireDate: Date, backend: String) {
        self.sessionID = sessionID
        self.alarmID = alarmID
        self.fireDate = fireDate
        self.backend = backend
    }
}

/// Pure planning for "alert me this long before a favorited session".
/// AlarmKit and UserNotifications both consume the same plans.
public enum ReminderScheduler {
    public static func plan(
        session: Session,
        conferenceID: String,
        leadTime: TimeInterval,
        now: Date = .now
    ) -> ReminderPlan? {
        let lead = max(0, leadTime)
        let fireDate = session.startTime.addingTimeInterval(-lead)
        guard fireDate > now else { return nil }
        return ReminderPlan(
            sessionID: session.id,
            conferenceID: conferenceID,
            title: session.title,
            fireDate: fireDate,
            alarmID: StableIdentifier.uuid(namespace: "conferencekit.alarm.\(conferenceID)", value: session.id)
        )
    }

    public static func plans(
        sessions: [Session],
        conferenceID: String,
        favoriteIDs: Set<String>,
        leadTime: TimeInterval,
        now: Date = .now
    ) -> [ReminderPlan] {
        sessions.compactMap { session in
            guard favoriteIDs.contains(session.id) else { return nil }
            return plan(session: session, conferenceID: conferenceID, leadTime: leadTime, now: now)
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    public static let recordsKey = "conferencekit.scheduledReminders"

    public static func loadRecords(defaults: UserDefaults) -> [ScheduledReminderRecord] {
        guard let data = defaults.data(forKey: recordsKey) else { return [] }
        return (try? JSONDecoder().decode([ScheduledReminderRecord].self, from: data)) ?? []
    }

    public static func saveRecords(_ records: [ScheduledReminderRecord], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }
}
