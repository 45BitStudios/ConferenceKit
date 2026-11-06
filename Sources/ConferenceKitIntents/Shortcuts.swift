import AppIntents
import Foundation

/// Exposes this package's intents, entities, and queries to the host app.
///
/// Add to the app target so its metadata extraction pulls in the package:
///
/// ```swift
/// struct HostIntentsPackage: AppIntentsPackage {
///     static var includedPackages: [any AppIntentsPackage.Type] {
///         [ConferenceIntentsPackage.self]
///     }
/// }
/// ```
public struct ConferenceIntentsPackage: AppIntentsPackage {}

/// App Shortcut phrases for the conference intents.
///
/// Apple’s App Shortcuts cap is ten. This provider is at that cap.
/// Search Attendees stays a normal intent so the directory is still reachable.
///
/// `AppShortcutsBuilder` needs literal `AppShortcut` expressions, so the list
/// lives in `ConferenceAppShortcuts`. A host app that declares its own
/// provider copies the entries it wants; `shortcuts` returns the same list for
/// code that just needs the values.
public enum ConferenceShortcutTemplate {
    public static var shortcuts: [AppShortcut] { ConferenceAppShortcuts.appShortcuts }
}

public struct ConferenceAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: WhatsNextIntent(),
                phrases: [
                    "What's next at \(.applicationName)",
                    "What's on now at \(.applicationName)"
                ],
                shortTitle: "What's Next",
                systemImageName: "clock"
            )
            AppShortcut(
                intent: OpenSessionIntent(),
                phrases: [
                    "Open \(\.$target) in \(.applicationName)",
                    "Show \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Open Session",
                systemImageName: "calendar"
            )
            AppShortcut(
                intent: OpenSpeakerIntent(),
                phrases: [
                    "Open speaker \(\.$target) in \(.applicationName)",
                    "Who is \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Open Speaker",
                systemImageName: "person"
            )
            AppShortcut(
                intent: MyScheduleTodayIntent(),
                phrases: [
                    "My schedule today in \(.applicationName)",
                    "What did I save in \(.applicationName)"
                ],
                shortTitle: "My Schedule",
                systemImageName: "star"
            )
            AppShortcut(
                intent: SearchSessionsIntent(),
                phrases: [
                    "Find a session in \(.applicationName)",
                    "Search sessions in \(.applicationName)"
                ],
                shortTitle: "Search Sessions",
                systemImageName: "magnifyingglass"
            )
            AppShortcut(
                intent: SetSessionFavoriteIntent(),
                phrases: [
                    "Save \(\.$session) in \(.applicationName)",
                    "Favorite \(\.$session) in \(.applicationName)"
                ],
                shortTitle: "Favorite Session",
                systemImageName: "star.fill"
            )
            AppShortcut(
                intent: AddNoteToCurrentSessionIntent(),
                phrases: [
                    "Add a note in \(.applicationName)",
                    "Take a note with \(.applicationName)"
                ],
                shortTitle: "Add Note",
                systemImageName: "note.text"
            )
            AppShortcut(
                intent: ShowSessionNotesIntent(),
                phrases: [
                    "Show my notes for \(\.$session) in \(.applicationName)"
                ],
                shortTitle: "Show Notes",
                systemImageName: "note.text"
            )
            AppShortcut(
                intent: ExportConferenceNotesIntent(),
                phrases: [
                    "Export my notes from \(.applicationName)"
                ],
                shortTitle: "Export Notes",
                systemImageName: "square.and.arrow.up"
            )
            AppShortcut(
                intent: OpenAttendeeIntent(),
                phrases: [
                    "Find \(\.$target) in \(.applicationName)",
                    "Open attendee \(\.$target) in \(.applicationName)"
                ],
                shortTitle: "Find Attendee",
                systemImageName: "person.crop.rectangle"
            )
    }

    public static let shortcutTileColor: ShortcutTileColor = .orange
}
