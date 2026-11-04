import ConferenceKit
import SwiftUI
import UserNotifications

/// Shows what the reminder path actually scheduled with UserNotifications.
struct DiagnosticsView: View {
    var store: ConferenceStore
    @State private var authorization = "?"
    @State private var pending: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Reminders") {
                    Text("enabled=\(store.reminderPreferences.enabled ? "true" : "false") lead=\(Int(store.reminderPreferences.leadTime / 60))m alarmKit=\(ConferenceKitConfiguration.shared.usesAlarmKit() ? "on" : "off")")
                    Text("favorites=\(store.favorites.ids.count)")
                    Text("authorization=\(authorization)")
                        .accessibilityIdentifier("diag.auth")
                    Text("pending=\(pending.count)")
                        .accessibilityIdentifier("diag.pending")
                    ForEach(pending, id: \.self) { Text($0).font(.caption.monospaced()) }
                }
                Button("Request notification permission") {
                    Task {
                        let status = await SessionReminderCenter.shared.requestAuthorization()
                        print("CKDEMO REMINDERS requestAuthorization=\(status)")
                        await refresh()
                    }
                }
                .accessibilityIdentifier("diag.requestAuth")
                Button("Refresh") { Task { await refresh() } }
                    .accessibilityIdentifier("diag.refresh")
            }
            .navigationTitle("Diagnostics")
            .task { await refresh() }
        }
    }

    private func refresh() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorization = "\(settings.authorizationStatus.rawValue)"
        let requests = await center.pendingNotificationRequests()
        pending = requests.map { request in
            #if os(tvOS)
            var line = request.identifier // tvOS notifications carry no title
            #else
            var line = "\(request.identifier) | \(request.content.title)"
            #endif
            if let trigger = request.trigger as? UNCalendarNotificationTrigger, let date = trigger.nextTriggerDate() {
                line += " | \(date.formatted(date: .abbreviated, time: .shortened))"
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                line += " | in \(Int(trigger.timeInterval))s"
            }
            return line
        }
        print("CKDEMO REMINDERS auth=\(authorization) pending=\(pending.count) \(pending)")
    }
}
