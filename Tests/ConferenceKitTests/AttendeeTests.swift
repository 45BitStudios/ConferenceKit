import ConferenceKit
import ConferenceKitIntents
import Foundation
import Testing
#if canImport(Contacts) && !os(tvOS)
import Contacts
#endif

@Test func privacyDefaultsHideContactFields() throws {
    let json = """
    {"id":"a","displayName":"A","email":"secret@example.com","phone":"555-0100","social":[{"platform":"website","url":"https://example.com/a"}]}
    """.data(using: .utf8)!
    let attendee = try JSONDecoder().decode(Attendee.self, from: json)
    #expect(attendee.privacy.discoverable == false)
    #expect(attendee.privacy.showsEmail == false)
    #expect(attendee.privacy.showsPhone == false)
    #expect(attendee.privacy.showsSocial == false)
    #expect(attendee.messagingConsent == false)
    let visible = attendee.hidingPrivateContactFields()
    #expect(visible.email == nil)
    #expect(visible.phone == nil)
    #expect(visible.social.isEmpty)
    let manifest = ConferenceManifest(
        conference: ConferenceInfo(id: "c", name: "C", timezone: "UTC", startDate: "2026-04-16", endDate: "2026-04-16"),
        attendees: [attendee]
    )
    #expect(manifest.directoryAttendees().isEmpty)
    let listed = attendee
    var visiblePerson = listed
    visiblePerson.privacy.discoverable = true
    let directory = ConferenceManifest(
        conference: manifest.conference,
        attendees: [visiblePerson]
    )
    #expect(ConferenceSearch.attendees(in: directory, matching: AttendeeFilter(query: "secret@example.com")).isEmpty)
    #expect(ConferenceSearch.attendees(in: directory, matching: AttendeeFilter(query: "555-0100")).isEmpty)
    #expect(ConferenceSearch.attendees(in: directory, matching: AttendeeFilter(query: "A")).map(\.id) == ["a"])
}

@Test func sampleDirectoryOmitsPrivateAndHiddenPeople() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let listed = manifest.directoryAttendees()
    #expect(listed.map(\.id).sorted() == ["alex-rivera", "jordan-hale", "maya-chen"])
    let maya = try #require(listed.first { $0.id == "maya-chen" })
    #expect(maya.email == "maya@example.com")
    #expect(maya.phone == nil)
    #expect(maya.social.map(\.platform) == [.github])
    #expect(maya.phone == nil)
    let jordan = try #require(listed.first { $0.id == "jordan-hale" })
    #expect(jordan.email == nil)
    #expect(jordan.phone == nil)
    #expect(jordan.social.isEmpty)
    // "Sam" matches Jordan's public company "Sample Conf". Sam Okonkwo is not in that result.
    let samHits = ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: "Sam"))
    #expect(!samHits.contains { $0.id == "sam-okonkwo" })
    #expect(samHits.allSatisfy { $0.privacy.discoverable })
    #expect(ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: "Okonkwo")).isEmpty)
    #expect(ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: "Lumen")).isEmpty)
    #expect(ConferenceSearch.attendees(in: manifest, matching: AttendeeFilter(query: "Maya", ticketKind: "full")).map(\.id) == ["maya-chen"])
    let spoken = ConferenceAskAnswers.findAttendee(named: "Maya", catalog: ConferenceAskCatalog(manifest: manifest))
    #expect(spoken.contains("maya@example.com"))
    #expect(!spoken.contains("555"))
    let publicSam = ConferenceAskAnswers.findAttendee(named: "Sam", catalog: ConferenceAskCatalog(manifest: manifest))
    #expect(!publicSam.contains("Okonkwo"))
    #expect(!publicSam.contains("Asked not to be listed"))
    #expect(!publicSam.contains("Lumen"))
    let missing = ConferenceAskAnswers.findAttendee(named: "Okonkwo", catalog: ConferenceAskCatalog(manifest: manifest))
    #expect(missing.contains("Okonkwo"))
    #expect(missing.contains("directory"))
    #expect(!missing.contains("Asked not to be listed"))
    #expect(!missing.contains("Lumen"))
    #expect(!missing.contains("sam.secret"))
}

