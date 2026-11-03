import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

public enum ReminderAuthorization: String, Sendable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

public enum ReminderBackendKind: String, Sendable {
    case alarmKit
    case notification
    case none
}

public protocol SessionAlarmBackend: Sendable {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async -> ReminderAuthorization
    func schedule(plans: [ReminderPlan], conferenceName: String) async throws
    func cancel(alarmIDs: [UUID]) async
}

/// Keeps favorited-session reminders in sync.
///
/// AlarmKit (iOS 26+) is used when a backend has been registered and the
/// attendee allowed alarms. Otherwise the same plans go through
/// UserNotifications, which is the fallback on older systems and on
/// platforms without AlarmKit.
public final class SessionReminderCenter: @unchecked Sendable {
    public static let shared = SessionReminderCenter()

    private let lock = NSLock()
    private var backend: (any SessionAlarmBackend)?

    public func registerAlarmBackend(_ backend: any SessionAlarmBackend) {
        lock.lock()
        self.backend = backend
        lock.unlock()
    }

    public func alarmBackend() -> (any SessionAlarmBackend)? {
        lock.lock()
        defer { lock.unlock() }
        return backend
    }

    public func authorization() async -> ReminderAuthorization {
        if let backend = alarmBackend() {
            return await backend.authorization()
        }
        return await NotificationReminderBackend.authorization()
    }

    public func requestAuthorization() async -> ReminderAuthorization {
        if let backend = alarmBackend() {
            let status = await backend.requestAuthorization()
            if status == .authorized { return status }
        }
        return await NotificationReminderBackend.requestAuthorization()
    }

    /// Replace reminders so they match the current favorite set.
    @discardableResult
    public func sync(
        manifest: ConferenceManifest,
        favoriteIDs: Set<String>,
        preferences: ReminderPreferences,
        defaults: UserDefaults,
        now: Date = .now
    ) async -> [ReminderPlan] {
        let existing = ReminderScheduler.loadRecords(defaults: defaults)
        let plans = preferences.enabled
            ? ReminderScheduler.plans(
                sessions: manifest.sessions,
                conferenceID: manifest.conference.id,
                favoriteIDs: favoriteIDs,
                leadTime: preferences.leadTime,
                now: now
            )
            : []

        let removed = existing.filter { record in
            !plans.contains { $0.sessionID == record.sessionID }
        }
        if !removed.isEmpty {
            await alarmBackend()?.cancel(alarmIDs: removed.map(\.alarmID))
            await NotificationReminderBackend.cancel(identifiers: removed.map {
                "conferencekit.reminder.\(manifest.conference.id).\($0.sessionID)"
            })
        }

        guard preferences.enabled else {
            ReminderScheduler.saveRecords([], defaults: defaults)
            return []
        }

        var records: [ScheduledReminderRecord] = []
        if let backend = alarmBackend(), await backend.authorization() == .authorized {
            try? await backend.schedule(plans: plans, conferenceName: manifest.conference.name)
            records = plans.map {
                ScheduledReminderRecord(sessionID: $0.sessionID, alarmID: $0.alarmID, fireDate: $0.fireDate, backend: ReminderBackendKind.alarmKit.rawValue)
            }
        } else {
            await NotificationReminderBackend.schedule(plans: plans, conferenceName: manifest.conference.name)
            records = plans.map {
                ScheduledReminderRecord(sessionID: $0.sessionID, alarmID: $0.alarmID, fireDate: $0.fireDate, backend: ReminderBackendKind.notification.rawValue)
            }
        }
        ReminderScheduler.saveRecords(records, defaults: defaults)
        return plans
    }
}

enum NotificationReminderBackend {
    static func authorization() async -> ReminderAuthorization {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
        #else
        return .unavailable
        #endif
    }

    static func requestAuthorization() async -> ReminderAuthorization {
        #if canImport(UserNotifications)
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    static func schedule(plans: [ReminderPlan], conferenceName: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.subtitle = conferenceName
            content.body = "Starts soon."
            content.sound = .default
            content.userInfo = ["sessionID": plan.sessionID]
            let interval = plan.fireDate.timeIntervalSinceNow
            guard interval > 1 else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: plan.notificationIdentifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
        #endif
    }

    static func cancel(identifiers: [String]) async {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        #endif
    }
}
