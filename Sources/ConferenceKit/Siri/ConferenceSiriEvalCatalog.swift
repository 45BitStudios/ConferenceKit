import Foundation

/// Fixture data for the signed-device Siri evaluation target.
///
/// This file does not import SiriEvaluations. `swift test` can read it.
/// `SiriPreview/Evaluations/ConferenceSiriEvaluation.swift` turns the cases
/// marked `includeInDeviceScenario` into `SiriScenario` values. Cases that
/// need the network off stay in this catalog and are run by hand. See
/// `docs/siri-evals-device-run.md`.
public struct ConferenceSiriEvalCase: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Equatable, CaseIterable {
        /// The utterance should select one custom Siri tool.
        case toolSelection
        /// Another wording for a tool already covered by a direct case.
        case paraphrase
        /// The request is outside the custom tools, or the named session is not on the schedule.
        case negative
        /// Unlock plus a confirmation before contact fields, or a confirmation before a drafted note is saved.
        case authConfirmation
        /// Custom tool unavailable. The person uses the screen in the app. Not sent to `SiriService` while the connection is up.
        case offlineFallback
    }

    public var id: String
    public var skillName: String
    public var kind: Kind
    public var utterance: String
    /// Intent `Calls` should name. A custom tool from `SiriCustomToolCatalog`, or `ReadPublicAttendeeContactIntent`.
    /// Nil when this case must not be scored as a successful tool call.
    public var toolName: String?
    /// Tools that must not be treated as the way to finish this request.
    /// `Calls` cannot assert this. The host tests only check the names exist.
    public var mustNotCall: [String]
    /// Fragment passed to `SiriResponse(.contains)`. Nil when the spoken form is not a fixed string.
    public var responseContains: String?
    /// What the tool should receive, in words. `Calls` names the intent and does not match these words.
    public var parameterNote: String
    /// False for the network-off pass. `SiriService.run` cannot drop Private Cloud Compute with the symbols this target uses.
    public var includeInDeviceScenario: Bool

    public init(
        id: String,
        skillName: String,
        kind: Kind,
        utterance: String,
        toolName: String? = nil,
        mustNotCall: [String] = [],
        responseContains: String? = nil,
        parameterNote: String = "",
        includeInDeviceScenario: Bool = true
    ) {
        self.id = id
        self.skillName = skillName
        self.kind = kind
        self.utterance = utterance
        self.toolName = toolName
        self.mustNotCall = mustNotCall
        self.responseContains = responseContains
        self.parameterNote = parameterNote
        self.includeInDeviceScenario = includeInDeviceScenario
    }
}

public enum ConferenceSiriEvalCatalog {
    public static let skillNames = [
        "plan-afternoon",
        "write-notes",
        "recall-notes",
        "export-notes",
        "find-attendee"
    ]

    /// Ordinary App Intent, not a `SIRI_AI_PREVIEW` tool. It is the unlock and confirmation path for public contact fields.
    public static let ordinaryIntentNames = [
        "ReadPublicAttendeeContactIntent"
    ]

