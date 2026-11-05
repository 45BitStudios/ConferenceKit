import ConferenceKit
import Foundation
import Testing

@Test func newsFeedPinsThenSortsNewestFirst() {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    func item(_ id: String, hours: TimeInterval, pinned: Bool) -> ConferenceNewsItem {
        ConferenceNewsItem(
            id: id,
            title: id,
            body: "Body",
            publishedAt: base.addingTimeInterval(hours * 3600),
            isPinned: pinned
        )
    }
    let sorted = NewsFeed.sorted([
        item("newer", hours: 3, pinned: false),
        item("old-pin", hours: 1, pinned: true),
        item("middle", hours: 2, pinned: false),
        item("new-pin", hours: 4, pinned: true)
    ])
    #expect(sorted.map(\.id) == ["new-pin", "old-pin", "newer", "middle"])
    #expect(NewsFeed.sorted(SGConfSeed.news).map(\.id) == ["sg-doors", "sg-slides", "sg-workshops"])
}

@Test func sampleManifestCarriesSGConfSeed() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    #expect(manifest.news == SGConfSeed.news)
    #expect(manifest.resources == SGConfSeed.resources)
    #expect(manifest.pass == SGConfSeed.pass)
    let encoded = try ConferenceLoader.makeEncoder().encode(manifest)
    let again = try ConferenceLoader().decode(data: encoded)
    #expect(again.news == manifest.news)
    #expect(again.resources == manifest.resources)
    #expect(again.pass == manifest.pass)
}

@Test func announcementPlannerSkipsSilentAndAlreadySent() throws {
    let long = String(repeating: "a", count: 200)
    let items = [
        ConferenceNewsItem(id: "silent", title: "Quiet", body: "No alert", publishedAt: .now, announces: false),
        ConferenceNewsItem(id: "loud", title: "Doors", body: long, publishedAt: .now, isPinned: true, announces: true),
        ConferenceNewsItem(id: "sent", title: "Old", body: "Already sent", publishedAt: .now, announces: true)
    ]
    let pending = AnnouncementPlanner.notices(
        items: items,
        conferenceID: "sg",
        alreadyScheduled: ["sent"],
        enabled: true
    )
    let notice = try #require(pending.first)
    #expect(pending.map(\.newsID) == ["loud"])
    #expect(notice.identifier == "conferencekit.news.sg.loud")
    #expect(notice.body.count == 181)
    #expect(notice.body.hasSuffix("…"))
    #expect(AnnouncementPlanner.notices(items: items, conferenceID: "sg", alreadyScheduled: [], enabled: false).isEmpty)
}

@Test func announcementLedgerRoundTrips() {
    let defaults = UserDefaults(suiteName: "conferencekit-news-\(UUID().uuidString)")!
    #expect(AnnouncementLedger.isEnabled(defaults))
    AnnouncementLedger.setEnabled(false, defaults: defaults)
    #expect(AnnouncementLedger.isEnabled(defaults) == false)
    AnnouncementLedger.save(["sg-doors", "sg-slides"], conferenceID: "sg", defaults: defaults)
    #expect(AnnouncementLedger.scheduledIDs(conferenceID: "sg", defaults: defaults) == ["sg-doors", "sg-slides"])
    #expect(AnnouncementLedger.scheduledIDs(conferenceID: "other", defaults: defaults).isEmpty)
}

