import AppIntents
import ConferenceKit
import Foundation

#if os(iOS) || os(macOS) || os(visionOS)
/// Apple Intelligence search schema.
///
/// Signature follows the `system.search` example: `searchScopes`,
/// `criteria` of type `StringSearchCriteria`, and `ShowInAppSearchResultsIntent`.
/// `criteria.term` is the term used by the published schema sample and is
/// flagged in the pull request because the property name is not in the
/// tech-talk transcript.
@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
@AppIntent(schema: .system.search)
public struct ConferenceInAppSearchIntent: ShowInAppSearchResultsIntent {
    public static var title: LocalizedStringResource = "Search Conference"
    public static var searchScopes: [StringSearchScope] = [.general]

    public var criteria: StringSearchCriteria

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let term = criteria.term
        ConferenceNavigation.shared.search(term)
        return .result()
    }
}
#endif