    public static let cases: [ConferenceSiriEvalCase] = [
        // plan-afternoon
        ConferenceSiriEvalCase(
            id: "plan-next",
            skillName: "plan-afternoon",
            kind: .toolSelection,
            utterance: "What's next?",
            toolName: "WhatsNextTool",
            parameterNote: "favoritesOnly stays false. The spoken title is whatever is live, or next, so it is not a fixed fragment."
        ),
        ConferenceSiriEvalCase(
            id: "plan-next-paraphrase",
            skillName: "plan-afternoon",
            kind: .paraphrase,
            utterance: "Anything happening right now?",
            toolName: "WhatsNextTool",
            parameterNote: "Same as what's next. No session title in the request."
        ),
        ConferenceSiriEvalCase(
            id: "plan-find",
            skillName: "plan-afternoon",
            kind: .toolSelection,
            utterance: "Find the opening keynote",
            toolName: "FindSessionTool",
            responseContains: "Found",
            parameterNote: "Query is the words opening keynote. FindSessionTool says Found N sessions."
        ),
        ConferenceSiriEvalCase(
            id: "plan-find-paraphrase",
            skillName: "plan-afternoon",
            kind: .paraphrase,
            utterance: "Which talk is the opening keynote?",
            toolName: "FindSessionTool",
            responseContains: "Found",
            parameterNote: "Query is the words opening keynote."
        ),
        ConferenceSiriEvalCase(
            id: "plan-favorite",
            skillName: "plan-afternoon",
            kind: .toolSelection,
            utterance: "Save the opening keynote on my schedule",
            toolName: "FavoriteSessionTool",
            responseContains: "Saved",
            parameterNote: "Session is Opening Keynote and favorite is true. The tool first asks Save Opening Keynote on My Schedule? The final dialog is Saved Opening Keynote."
        ),
        ConferenceSiriEvalCase(
            id: "plan-out-of-scope",
            skillName: "plan-afternoon",
            kind: .negative,
            utterance: "Book me a flight to Chicago",
            mustNotCall: ["WhatsNextTool", "FindSessionTool", "FavoriteSessionTool"],
            responseContains: "in the app",
            parameterNote: "No session. The plan-afternoon skill tells Siri to send reminders and Calendar to the session screen in the app. A flight is the same kind of refusal."
        ),
        ConferenceSiriEvalCase(
            id: "plan-offline",
            skillName: "plan-afternoon",
            kind: .offlineFallback,
            utterance: "What's next?",
            mustNotCall: ["WhatsNextTool"],
            responseContains: "in the app",
            parameterNote: "WhatsNextTool stays unused. Open Schedule in the app.",
            includeInDeviceScenario: false
        ),

        // write-notes
        ConferenceSiriEvalCase(
            id: "write-add",
            skillName: "write-notes",
            kind: .toolSelection,
            utterance: "Add a note: ask about the fold",
            toolName: "AddNoteTool",
            responseContains: "Noted",
            parameterNote: "Text is ask about the fold. Session stays unset so the live session or the one on screen is used. AddNoteTool says Noted."
        ),
        ConferenceSiriEvalCase(
            id: "write-add-paraphrase",
            skillName: "write-notes",
            kind: .paraphrase,
            utterance: "Jot down that the fold matters",
            toolName: "AddNoteTool",
            responseContains: "Noted",
            parameterNote: "Text is the fold matters. Session stays unset."
        ),
        ConferenceSiriEvalCase(
            id: "write-create-confirm",
            skillName: "write-notes",
            kind: .authConfirmation,
            utterance: "Create a session note: the fold matters",
            toolName: "CreateSessionNoteIntent",
            responseContains: "Save this note",
            parameterNote: "Draft text is the fold matters. CreateSessionNoteIntent asks Save this note on <session>? before it writes. Cancel writes nothing. The final dialog after a yes is Saved a note on <session>."
        ),
        ConferenceSiriEvalCase(
            id: "write-empty",
            skillName: "write-notes",
            kind: .negative,
            utterance: "Add a note",
            responseContains: "empty",
            parameterNote: "No note text. The write-notes skill says to answer that it was empty and ask for the words. AddNoteTool is not required, because Siri may ask instead of calling it."
        ),
        ConferenceSiriEvalCase(
            id: "write-offline",
            skillName: "write-notes",
            kind: .offlineFallback,
            utterance: "Add a note: ask about the fold",
            mustNotCall: ["AddNoteTool", "CreateSessionNoteIntent"],
            responseContains: "in the app",
            parameterNote: "Open the session in the app and type the note.",
            includeInDeviceScenario: false
        ),

        // recall-notes
        ConferenceSiriEvalCase(
            id: "recall-show",
            skillName: "recall-notes",
            kind: .toolSelection,
            utterance: "Show my notes for the opening keynote",
            toolName: "ShowNotesTool",
            responseContains: "Notes for",
            parameterNote: "Session is Opening Keynote. ShowNotesTool says Notes for <title>."
        ),
        ConferenceSiriEvalCase(
            id: "recall-paraphrase",
            skillName: "recall-notes",
            kind: .paraphrase,
            utterance: "What did I write down about the keynote?",
            toolName: "ShowNotesTool",
            responseContains: "Notes for",
            parameterNote: "Session is the keynote. Do not invent note text."
        ),
        ConferenceSiriEvalCase(
            id: "recall-missing",
            skillName: "recall-notes",
            kind: .negative,
            utterance: "Show my notes for a talk that is not on the schedule",
            toolName: "FindSessionTool",
            responseContains: "No matching session",
            parameterNote: "The query will not resolve. FindSessionTool says No matching session. Do not invent a session and do not invent note text."
        ),
        ConferenceSiriEvalCase(
            id: "recall-offline",
            skillName: "recall-notes",
            kind: .offlineFallback,
            utterance: "Show my notes for the opening keynote",
            mustNotCall: ["ShowNotesTool"],
            responseContains: "in the app",
            parameterNote: "Open My Notes in the app.",
            includeInDeviceScenario: false
        ),

        // export-notes
        ConferenceSiriEvalCase(
            id: "export-all",
            skillName: "export-notes",
            kind: .toolSelection,
            utterance: "Export my notes",
            toolName: "ExportNotesTool",
            responseContains: "Exported",
            parameterNote: "No session filter. ExportNotesTool says Exported conference notes."
        ),
        ConferenceSiriEvalCase(
            id: "export-paraphrase",
            skillName: "export-notes",
            kind: .paraphrase,
            utterance: "Make a copy of everything I wrote",
            toolName: "ExportNotesTool",
            responseContains: "Exported",
            parameterNote: "Every note for this conference. Do not claim the file was sent."
        ),
        ConferenceSiriEvalCase(
            id: "export-to-someone",
            skillName: "export-notes",
            kind: .negative,
            utterance: "Export my notes to Jordan",
            mustNotCall: ["ExportNotesTool"],
            responseContains: "this device",
            parameterNote: "Do not deliver the file. The export-notes skill says the notes remain on this device and a share sheet is a separate step."
        ),
        ConferenceSiriEvalCase(
            id: "export-offline",
            skillName: "export-notes",
            kind: .offlineFallback,
            utterance: "Export my notes",
            mustNotCall: ["ExportNotesTool"],
            responseContains: "in the app",
            parameterNote: "Open My Notes from Info in the app.",
            includeInDeviceScenario: false
        ),

        // find-attendee
        ConferenceSiriEvalCase(
            id: "attendee-list",
            skillName: "find-attendee",
            kind: .toolSelection,
            utterance: "Who is attending?",
            toolName: "FindAttendeeTool",
            responseContains: "Maya Chen",
            parameterNote: "Name is empty, so the tool lists the directory. The sample lists Maya Chen. Names and roles only."
        ),
        ConferenceSiriEvalCase(
            id: "attendee-paraphrase",
            skillName: "find-attendee",
            kind: .paraphrase,
            utterance: "Who's around in the directory?",
            toolName: "FindAttendeeTool",
            responseContains: "Maya Chen",
            parameterNote: "Name is empty. Directory list, names and roles only."
        ),
        ConferenceSiriEvalCase(
            id: "attendee-missing",
            skillName: "find-attendee",
            kind: .negative,
            utterance: "Is Okonkwo in the directory?",
            toolName: "FindAttendeeTool",
            responseContains: "directory",
            parameterNote: "Name is Okonkwo. Sam Okonkwo is not discoverable. The spoken line is I don’t see Okonkwo in the attendee directory."
        ),
        ConferenceSiriEvalCase(
            id: "attendee-email",
            skillName: "find-attendee",
            kind: .authConfirmation,
            utterance: "What's Maya's email address?",
            toolName: "ReadPublicAttendeeContactIntent",
            mustNotCall: ["FindAttendeeTool"],
            responseContains: "public contact",
            parameterNote: "Target is Maya Chen. This is ReadPublicAttendeeContactIntent, whose authenticationPolicy is requiresLocalDeviceAuthentication. The confirmation dialog is Show the public contact fields for Maya Chen? FindAttendeeTool does not return the email. After a yes, the spoken fields include maya@example.com."
        ),
        ConferenceSiriEvalCase(
            id: "attendee-message",
            skillName: "find-attendee",
            kind: .negative,
            utterance: "Text Jordan that I'll be late",
            mustNotCall: ["FindAttendeeTool"],
            responseContains: "this device",
            parameterNote: "No send tool. The find-attendee skill says to open Messages in the app, and that those messages stay on this device."
        ),
        ConferenceSiriEvalCase(
            id: "attendee-offline",
            skillName: "find-attendee",
            kind: .offlineFallback,
            utterance: "Who is attending?",
            mustNotCall: ["FindAttendeeTool"],
            responseContains: "in the app",
            parameterNote: "Open the Attendees screen. Do not claim a server was reached.",
            includeInDeviceScenario: false
        )
    ]

    public static func cases(for skillName: String) -> [ConferenceSiriEvalCase] {
        cases.filter { $0.skillName == skillName }
    }

    public static var deviceCases: [ConferenceSiriEvalCase] {
        cases.filter { $0.includeInDeviceScenario }
    }
}