@Test func resourcesGroupByCategoryAndChooseAnAction() throws {
    let groups = ResourceTransfer.grouped(SGConfSeed.resources)
    #expect(groups.map(\.category) == ["map", "slides", "sponsor"])
    #expect(groups.map(\.label) == ["Map", "Slides", "Sponsor"])
    let link = try #require(SGConfSeed.resources.first { $0.kind == .link })
    let slides = try #require(SGConfSeed.resources.first { $0.id == "sg-opening-slides" })
    let directory = URL(fileURLWithPath: "/tmp/conferencekit-resources", isDirectory: true)
    #expect(ResourceTransfer.action(for: link, record: ResourceTransfer.initial(id: link.id), directory: directory) == .browser(link.remoteURL))
    let idle = ResourceTransfer.action(for: slides, record: ResourceTransfer.initial(id: slides.id), directory: directory)
    #expect(idle == .download)
    var record = ResourceTransfer.reduce(ResourceTransfer.initial(id: slides.id), .start)
    #expect(record.phase == .downloading)
    #expect(record.progress == 0)
    record = ResourceTransfer.reduce(record, .progress(1.4))
    #expect(record.progress == 1)
    record = ResourceTransfer.reduce(record, .progress(.nan))
    #expect(record.progress == 0)
    record = ResourceTransfer.reduce(record, .succeed(filename: "opening-keynote.pdf"))
    #expect(record.phase == .downloaded)
    #expect(record.progress == 1)
    if case .preview(let url) = ResourceTransfer.action(for: slides, record: record, directory: directory) {
        #expect(url.lastPathComponent == "opening-keynote.pdf")
    } else {
        Issue.record("Expected a preview URL")
    }
    let failed = ResourceTransfer.reduce(record, .fail("offline"))
    #expect(failed.phase == .failed)
    #expect(failed.message == "offline")
    let restarted = ResourceTransfer.reduce(failed, .start)
    #expect(restarted.localFilename == nil)
    #expect(restarted.phase == .downloading)
    let hostile = ConferenceResource(
        id: "slides",
        title: "Slides",
        kind: .pdf,
        remoteURL: URL(string: "https://example.com/slides.pdf")!,
        localFilename: "../secret.pdf",
        category: "slides"
    )
    #expect(ResourceTransfer.storedFilename(for: hostile) == "secret.pdf")
    let unnamed = ConferenceResource(
        id: "notes",
        title: "Notes",
        kind: .doc,
        remoteURL: URL(string: "https://example.com/notes.doc")!,
        category: "slides"
    )
    #expect(ResourceTransfer.storedFilename(for: unnamed) == "notes.doc")
}

@Test @MainActor func resourceLibraryTreatsAnExistingFileAsDownloaded() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let resource = try #require(SGConfSeed.resources.first { $0.kind == .pdf })
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let filename = ResourceTransfer.storedFilename(for: resource)
    try Data("%PDF".utf8).write(to: directory.appendingPathComponent(filename))
    let library = ResourceLibrary(directory: directory, resources: SGConfSeed.resources)
    #expect(library.record(for: resource).phase == .downloaded)
    #expect(library.fileURL(for: resource)?.lastPathComponent == filename)
    let link = try #require(SGConfSeed.resources.first { $0.kind == .link })
    #expect(library.record(for: link).phase == .idle)
}

@Test func passBuilderWritesManifestAndUnsignedArchive() throws {
    #expect(PassArchiveChecksum.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    #expect(PassBuilder.sha1Hex(Data()) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    let pass = SGConfSeed.pass
    let package = try PassBuilder.build(pass: pass)
    let again = try PassBuilder.build(pass: pass)
    #expect(package.passJSON == again.passJSON)
    #expect(package.manifestJSON == again.manifestJSON)
    #expect(package.archive == again.archive)
    #expect(package.isSigned == false)
    #expect(package.archive.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
    #expect(package.archive.range(of: Data("pass.json".utf8)) != nil)
    #expect(package.archive.range(of: Data("manifest.json".utf8)) != nil)
    let json = try #require(JSONSerialization.jsonObject(with: package.passJSON) as? [String: Any])
    #expect(json["formatVersion"] as? Int == 1)
    #expect(json["passTypeIdentifier"] as? String == PassBuilder.placeholderPassTypeIdentifier)
    #expect(json["teamIdentifier"] as? String == PassBuilder.placeholderTeamIdentifier)
    #expect(json["organizationName"] as? String == "45BitStudios")
    #expect(json["relevantDate"] as? String == ConferenceLoader.formatISO8601(pass.relevantDate))
    let ticket = try #require(json["eventTicket"] as? [String: Any])
    let primary = try #require((ticket["primaryFields"] as? [[String: Any]])?.first)
    #expect(primary["value"] as? String == pass.attendeeName)
    let barcode = try #require(json["barcode"] as? [String: Any])
    #expect(barcode["message"] as? String == pass.barcodePayload)
    #expect(barcode["format"] as? String == "PKBarcodeFormatQR")
    let manifest = try #require(JSONSerialization.jsonObject(with: package.manifestJSON) as? [String: Any])
    #expect(manifest["pass.json"] as? String == PassBuilder.sha1Hex(package.passJSON))
    #expect(manifest["manifest.json"] == nil)
    #expect(manifest["signature"] == nil)
    #expect(PassBuilder.signingRequirement.contains("Pass Type ID"))
    #expect(PassBuilder.signingRequirement.contains("certificate"))
    let signed = try PassBuilder.build(pass: pass, signature: Data("not-a-real-signature".utf8))
    #expect(signed.isSigned)
    #expect(signed.archive.range(of: Data("signature".utf8)) != nil)
    #expect(signed.archive != package.archive)
}
