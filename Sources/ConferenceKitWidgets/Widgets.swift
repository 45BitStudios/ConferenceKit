#if canImport(WidgetKit) && !os(tvOS) && !os(visionOS)
import AppIntents
import ConferenceKit
import ConferenceKitIntents
import SwiftUI
import WidgetKit

public struct ScheduleEntry: TimelineEntry {
    public var date: Date
    public var conferenceName: String
    public var accentHex: String
    public var title: String
    public var subtitle: String
    public var footnote: String
    public var sessionID: String?
    public var isFavorite: Bool
    public var isLive: Bool

    public init(
        date: Date = .now,
        conferenceName: String,
        accentHex: String,
        title: String,
        subtitle: String,
        footnote: String,
        sessionID: String? = nil,
        isFavorite: Bool = false,
        isLive: Bool = false
    ) {
        self.date = date
        self.conferenceName = conferenceName
        self.accentHex = accentHex
        self.title = title
        self.subtitle = subtitle
        self.footnote = footnote
        self.sessionID = sessionID
        self.isFavorite = isFavorite
        self.isLive = isLive
    }

    static let placeholder = ScheduleEntry(
        conferenceName: "Conference",
        accentHex: "#FF6A00",
        title: "Opening Keynote",
        subtitle: "9:00 AM",
        footnote: "Main Stage",
        sessionID: "placeholder",
        isLive: true
    )
}

enum WidgetSchedule {
    static func snapshot() -> ConferenceSnapshot? {
        ConferenceSnapshotStore.load()
    }

    static func favoriteIDs(in snapshot: ConferenceSnapshot) -> Set<String> {
        let stored = FavoritesStore.readSessionIDs(
            conferenceID: snapshot.manifest.conference.id,
            defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
        )
        return stored.isEmpty ? Set(snapshot.favoriteSessionIDs) : stored
    }

    static func upNextEntry(at now: Date = .now) -> ScheduleEntry {
        guard let snapshot = snapshot() else { return .placeholder }
        let manifest = snapshot.manifest
        let favorites = favoriteIDs(in: snapshot)
        if let live = ConferenceSearch.liveSessions(in: manifest.sessions, at: now).first {
            return entry(for: live, manifest: manifest, favorites: favorites, live: true)
        }
        if let next = ConferenceSearch.nextUp(in: manifest.sessions, at: now).first {
            return entry(for: next, manifest: manifest, favorites: favorites, live: false)
        }
        return ScheduleEntry(
            conferenceName: manifest.conference.name,
            accentHex: manifest.theme.accent,
            title: "That's a wrap",
            subtitle: manifest.conference.name,
            footnote: "No upcoming sessions"
        )
    }

    static func myScheduleEntry(at now: Date = .now) -> ScheduleEntry {
        guard let snapshot = snapshot() else { return .placeholder }
        let manifest = snapshot.manifest
        let favorites = favoriteIDs(in: snapshot)
        let saved = manifest.sessions.filter { favorites.contains($0.id) && $0.endTime >= now }
        guard let first = saved.first else {
            return ScheduleEntry(
                conferenceName: manifest.conference.name,
                accentHex: manifest.theme.accent,
                title: "My Schedule",
                subtitle: "Nothing saved yet",
                footnote: manifest.conference.name
            )
        }
        var entry = entry(for: first, manifest: manifest, favorites: favorites, live: first.isHappening(at: now))
        entry.footnote = "\(saved.count) saved"
        return entry
    }

    static func countdownEntry(at now: Date = .now) -> ScheduleEntry {
        guard let snapshot = snapshot() else { return .placeholder }
        let manifest = snapshot.manifest
        let clock = manifest.clock
        let interval = clock.interval(startDay: manifest.conference.startDate, endDay: manifest.conference.endDate)
        let phase = clock.phase(interval: interval, at: now)
        let title: String
        let subtitle: String
        switch phase {
        case .before:
            let days = interval.map { max(0, clock.calendar.dateComponents([.day], from: now, to: $0.start).day ?? 0) } ?? 0
            title = days == 0 ? "Today" : "\(days)d"
            subtitle = "until \(manifest.conference.name)"
        case .during:
            title = "Now"
            subtitle = manifest.conference.name
        case .after:
            title = "Done"
            subtitle = manifest.conference.name
        }
        return ScheduleEntry(
            conferenceName: manifest.conference.name,
            accentHex: manifest.theme.accent,
            title: title,
            subtitle: subtitle,
            footnote: clock.dayString(interval?.start ?? .now)
        )
    }

