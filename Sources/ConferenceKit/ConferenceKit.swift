import Foundation

/// ConferenceKit turns a single JSON manifest into a conference app
/// for iPhone, iPad, Mac, Apple Watch, tvOS, visionOS, and iPhone Duo.
///
/// Drop `ConferenceAppView` into your app target, point it at bundled or
/// remote JSON, and the kit owns schedule, speakers, theme, and layouts.
public enum ConferenceKit {
    /// Documents may omit every 1.1 field. 1.0 manifests still decode.
    public static let schemaVersion = "1.2"
    public static let minimumSchemaVersion = "1.0"
}
