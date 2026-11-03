import ConferenceKit
import Foundation

#if canImport(AlarmKit) && os(iOS)
import AlarmKit
import AppIntents
import SwiftUI

/// Fixed alarms, not countdown timers, so the host does not have to ship an
/// AlarmKit Live Activity. A secondary button opens the session.
@available(iOS 26.0, *)
public struct SessionAlarmMetadata: AlarmMetadata {
    public var sessionID: String
    public var title: String

    public init(sessionID: String, title: String) {
        self.sessionID = sessionID
        self.title = title
    }
}

@available(iOS 26.0, *)
public struct OpenSessionFromAlarmIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Open Session"
    public static let description = IntentDescription("Open the session this alarm belongs to.")
    public static let openAppWhenRun = true

    @Parameter(title: "Session")
    public var sessionID: String

    public init() {
        sessionID = ""
    }

    public init(sessionID: String) {
        self.sessionID = sessionID
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        ConferenceNavigation.shared.openSession(id: sessionID)
        return .result()
    }
}

@available(iOS 26.0, *)
struct AlarmKitSessionBackend: SessionAlarmBackend {
    func authorization() async -> ReminderAuthorization {
        switch AlarmManager.shared.authorizationState {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> ReminderAuthorization {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            return state == .authorized ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func schedule(plans: [ReminderPlan], conferenceName: String) async throws {
        for plan in plans {
            let stop = AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "stop.circle")
            let open = AlarmButton(text: "Open", textColor: .white, systemImageName: "arrow.right.circle")
            let alert = AlarmPresentation.Alert(
                title: "\(plan.title)",
                stopButton: stop,
                secondaryButton: open,
                secondaryButtonBehavior: .custom
            )
            let attributes = AlarmAttributes<SessionAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: SessionAlarmMetadata(sessionID: plan.sessionID, title: plan.title),
                tintColor: .orange
            )
            let configuration = AlarmManager.AlarmConfiguration(
                schedule: .fixed(plan.fireDate),
                attributes: attributes,
                secondaryIntent: OpenSessionFromAlarmIntent(sessionID: plan.sessionID)
            )
            _ = try await AlarmManager.shared.schedule(id: plan.alarmID, configuration: configuration)
            _ = conferenceName
        }
    }

    func cancel(alarmIDs: [UUID]) async {
        for id in alarmIDs {
            try? AlarmManager.shared.cancel(id: id)
        }
    }
}
#endif

public enum ConferenceIntentsBootstrap {
    /// Registers AlarmKit only when `ConferenceKitConfiguration.usesAlarmKit()` is true.
    /// The default path is a local notification. AlarmKit also needs the entitlement.
    @MainActor
    public static func prepare() {
        guard ConferenceKitConfiguration.shared.usesAlarmKit() else {
            SessionReminderCenter.shared.clearAlarmBackend()
            return
        }
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.0, *) {
            SessionReminderCenter.shared.registerAlarmBackend(AlarmKitSessionBackend())
            return
        }
        #endif
        SessionReminderCenter.shared.clearAlarmBackend()
    }

    @MainActor
    public static func didLoad(_ store: ConferenceStore) async {
        guard let manifest = store.manifest else { return }
        await ConferenceSpotlight.reindex(manifest)
        #if SIRI_AI_PREVIEW
        await ConferenceSiriPreviewIndex.reindex(manifest)
        #endif
        _ = await SessionReminderCenter.shared.sync(
            manifest: manifest,
            favoriteIDs: store.favorites.ids,
            preferences: store.reminderPreferences,
            defaults: ConferenceKitConfiguration.shared.resolvedDefaults()
        )
        ConferenceAppShortcuts.updateAppShortcutParameters()
    }
}
