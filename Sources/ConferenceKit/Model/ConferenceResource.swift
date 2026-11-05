import Foundation

public enum ConferenceResourceKind: String, Codable, Hashable, Sendable, CaseIterable {
    case pdf
    case doc
    case link

    public var label: String {
        switch self {
        case .pdf: "PDF"
        case .doc: "Document"
        case .link: "Link"
        }
    }

    public var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .doc: "doc"
        case .link: "url"
        }
    }

    public var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .doc: "doc.text"
        case .link: "link"
        }
    }
}

/// A downloadable document or an external link. Stored on the manifest, same as sessions.
public struct ConferenceResource: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var kind: ConferenceResourceKind
    public var remoteURL: URL
    public var localFilename: String?
    public var fileSizeBytes: Int64?
    /// Free-form grouping key such as `slides`, `map`, or `sponsor`.
    public var category: String

    public init(
        id: String,
        title: String,
        kind: ConferenceResourceKind,
        remoteURL: URL,
        localFilename: String? = nil,
        fileSizeBytes: Int64? = nil,
        category: String
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.remoteURL = remoteURL
        self.localFilename = localFilename
        self.fileSizeBytes = fileSizeBytes
        self.category = category
    }

    public var fileSizeLabel: String? {
        fileSizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
    }
}

public struct ResourceGroup: Hashable, Sendable, Identifiable {
    public var category: String
    public var resources: [ConferenceResource]

    public var id: String { category }

    public var label: String {
        ResourceTransfer.categoryLabel(category)
    }
}

public enum ResourceDownloadPhase: String, Codable, Hashable, Sendable {
    case idle
    case downloading
    case downloaded
    case failed
}

public struct ResourceDownloadRecord: Codable, Hashable, Sendable {
    public var resourceID: String
    public var phase: ResourceDownloadPhase
    public var progress: Double
    public var localFilename: String?
    public var message: String?

    public init(
        resourceID: String,
        phase: ResourceDownloadPhase,
        progress: Double,
        localFilename: String? = nil,
        message: String? = nil
    ) {
        self.resourceID = resourceID
        self.phase = phase
        self.progress = progress
        self.localFilename = localFilename
        self.message = message
    }
}

public enum ResourceDownloadEvent: Hashable, Sendable {
    case start
    case progress(Double)
    case succeed(filename: String)
    case fail(String)
}

public enum ResourceOpenAction: Hashable, Sendable {
    case browser(URL)
    case preview(URL)
    case download
    case downloading(Double)
    case failed(String)
}

public enum ResourceTransfer {
    public static func initial(id: String) -> ResourceDownloadRecord {
        ResourceDownloadRecord(resourceID: id, phase: .idle, progress: 0)
    }

    public static func clampedProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    public static func reduce(_ record: ResourceDownloadRecord, _ event: ResourceDownloadEvent) -> ResourceDownloadRecord {
        var copy = record
        switch event {
        case .start:
            copy.phase = .downloading
            copy.progress = 0
            copy.localFilename = nil
            copy.message = nil
        case .progress(let value):
            guard copy.phase == .downloading else { return record }
            copy.progress = clampedProgress(value)
        case .succeed(let filename):
            copy.phase = .downloaded
            copy.progress = 1
            copy.localFilename = filename
            copy.message = nil
        case .fail(let message):
            copy.phase = .failed
            copy.message = message
        }
        return copy
    }

    /// Last path component only, so a manifest cannot write outside the resources directory.
    public static func storedFilename(for resource: ConferenceResource) -> String {
        let fallback = "\(resource.id).\(resource.kind.fileExtension)"
        let raw = resource.localFilename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = URL(fileURLWithPath: raw).lastPathComponent
        if raw.isEmpty || base.isEmpty || base == "." || base == ".." || base == "/" {
            return fallback
        }
        return base
    }

    public static func categoryLabel(_ category: String) -> String {
        switch category.lowercased() {
        case "slides": return "Slides"
        case "map": return "Map"
        case "sponsor": return "Sponsor"
        default:
            guard let first = category.first else { return "Other" }
            return first.uppercased() + category.dropFirst()
        }
    }

    /// Categories are alphabetical. Resources inside a category are alphabetical by title.
    public static func grouped(_ resources: [ConferenceResource]) -> [ResourceGroup] {
        let groups = Dictionary(grouping: resources) { $0.category.lowercased() }
        return groups.keys.sorted().map { key in
            let items = (groups[key] ?? []).sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return ResourceGroup(category: key, resources: items)
        }
    }

    public static func action(
        for resource: ConferenceResource,
        record: ResourceDownloadRecord,
        directory: URL
    ) -> ResourceOpenAction {
        if resource.kind == .link {
            return .browser(resource.remoteURL)
        }
        switch record.phase {
        case .downloading:
            return .downloading(record.progress)
        case .downloaded:
            let name = record.localFilename ?? storedFilename(for: resource)
            return .preview(directory.appendingPathComponent(name))
        case .failed:
            return .failed(record.message ?? "Download failed.")
        case .idle:
            return .download
        }
    }
}
