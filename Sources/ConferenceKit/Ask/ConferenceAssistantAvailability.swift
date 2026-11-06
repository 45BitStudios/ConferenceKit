import Foundation

/// How a conference question is answered. These are different runtimes.
///
/// Custom Siri tools (`@AppIntent(.tool)`) are the path the group lab described
/// as Siri-on-the-server: Private Cloud Compute. Ordinary App Intents and the
/// on-device Ask rules do not use that path and do not require it.
public enum ConferenceAssistantChannel: String, Codable, Hashable, Sendable, CaseIterable {
    /// Shortcuts and App Intents that run in the app or extension. On device.
    case appIntent
    /// `ConferenceAskAnswers`, and the on-device Foundation Models session when AskKit is linked.
    case onDeviceAsk
    /// Custom ToolIntents. Unavailable when Siri cannot reach Private Cloud Compute.
    case siriCustomTool
}

public enum ConferenceAssistantAvailability {
    /// `privateCloudComputeReachable` is an input from the caller. This package does not
    /// probe Apple's server. A custom tool is runnable only when that input is true.
    public static func canRun(
        _ channel: ConferenceAssistantChannel,
        privateCloudComputeReachable: Bool
    ) -> Bool {
        switch channel {
        case .appIntent, .onDeviceAsk:
            return true
        case .siriCustomTool:
            return privateCloudComputeReachable
        }
    }

    /// Offline, a request for a custom Siri tool falls back to the on-device App Intent path.
    public static func resolved(
        _ channel: ConferenceAssistantChannel,
        privateCloudComputeReachable: Bool
    ) -> ConferenceAssistantChannel {
        if channel == .siriCustomTool, !privateCloudComputeReachable {
            return .appIntent
        }
        return channel
    }
}

/// Names of the custom ToolIntents compiled only with `SIRI_AI_PREVIEW`.
/// The preview cap of 40 is lab guidance for that developer preview, not an App Store limit
/// this package can enforce. Schema intents such as in-app search are not in this list.
public enum SiriCustomToolCatalog {
    public static let previewCap = 40

    public static let names = [
        "WhatsNextTool",
        "FindSessionTool",
        "FavoriteSessionTool",
        "AddNoteTool",
        "ShowNotesTool",
        "ExportNotesTool",
        "CreateSessionNoteIntent",
        "FindAttendeeTool"
    ]
}
