#if SIRI_AI_PREVIEW && os(iOS)
import ActivityKit
import ConferenceKit
import SwiftUI

/// Foreground context plus a Live Activity so “add a note: …” can land on the
/// session on screen without the person naming the app. Preview only.
struct ConferenceSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var room: String
    }

    var sessionID: String
    var conferenceName: String
}

extension View {
    @ViewBuilder
    func siriSessionContext(sessionID: String, title: String, room: String) -> some View {
        if #available(iOS 27.3, *) {
            self.userActivity(ConferenceActivity.session) { activity in
                activity.title = title
                activity.userInfo = ["sessionID": sessionID]
            }
            .task(id: sessionID) {
                await ConferenceLiveSession.sync(sessionID: sessionID, title: title, room: room)
            }
        } else {
            self
        }
    }
}

@available(iOS 27.3, *)
enum ConferenceLiveSession {
    // Off the main actor: Activity isn't Sendable in the 27.3 SDK, and update/end are
    // @concurrent, so a main-actor-isolated Activity can't be handed to them.
    @concurrent
    static func sync(sessionID: String, title: String, room: String) async {
        let state = ConferenceSessionAttributes.ContentState(title: title, room: room)
        let existing = Activity<ConferenceSessionAttributes>.activities.first { $0.attributes.sessionID == sessionID }
        if let existing {
            await existing.update(ActivityContent(state: state, staleDate: nil))
            return
        }
        for activity in Activity<ConferenceSessionAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let attributes = ConferenceSessionAttributes(sessionID: sessionID, conferenceName: title)
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }
}
#endif