@Test func vCardEscapesAndKeepsOnlyPublicFields() throws {
    let person = Attendee(
        id: "doe",
        displayName: "Doe, Jane",
        role: "A; B",
        company: "North, Wind",
        bio: "Line 1\nLine 2 \\ end " + String(repeating: "x", count: 120),
        email: "jane@example.com",
        phone: "+1 (312) 555-0100",
        social: [SocialLink(platform: .website, url: URL(string: "https://example.com/jane")!)],
        privacy: AttendeePrivacy(discoverable: true, showsEmail: true, showsPhone: false, showsSocial: true),
        messagingConsent: false
    )
    let card = VCard.make(from: person)
    #expect(card.contains("VERSION:3.0"))
    #expect(card.contains("\r\n"))
    #expect(card.contains("FN:Doe\\, Jane"))
    #expect(card.contains("TITLE:A\\; B"))
    #expect(card.contains("ORG:North\\, Wind"))
    #expect(card.contains("EMAIL;TYPE=INTERNET:jane@example.com"))
    #expect(card.contains("NOTE:Line 1\\nLine 2 \\\\ end"))
    #expect(!card.contains("TEL"))
    #expect(!card.contains("555-0100"))
    let parsed = try #require(VCard.parse(card).first)
    #expect(parsed.fullName == "Doe, Jane")
    #expect(parsed.title == "A; B")
    #expect(parsed.organization == "North, Wind")
    #expect(parsed.note?.hasPrefix("Line 1\nLine 2 \\ end") == true)
    #expect(parsed.emails == ["jane@example.com"])
    #expect(parsed.phones.isEmpty)
    #expect(parsed.urls.map(\.absoluteString) == ["https://example.com/jane"])

    let unlisted = Attendee(id: "hidden", displayName: "Hidden", email: "h@example.com", privacy: AttendeePrivacy())
    #expect(AttendeeShare.card(for: unlisted, allowsUnlisted: false) == nil)
    let ownCard = try #require(AttendeeShare.card(for: unlisted, allowsUnlisted: true))
    #expect(!ownCard.vCard.contains("EMAIL"))
    #expect(ownCard.qrPayload == ownCard.vCard)
}

@Test func vCardParserUnfoldsAndReadsSeveralCards() {
    let text = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Doe\\, Jane\r\nNOTE:Hello \r\n folded\r\nEND:VCARD\r\nBEGIN:VCARD\r\nFN:Other\r\nTEL:555\r\nEND:VCARD\r\n"
    let cards = VCard.parse(text)
    #expect(cards.map(\.fullName) == ["Doe, Jane", "Other"])
    #expect(cards[0].note == "Hello folded")
    #expect(cards[1].phones == ["555"])
}

@Test func attendeeQueriesMapPublicDirectoryOnly() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    await ConferenceCatalog.shared.update(manifest: manifest, favoriteSessionIDs: [], favoriteSpeakerIDs: [])
    await ConferenceCatalog.shared.updateCurrentAttendee(nil)
    let query = AttendeeEntityQuery()
    let byID = try await query.entities(for: ["maya-chen", "sam-okonkwo"])
    #expect(byID.map(\.id) == ["maya-chen"])
    #expect(byID.first?.email == "maya@example.com")
    #expect(byID.first?.phone == nil)
    let jordan = try await query.entities(matching: "Jordan")
    #expect(jordan.map(\.id) == ["jordan-hale"])
    #expect(jordan.first?.email == nil)
    #expect(jordan.first?.phone == nil)
    #expect(try await query.entities(matching: "sam.secret").isEmpty)
    let suggested = try await query.suggestedEntities()
    #expect(suggested.map(\.id).sorted() == ["alex-rivera", "jordan-hale", "maya-chen"])
    let info = manifest.conference
    #expect(ConferenceLink.parse(ConferenceLink.attendee("maya-chen").url(conference: info)) == .attendee("maya-chen"))
    await ConferenceCatalog.shared.reset()
}

@Test @MainActor func appShortcutsStayWithinTheCap() {
    #expect(ConferenceShortcutTemplate.shortcuts.count == 10)
}

@Test func messagingPolicyBlocksPrivateAndUnwillingPeople() {
    let open = AttendeeVisibility(id: "me", discoverable: true, messagingConsent: true)
    let friend = AttendeeVisibility(id: "you", discoverable: true, messagingConsent: true)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: open, recipient: friend)) == nil)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: open, recipient: open)) == .selfMessage)
    let hidden = AttendeeVisibility(id: "you", discoverable: false, messagingConsent: true)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: open, recipient: hidden)) == .recipientNotDiscoverable)
    let quiet = AttendeeVisibility(id: "you", discoverable: true, messagingConsent: false)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: open, recipient: quiet)) == .recipientDeclined)
    let shy = AttendeeVisibility(id: "me", discoverable: true, messagingConsent: false)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: shy, recipient: friend)) == .senderDeclined)
    let unlisted = AttendeeVisibility(id: "me", discoverable: false, messagingConsent: true)
    #expect(AttendeeMessagingPolicy.denial(context: AttendeeMessagingContext(sender: unlisted, recipient: friend)) == .senderNotDiscoverable)
    #expect(
        AttendeeMessagingPolicy.denial(
            context: AttendeeMessagingContext(sender: open, recipient: friend),
            storedBlockedIDs: ["you"]
        ) == .blocked
    )
}

