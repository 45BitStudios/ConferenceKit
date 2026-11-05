import Foundation

public struct AnnouncementNotice: Hashable, Sendable {
    public var newsID: String
    public var identifier: String
    public var title: String
    public var body: String

    public init(newsID: String, identifier: String, title: String, body: String) {
        self.newsID = newsID
        self.identifier = identifier
        self.title = title
        self.body = body
    }
}

/// Which news items should raise a local notification. AlarmKit is not used here.
public enum AnnouncementPlanner {
    public static func identifier(conferenceID: String, newsID: String) -> String {
        "conferencekit.news.\(conferenceID).\(newsID)"
    }

    public static func excerpt(_ body: String, limit: Int = 180) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit, limit > 0 else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return trimmed[..<end].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    public static func notices(
        items: [ConferenceNewsItem],
        conferenceID: String,
        alreadyScheduled: Set<String>,
        enabled: Bool
    ) -> [AnnouncementNotice] {
        guard enabled else { return [] }
        return NewsFeed.sorted(items).compactMap { item in
            guard item.announces, !alreadyScheduled.contains(item.id) else { return nil }
            return AnnouncementNotice(
                newsID: item.id,
                identifier: identifier(conferenceID: conferenceID, newsID: item.id),
                title: item.title,
                body: excerpt(item.body)
            )
        }
    }
}

public enum AnnouncementLedger {
    public static let enabledKey = "conferencekit.announcementNotificationsEnabled"

    public static func isEnabled(_ defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    public static func setEnabled(_ enabled: Bool, defaults: UserDefaults) {
        defaults.set(enabled, forKey: enabledKey)
    }

    public static func scheduledIDs(conferenceID: String, defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey(conferenceID)) ?? [])
    }

    public static func save(_ ids: Set<String>, conferenceID: String, defaults: UserDefaults) {
        defaults.set(ids.sorted(), forKey: storageKey(conferenceID))
    }

    private static func storageKey(_ conferenceID: String) -> String {
        "conferencekit.announcedNews.\(conferenceID)"
    }
}

/// Schedules announcement notifications through UserNotifications.
/// Session alarms stay on `SessionReminderCenter` (AlarmKit only when opted in,
/// otherwise the same notification fallback). This type never calls AlarmKit.
public enum NewsNotificationCenter {
    @discardableResult
    public static func sync(
        items: [ConferenceNewsItem],
        conferenceID: String,
        enabled: Bool,
        defaults: UserDefaults,
        requestPermission: Bool
    ) async -> [AnnouncementNotice] {
        let already = AnnouncementLedger.scheduledIDs(conferenceID: conferenceID, defaults: defaults)
        let pending = AnnouncementPlanner.notices(
            items: items,
            conferenceID: conferenceID,
            alreadyScheduled: already,
            enabled: enabled
        )
        guard !pending.isEmpty else { return [] }
        var status = await NotificationReminderBackend.authorization()
        if status == .notDetermined, requestPermission {
            status = await NotificationReminderBackend.requestAuthorization()
        }
        guard status == .authorized else { return [] }
        await NotificationReminderBackend.scheduleAnnouncements(pending)
        var ids = already
        for notice in pending { ids.insert(notice.newsID) }
        AnnouncementLedger.save(ids, conferenceID: conferenceID, defaults: defaults)
        return pending
    }

    /// Cancels pending announcement alerts and forgets them so a later opt-in can schedule again.
    public static func cancel(conferenceID: String?, defaults: UserDefaults) async {
        guard let conferenceID else { return }
        let ids = AnnouncementLedger.scheduledIDs(conferenceID: conferenceID, defaults: defaults)
        let identifiers = ids.map { AnnouncementPlanner.identifier(conferenceID: conferenceID, newsID: $0) }
        await NotificationReminderBackend.cancel(identifiers: identifiers)
        AnnouncementLedger.save([], conferenceID: conferenceID, defaults: defaults)
    }
}