    static func favoriteEntry(sessionID: String?, speakerID: String?, at now: Date = .now) -> ScheduleEntry {
        guard let snapshot = snapshot() else { return .placeholder }
        let manifest = snapshot.manifest
        let favorites = favoriteIDs(in: snapshot)
        if let sessionID, let session = manifest.session(id: sessionID) {
            return entry(for: session, manifest: manifest, favorites: favorites, live: session.isHappening(at: now))
        }
        if let speakerID, let speaker = manifest.speaker(id: speakerID) {
            let next = manifest.sessions(for: speakerID).first { $0.endTime >= now }
            return ScheduleEntry(
                conferenceName: manifest.conference.name,
                accentHex: manifest.theme.accent,
                title: speaker.name,
                subtitle: speaker.affiliation,
                footnote: next?.title ?? "Speaker",
                sessionID: next?.id,
                isFavorite: favorites.contains(next?.id ?? "")
            )
        }
        if let saved = manifest.sessions.first(where: { favorites.contains($0.id) }) {
            return entry(for: saved, manifest: manifest, favorites: favorites, live: saved.isHappening(at: now))
        }
        return upNextEntry(at: now)
    }

    static func timeline(sessions: [Session], build: (Date) -> ScheduleEntry) -> Timeline<ScheduleEntry> {
        let now = Date()
        var dates = [now]
        for session in sessions where session.endTime > now {
            if session.startTime > now { dates.append(session.startTime) }
            dates.append(session.endTime)
            if dates.count > 24 { break }
        }
        let unique = Array(Set(dates)).sorted()
        let entries = unique.map { date in
            var entry = build(date)
            entry.date = date
            return entry
        }
        let refresh = unique.dropFirst().first ?? now.addingTimeInterval(30 * 60)
        return Timeline(entries: entries, policy: .after(refresh))
    }

    private static func entry(for session: Session, manifest: ConferenceManifest, favorites: Set<String>, live: Bool) -> ScheduleEntry {
        let clock = manifest.clock
        let room = session.roomID.flatMap { manifest.room(id: $0)?.name }
        return ScheduleEntry(
            conferenceName: manifest.conference.name,
            accentHex: manifest.theme.accent,
            title: session.title,
            subtitle: clock.rangeString(from: session.startTime, to: session.endTime),
            footnote: room ?? session.kind.label,
            sessionID: session.id,
            isFavorite: favorites.contains(session.id),
            isLive: live
        )
    }
}

public struct UpNextProvider: TimelineProvider {
    public init() {}
    public func placeholder(in context: Context) -> ScheduleEntry { .placeholder }
    public func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(WidgetSchedule.upNextEntry())
    }
    public func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let sessions = WidgetSchedule.snapshot()?.manifest.sessions ?? []
        completion(WidgetSchedule.timeline(sessions: sessions) { WidgetSchedule.upNextEntry(at: $0) })
    }
}

public struct NowLiveProvider: TimelineProvider {
    public init() {}
    public func placeholder(in context: Context) -> ScheduleEntry { .placeholder }
    public func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(WidgetSchedule.upNextEntry())
    }
    public func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let sessions = WidgetSchedule.snapshot()?.manifest.sessions ?? []
        completion(WidgetSchedule.timeline(sessions: sessions) { WidgetSchedule.upNextEntry(at: $0) })
    }
}

public struct MyScheduleProvider: TimelineProvider {
    public init() {}
    public func placeholder(in context: Context) -> ScheduleEntry { .placeholder }
    public func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(WidgetSchedule.myScheduleEntry())
    }
    public func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let sessions = WidgetSchedule.snapshot()?.manifest.sessions ?? []
        completion(WidgetSchedule.timeline(sessions: sessions) { WidgetSchedule.myScheduleEntry(at: $0) })
    }
}

public struct CountdownProvider: TimelineProvider {
    public init() {}
    public func placeholder(in context: Context) -> ScheduleEntry { .placeholder }
    public func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(WidgetSchedule.countdownEntry())
    }
    public func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let sessions = WidgetSchedule.snapshot()?.manifest.sessions ?? []
        completion(WidgetSchedule.timeline(sessions: sessions) { WidgetSchedule.countdownEntry(at: $0) })
    }
}

public struct FavoriteWidgetConfiguration: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Favorite"
    public static var description = IntentDescription("Show a saved session or speaker.")

    @Parameter(title: "Session")
    public var session: SessionEntity?

    @Parameter(title: "Speaker")
    public var speaker: SpeakerEntity?

    public init() {}
}

public struct FavoriteProvider: AppIntentTimelineProvider {
    public typealias Entry = ScheduleEntry
    public typealias Intent = FavoriteWidgetConfiguration

    public init() {}

    public func placeholder(in context: Context) -> ScheduleEntry { .placeholder }

    public func snapshot(for configuration: FavoriteWidgetConfiguration, in context: Context) async -> ScheduleEntry {
        WidgetSchedule.favoriteEntry(sessionID: configuration.session?.id, speakerID: configuration.speaker?.id)
    }

