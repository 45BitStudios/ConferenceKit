import ConferenceKit
import ConferenceKitIntents
import Foundation
import Testing
#if canImport(CoreSpotlight) && !os(tvOS)
import CoreSpotlight
#endif

@Test func customSiriToolsNeedPrivateCloudCompute() {
    #expect(ConferenceAssistantAvailability.canRun(.appIntent, privateCloudComputeReachable: false))
    #expect(ConferenceAssistantAvailability.canRun(.onDeviceAsk, privateCloudComputeReachable: false))
    #expect(ConferenceAssistantAvailability.canRun(.siriCustomTool, privateCloudComputeReachable: false) == false)
    #expect(ConferenceAssistantAvailability.canRun(.siriCustomTool, privateCloudComputeReachable: true))
    #expect(ConferenceAssistantAvailability.resolved(.siriCustomTool, privateCloudComputeReachable: false) == .appIntent)
    #expect(ConferenceAssistantAvailability.resolved(.onDeviceAsk, privateCloudComputeReachable: false) == .onDeviceAsk)
    #expect(SiriCustomToolCatalog.names.count <= SiriCustomToolCatalog.previewCap)
    #expect(Set(SiriCustomToolCatalog.names).count == SiriCustomToolCatalog.names.count)
    #expect(SiriCustomToolCatalog.names.contains("FindAttendeeTool"))
}

@Test func directoryAnswersAndSnippetsOmitContactFields() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let maya = try #require(manifest.attendee(id: "maya-chen"))
    let sam = try #require(manifest.attendee(id: "sam-okonkwo"))
    let listed = AttendeeDirectoryAnswers.reply(query: "Maya", manifest: manifest)
    #expect(listed.ids == ["maya-chen"])
    #expect(listed.spoken.contains("Maya Chen"))
    #expect(!listed.spoken.contains("@"))
    #expect(!listed.spoken.contains("maya@example.com"))
    let missing = AttendeeDirectoryAnswers.reply(query: "Okonkwo", manifest: manifest)
    #expect(missing.ids.isEmpty)
    #expect(missing.spoken.contains("directory"))
    #expect(!missing.spoken.contains("Lumen"))
    #expect(!missing.spoken.contains("Asked not to be listed"))
    #expect(AttendeeSnippetCopy.title(for: maya) == "Maya Chen")
    #expect(!AttendeeSnippetCopy.detail(for: maya).contains("@"))
    #expect(AttendeeSnippetCopy.title(for: sam) == "Attendee")
    #expect(AttendeeSnippetCopy.detail(for: sam).isEmpty)
    let contact = AttendeeContactDisclosure.make(attendeeID: "maya-chen", in: manifest)
    #expect(contact?.email == "maya@example.com")
    #expect(contact?.phone == nil)
    #expect(AttendeeContactDisclosure.make(attendeeID: "sam-okonkwo", in: manifest) == nil)
}

@Test @MainActor func searchAttendeesPerformAndContactAuthStaySeparate() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    try await CatalogGate.shared.run {
        await ConferenceCatalog.shared.update(manifest: manifest, favoriteSessionIDs: [], favoriteSpeakerIDs: [])
        await ConferenceCatalog.shared.updateCurrentAttendee(nil)
        _ = try await SearchAttendeesIntent(query: "Okonkwo").perform()
        await ConferenceCatalog.shared.reset()
    }
    #expect(SearchAttendeesIntent.authenticationPolicy == .alwaysAllowed)
    #expect(OpenAttendeeIntent.authenticationPolicy == .alwaysAllowed)
    #expect(ReadPublicAttendeeContactIntent.authenticationPolicy == .requiresLocalDeviceAuthentication)
}

@Test @MainActor func profileEditRevalidatesPublicContactAndConsent() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let seed = Attendee(
        id: "me",
        displayName: "Me",
        email: "me@example.com",
        phone: "555-0100",
        privacy: AttendeePrivacy(discoverable: true, showsEmail: true, showsPhone: true),
        messagingConsent: true,
        isCurrentUser: true
    )
    let profiles = AttendeeProfileStore(conferenceID: "c", directory: directory, seed: seed)
    profiles.edit { person in
        person.privacy.showsEmail = false
        person.privacy.showsPhone = false
        person.messagingConsent = false
    }
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "c", name: "C", timezone: "UTC", startDate: "2026-04-16", endDate: "2026-04-16"),
        attendees: [profiles.profile]
    )
    let visible = try #require(manifest.directoryAttendees().first)
    #expect(visible.email == nil)
    #expect(visible.phone == nil)
    let card = VCard.make(from: profiles.profile)
    #expect(!card.contains("EMAIL"))
    #expect(!card.contains("TEL"))
    #expect(!card.contains("me@example.com"))
    let contact = AttendeeContactDisclosure.make(attendeeID: "me", in: manifest)
    #expect(contact?.email == nil)
    #expect(contact?.phone == nil)
    let transport = LocalDemoMessageTransport(directory: directory)
    let context = AttendeeMessagingContext(
        sender: AttendeeVisibility(profiles.profile),
        recipient: AttendeeVisibility(id: "maya", discoverable: true, messagingConsent: true)
    )
    await #expect(throws: AttendeeMessagingError.notPermitted(.senderDeclined)) {
        try await transport.send(
            OutgoingAttendeeMessage(senderID: "me", recipientID: "maya", body: "Hi"),
            context: context,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

#if canImport(CoreSpotlight) && !os(tvOS)
@Test func attendeeSpotlightOmitsContactFields() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let maya = try #require(manifest.directoryAttendees().first { $0.id == "maya-chen" })
    let entity = AttendeeEntity(maya)
    if #available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *) {
        let attributes = entity.attributeSet
        let blob = [attributes.title, attributes.contentDescription, attributes.comment]
            .compactMap { $0 }
            .joined(separator: "\n")
        #expect(blob.contains("Maya Chen"))
        #expect(!blob.contains("maya@example.com"))
        #expect(!blob.contains("@"))
    }
}
#endif