@Test func demoTransportSendReceiveAndBlockStayOnDevice() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let transport = LocalDemoMessageTransport(directory: directory)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let alex = AttendeeVisibility(id: "alex-rivera", discoverable: true, messagingConsent: true)
    let maya = AttendeeVisibility(id: "maya-chen", discoverable: true, messagingConsent: true)
    let jordan = AttendeeVisibility(id: "jordan-hale", discoverable: true, messagingConsent: false)
    let allowed = AttendeeMessagingContext(sender: alex, recipient: maya)
    let result = try await transport.send(
        OutgoingAttendeeMessage(senderID: alex.id, recipientID: maya.id, body: " Hello "),
        context: allowed,
        now: now
    )
    #expect(result.deliveryStates == [.queued, .demoOnDevice])
    #expect(result.message.delivery == .demoOnDevice)
    #expect(result.message.body == "Hello")
    #expect(result.message.senderID == alex.id)
    let notice = try #require(result.snapshot.messages.first { $0.isDemoNotice })
    #expect(notice.senderID == AttendeeMessaging.demoTransportID)
    #expect(notice.body == AttendeeMessaging.demoNotice)
    #expect(!result.snapshot.messages.contains { $0.senderID == maya.id })
    #expect(result.snapshot.unreadCount(in: result.snapshot.conversations[0], localUserID: alex.id) == 0)

    let before = await transport.load()
    await #expect(throws: AttendeeMessagingError.notPermitted(.recipientDeclined)) {
        try await transport.send(
            OutgoingAttendeeMessage(senderID: alex.id, recipientID: jordan.id, body: "Nope"),
            context: AttendeeMessagingContext(sender: alex, recipient: jordan),
            now: now
        )
    }
    let afterDenial = await transport.load()
    #expect(afterDenial.messages.map(\.id) == before.messages.map(\.id))

    await #expect(throws: AttendeeMessagingError.emptyBody) {
        try await transport.send(
            OutgoingAttendeeMessage(senderID: alex.id, recipientID: maya.id, body: "   "),
            context: allowed,
            now: now
        )
    }

    let blocked = await transport.setBlocked(attendeeID: maya.id, blocked: true)
    #expect(blocked.blockedIDs == [maya.id])
    await #expect(throws: AttendeeMessagingError.notPermitted(.blocked)) {
        try await transport.send(
            OutgoingAttendeeMessage(senderID: alex.id, recipientID: maya.id, body: "Again"),
            context: allowed,
            now: now
        )
    }
    _ = await transport.setBlocked(attendeeID: maya.id, blocked: false)

    let receivedAt = now.addingTimeInterval(60)
    let received = await transport.receiveDemo(
        IncomingDemoMessage(senderID: maya.id, recipientID: alex.id, body: "Sample on this device", sentAt: receivedAt)
    )
    let conversation = try #require(received.conversations.first)
    #expect(received.unreadCount(in: conversation, localUserID: alex.id) == 1)
    #expect(received.messages.contains { $0.senderID == maya.id && $0.delivery == .demoOnDevice && !$0.isDemoNotice })
    let read = await transport.markRead(conversationID: conversation.id, at: receivedAt)
    #expect(read.unreadCount(in: try #require(read.conversations.first), localUserID: alex.id) == 0)

    let reported = await transport.report(attendeeID: maya.id, reason: "Spam", now: receivedAt)
    #expect(reported.reports.map(\.reason) == ["Spam"])

    let reloaded = LocalDemoMessageTransport(directory: directory)
    let stored = await reloaded.load()
    #expect(stored.messages.contains { $0.body == "Hello" && $0.delivery == .demoOnDevice })
    #expect(stored.reports.map(\.attendeeID) == [maya.id])
    #expect(!stored.messages.contains { $0.delivery == .acceptedByService })
}

#if canImport(Contacts) && !os(tvOS)
@Test func contactRecordUsesPublicFieldsOnly() async throws {
    let manifest = try await ConferenceLoader().load(.sample)
    let maya = try #require(manifest.attendee(id: "maya-chen"))
    let contact = AttendeeContacts.makeContact(maya)
    #expect(contact.emailAddresses.first.map { String($0.value) } == "maya@example.com")
    #expect(contact.phoneNumbers.isEmpty)
    #expect(contact.urlAddresses.isEmpty == false)
    let jordan = try #require(manifest.attendee(id: "jordan-hale"))
    let privateCard = AttendeeContacts.makeContact(jordan)
    #expect(privateCard.emailAddresses.isEmpty)
    #expect(privateCard.phoneNumbers.isEmpty)
    #expect(privateCard.urlAddresses.isEmpty)
}
#endif
