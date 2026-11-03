import AppIntents
import Foundation

/// Phrases the host app should register.
///
/// App Shortcuts are discovered from the application target. Link this
/// product and declare a provider in the app:
///
/// ```swift
/// struct HostShortcuts: AppShortcutsProvider {
///     static var appShortcuts: [AppShortcut] { ConferenceShortcutTemplate.shortcuts }
///     static var shortcutTileColor: ShortcutTileColor = .orange
/// }
/// ```
public enum ConferenceShortcutTemplate {
    public static var shortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: WhatsNextIntent(),
                phrases: [
                    "What's next at \(.applicationName)",
                    "What's on now at \(.applicationName)"
                ],
                shortTitle: "What's Next",
                systemImageName: "clock"
            ),
            AppShortcut(
                intent: OpenSessionIntent(),
                phrases: [
                    "Open \(\.$target) in \(.applicationName)",
                    "Show \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Open Session",
                systemImageName: "calendar"
            ),
            AppShortcut(
                intent: OpenSpeakerIntent(),
                phrases: [
                    "Open speaker \(\.$target) in \(.applicationName)",
                    "Who is \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Open Speaker",
                systemImageName: "person"
            ),
            AppShortcut(
                intent: MyScheduleTodayIntent(),
                phrases: [
                    "My schedule today in \(.applicationName)",
                    "What did I save in \(.applicationName)"
                ],
                shortTitle: "My Schedule",
                systemImageName: "star"
            ),
            AppShortcut(
                intent: SearchSessionsIntent(),
                phrases: [
                    "Search \(\.$query) in \(.applicationName)",
                    "Find a session in \(.applicationName)"
                ],
                shortTitle: "Search Sessions",
                systemImageName: "magnifyingglass"
            ),
            AppShortcut(
                intent: SetSessionFavoriteIntent(),
                phrases: [
                    "Save \(\.$session) in \(.applicationName)",
                    "Favorite \(\.$session) in \(.applicationName)"
                ],
                shortTitle: "Favorite Session",
                systemImageName: "star.fill"
            ),
            AppShortcut(
                intent: AddNoteToCurrentSessionIntent(),
                phrases: [
                    "Add a note in \(.applicationName)",
                    "Take a note with \(.applicationName)"
                ],
                shortTitle: "Add Note",
                systemImageName: "note.text"
            ),
            AppShortcut(
                intent: ShowSessionNotesIntent(),
                phrases: [
                    "Show my notes for \(\.$session) in \(.applicationName)"
                ],
                shortTitle: "Show Notes",
                systemImageName: "note.text"
            ),
            AppShortcut(
                intent: ExportConferenceNotesIntent(),
                phrases: [
                    "Export my notes from \(.applicationName)"
                ],
                shortTitle: "Export Notes",
                systemImageName: "square.and.arrow.up"
            )
        ]
    }
}

public struct ConferenceAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] { ConferenceShortcutTemplate.shortcuts }
    public static var shortcutTileColor: ShortcutTileColor = .orange
}