    public func timeline(for configuration: FavoriteWidgetConfiguration, in context: Context) async -> Timeline<ScheduleEntry> {
        let sessions = WidgetSchedule.snapshot()?.manifest.sessions ?? []
        let sessionID = configuration.session?.id
        let speakerID = configuration.speaker?.id
        return WidgetSchedule.timeline(sessions: sessions) {
            WidgetSchedule.favoriteEntry(sessionID: sessionID, speakerID: speakerID, at: $0)
        }
    }
}

public struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ScheduleEntry
    var showsFavoriteButton: Bool

    public init(entry: ScheduleEntry, showsFavoriteButton: Bool = true) {
        self.entry = entry
        self.showsFavoriteButton = showsFavoriteButton
    }

    public var body: some View {
        content
            .containerBackground(for: .widget) {
                Color(hex: entry.accentHex)?.opacity(0.18) ?? Color.orange.opacity(0.18)
            }
            .widgetURL(entry.sessionID.flatMap { URL(string: "conferencekit://session/\($0)") })
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.isLive ? "Live · \(entry.title)" : entry.title)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: entry.isLive ? "dot.radiowaves.left.and.right" : "calendar")
                        .widgetAccentable()
                    Text(entry.title)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        #if os(watchOS)
        case .accessoryCorner:
            Text(entry.title)
                .widgetLabel { Text(entry.subtitle) }
        #endif
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.conferenceName).font(.caption2)
                Text(entry.title).font(.headline)
                Text(entry.subtitle).font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.isLive ? "Live" : entry.conferenceName)
                        .font(.caption)
                        .widgetAccentable()
                    Spacer()
                    if showsFavoriteButton, let sessionID = entry.sessionID {
                        Button(intent: SetSessionFavoriteByIDIntent(sessionID: sessionID, favorite: !entry.isFavorite)) {
                            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        }
                        .accessibilityLabel(entry.isFavorite ? "Remove Favorite" : "Favorite")
                    }
                }
                Text(entry.title)
                    .font(.headline)
                Text(entry.subtitle)
                    .font(.subheadline)
                Text(entry.footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

public struct UpNextWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "conferencekit.up-next", provider: UpNextProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("The next session on the schedule.")
        .supportedFamilies(WidgetFamilies.standard)
    }
}

public struct NowLiveWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "conferencekit.now", provider: NowLiveProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Now")
        .description("The session that's on, or the next one.")
        .supportedFamilies(WidgetFamilies.compact)
    }
}

public struct MyScheduleWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "conferencekit.my-schedule", provider: MyScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("My Schedule")
        .description("The next session you saved.")
        .supportedFamilies(WidgetFamilies.large)
    }
}

public struct CountdownWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "conferencekit.countdown", provider: CountdownProvider()) { entry in
            ScheduleWidgetView(entry: entry, showsFavoriteButton: false)
        }
        .configurationDisplayName("Countdown")
        .description("How long until the conference starts.")
        .supportedFamilies(WidgetFamilies.compact)
    }
}

public struct FavoriteWidget: Widget {
    public init() {}
    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "conferencekit.favorite",
            intent: FavoriteWidgetConfiguration.self,
            provider: FavoriteProvider()
        ) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorite")
        .description("A saved session or speaker.")
        .supportedFamilies(WidgetFamilies.standard)
    }
}

enum WidgetFamilies {
    static var compact: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #elseif os(iOS)
        [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall]
        #endif
    }

    static var standard: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #elseif os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        #elseif os(macOS)
        [.systemSmall, .systemMedium, .systemLarge]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }

    static var large: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular, .accessoryInline]
        #elseif os(macOS)
        [.systemMedium, .systemLarge, .systemExtraLarge]
        #elseif os(iOS)
        [.systemMedium, .systemLarge, .accessoryRectangular]
        #else
        [.systemMedium, .systemLarge]
        #endif
    }
}

public struct ConferenceWidgetBundle: WidgetBundle {
    public init() {}
    public var body: some Widget {
        UpNextWidget()
        NowLiveWidget()
        MyScheduleWidget()
        CountdownWidget()
        FavoriteWidget()
    }
}

#if os(iOS)
@available(iOS 18.0, *)
public struct ConferenceFavoriteControl: ControlWidget {
    public init() {}
    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "conferencekit.favorite-next") {
            ControlWidgetButton(action: FavoriteNextSessionIntent()) {
                Label("Favorite Next", systemImage: "star")
            }
        }
        .displayName("Favorite Next")
        .description("Save the next session.")
    }
}
#endif

#else

public enum ConferenceWidgetsAvailability {
    public static let supported = false
}

#endif
