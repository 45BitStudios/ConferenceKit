import ConferenceKit
import SwiftUI
import UniformTypeIdentifiers
#if canImport(CoreImage) && !os(watchOS)
import CoreImage
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Contacts) && !os(tvOS)
@preconcurrency import Contacts
#endif
#if canImport(ContactsUI) && (os(iOS) || os(visionOS))
@preconcurrency import ContactsUI
#endif
#if os(macOS)
import AppKit
#endif

struct AttendeeDirectory: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool
    @State private var ticketKind: String?

    private var people: [Attendee] {
        store.attendees(matching: AttendeeFilter(query: store.searchText, ticketKind: ticketKind))
    }

    private var ticketKinds: [String] {
        let kinds = Set(store.attendees(matching: AttendeeFilter()).compactMap { $0.ticket?.kind })
        return kinds.sorted()
    }

    var body: some View {
        List {
            Button {
                router.openMyProfile(push: push)
            } label: {
                Label("My Profile", systemImage: "person.crop.circle")
            }
            Button {
                router.openMessages(push: push)
            } label: {
                HStack {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    if let count = store.inbox?.unreadCount, count > 0 {
                        Text("\(count)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                            .foregroundStyle(.white)
                            .accessibilityLabel("\(count) unread")
                    }
                }
            }
            if people.isEmpty {
                Text(store.searchText.isEmpty ? "No one has joined the directory." : "No one matches.")
                    .foregroundStyle(.secondary)
            }
            ForEach(people) { attendee in
                Button {
                    router.openAttendee(attendee.id, push: push)
                } label: {
                    AttendeeRow(attendee: attendee, isYou: attendee.id == store.profileStore?.profile.id)
                }
                .buttonStyle(.plain)
                .siriEntity(.attendee(attendee.id))
            }
        }
        .navigationTitle("Attendees")
        .toolbar {
            if ticketKinds.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("All tickets") { ticketKind = nil }
                        ForEach(ticketKinds, id: \.self) { kind in
                            Button(kind) { ticketKind = kind }
                        }
                    } label: {
                        Label(ticketKind ?? "Tickets", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .task { await store.inbox?.refresh() }
    }
}

struct AttendeeColumn: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool

    var body: some View {
        if router.showsMessages, let id = router.selectedConversationID {
            ConversationScreen(store: store, router: router, conversationID: id)
        } else if router.showsMessages {
            ConversationList(store: store, router: router, push: push)
        } else if router.showsMyProfile {
            MyProfileScreen(store: store, router: router)
        } else if let id = router.selectedAttendeeID, let attendee = resolved(id) {
            AttendeeDetail(
                store: store,
                router: router,
                attendee: attendee,
                push: push,
                allowsUnlisted: store.profileStore?.profile.id == id
            )
        } else {
            EmptyPane(title: "Attendees", systemImage: "person.3", message: "Choose someone from the directory.")
        }
    }

    private func resolved(_ id: String) -> Attendee? {
        if let listed = store.directoryAttendee(id: id) { return listed }
        if store.profileStore?.profile.id == id { return store.profileStore?.profile.hidingPrivateContactFields() }
        return nil
    }
}

struct AttendeeRow: View {
    var attendee: Attendee
    var isYou: Bool

    var body: some View {
        HStack(spacing: 12) {
            AttendeeAvatar(attendee: attendee)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(attendee.displayName.isEmpty ? "Unnamed attendee" : attendee.displayName)
                        .font(.headline)
                    if isYou {
                        Text("You")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if !attendee.affiliation.isEmpty {
                    Text(attendee.affiliation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let ticket = attendee.ticket?.display, !ticket.isEmpty {
                    Text(ticket)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct AttendeeAvatar: View {
    var attendee: Attendee
    var diameter: CGFloat = 44

    var body: some View {
        avatar
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatar: some View {
        if let asset = attendee.avatarAsset, !asset.isEmpty {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else if attendee.avatarURL != nil {
            AsyncImage(url: attendee.avatarURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    initials
                }
            }
        } else {
            initials
        }
    }

    private var initials: some View {
        ZStack {
            Circle().fill(.quaternary)
            Text(attendee.initials)
                .font(.headline)
        }
    }
}

struct AttendeeDetail: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var attendee: Attendee
    var push: Bool
    var allowsUnlisted: Bool
    @State private var reporting = false

    private var isYou: Bool { store.profileStore?.profile.id == attendee.id }
    private var blocked: Bool { store.inbox?.isBlocked(attendee.id) ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    AttendeeAvatar(attendee: attendee, diameter: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attendee.displayName).font(.title2.weight(.semibold))
                        if !attendee.affiliation.isEmpty {
                            Text(attendee.affiliation).foregroundStyle(.secondary)
                        }
                        if let ticket = attendee.ticket?.display {
                            Text(ticket).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !attendee.bio.isEmpty {
                    Text(attendee.bio).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let email = attendee.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
                if let phone = attendee.phone, !phone.isEmpty {
                    LabeledContent("Phone", value: phone)
                }
                ForEach(attendee.social) { link in
                    Link(destination: link.url) { Label(link.platform.label, systemImage: "link") }
                }
                if isYou {
                    Button("Edit profile") { router.openMyProfile(push: push) }
                        .buttonStyle(.bordered)
                } else {
                    messageControls
                    AttendeeModeration(store: store, attendeeID: attendee.id, reporting: $reporting)
                }
                AttendeeShareSection(store: store, router: router, attendee: isYou ? (store.profileStore?.profile ?? attendee) : attendee, allowsUnlisted: allowsUnlisted || isYou)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(attendee.displayName)
        .confirmationDialog("Report this person", isPresented: $reporting, titleVisibility: .visible) {
            Button("Spam") { report("Spam") }
            Button("Harassment") { report("Harassment") }
            Button("Other") { report("Other") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The report stays on this device until a messaging service exists.")
        }
    }

    @ViewBuilder
    private var messageControls: some View {
        if blocked {
            Text("You blocked this person. Unblock them from the menu to message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let context = store.messagingContext(for: attendee.id),
                  let denial = AttendeeMessagingPolicy.denial(context: context, storedBlockedIDs: Set(store.inbox?.snapshot.blockedIDs ?? [])) {
            Text(denial.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let me = store.profileStore?.profile {
            Button {
                let id = AttendeeMessaging.conversationID(participantIDs: [me.id, attendee.id])
                router.openConversation(id, push: push)
            } label: {
                Label("Message", systemImage: "bubble.left")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func report(_ reason: String) {
        Task { await store.inbox?.report(attendee.id, reason: reason) }
    }
}

struct AttendeeModeration: View {
    @Bindable var store: ConferenceStore
    var attendeeID: String
    @Binding var reporting: Bool

    private var blocked: Bool { store.inbox?.isBlocked(attendeeID) ?? false }

    var body: some View {
        HStack {
            Button(blocked ? "Unblock" : "Block") {
                Task { await store.inbox?.setBlocked(attendeeID, blocked: !blocked) }
            }
            Button("Report") { reporting = true }
        }
        .buttonStyle(.bordered)
    }
}

struct MyProfileScreen: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    @State private var importingFile = false
    @State private var importingContact = false
    @State private var imported: [ParsedVCard] = []
    @State private var importError: String?
    @State private var draftPlatform: SocialPlatform = .website
    @State private var draftURL = ""

    private var profile: Attendee? { store.profileStore?.profile }

    var body: some View {
        Form {
            if profile != nil {
                Section("Profile") {
                    TextField("Name", text: text(\.displayName))
                    TextField("Role", text: optional(\.role))
                    TextField("Company", text: optional(\.company))
                    TextField("Bio", text: text(\.bio), axis: .vertical)
                    TextField("Email", text: optional(\.email))
                        #if os(iOS) || os(macOS) || os(visionOS)
                        .textContentType(.emailAddress)
                        #endif
                    TextField("Phone", text: optional(\.phone))
                        #if os(iOS) || os(macOS) || os(visionOS)
                        .textContentType(.telephoneNumber)
                        #endif
                    TextField("Avatar URL", text: urlText)
                    TextField("Avatar asset name", text: optional(\.avatarAsset))
                }
                Section("Links") {
                    if let links = profile?.social, !links.isEmpty {
                        ForEach(links) { link in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(link.platform.label)
                                    Text(link.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Remove") {
                                    store.updateMyProfile { person in
                                        person.social.removeAll { $0.id == link.id }
                                    }
                                }
                            }
                        }
                    }
                    Picker("Platform", selection: $draftPlatform) {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            Text(platform.label).tag(platform)
                        }
                    }
                    TextField("https://", text: $draftURL)
                    Button("Add link") { addLink() }
                        .disabled(URL(string: draftURL) == nil)
                }
                Section("Privacy") {
                    Toggle("Discoverable", isOn: flag(\.discoverable))
                    Toggle("Show email", isOn: flag(\.showsEmail))
                    Toggle("Show phone", isOn: flag(\.showsPhone))
                    Toggle("Show social links", isOn: flag(\.showsSocial))
                    Toggle("Allow messages", isOn: consent)
                    Text("Email, phone, and social links stay off the directory, the QR code, and the vCard until you turn them on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let profile {
                    Section("What others see") {
                        if profile.privacy.discoverable {
                            let visible = profile.hidingPrivateContactFields()
                            Text(visible.displayName)
                            if !visible.affiliation.isEmpty { Text(visible.affiliation).foregroundStyle(.secondary) }
                            if let email = visible.email { Text(email) }
                            if let phone = visible.phone { Text(phone) }
                            if visible.social.isEmpty && visible.email == nil && visible.phone == nil {
                                Text("No contact fields are public.").foregroundStyle(.secondary)
                            }
                        } else {
                            Text("You are hidden from the directory.").foregroundStyle(.secondary)
                        }
                    }
                    Section("Share") {
                        AttendeeShareSection(store: store, router: router, attendee: profile, allowsUnlisted: true)
                        importControls
                    }
                }
                if !imported.isEmpty {
                    Section("Imported on this device") {
                        Text("These contacts are not added to the directory and are not messaged.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(Array(imported.enumerated()), id: \.offset) { _, card in
                            VStack(alignment: .leading) {
                                Text(card.fullName).font(.headline)
                                if let organization = card.organization { Text(organization).foregroundStyle(.secondary) }
                                if let email = card.emails.first { Text(email) }
                                if let phone = card.phones.first { Text(phone) }
                            }
                        }
                    }
                }
                if let importError {
                    Section { Text(importError).foregroundStyle(.red) }
                }
            }
        }
        .navigationTitle("My Profile")
        #if os(iOS) || os(macOS) || os(visionOS)
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.vCard, .text]) { result in
            switch result {
            case .success(let url):
                loadFile(url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        #endif
        #if canImport(ContactsUI) && (os(iOS) || os(visionOS))
        .sheet(isPresented: $importingContact) {
            ContactPicker { card in
                imported.append(card)
            }
        }
        #endif
    }

    private var consent: Binding<Bool> {
        Binding(
            get: { store.profileStore?.profile.messagingConsent ?? false },
            set: { value in store.updateMyProfile { $0.messagingConsent = value } }
        )
    }

    private var urlText: Binding<String> {
        Binding(
            get: { store.profileStore?.profile.avatarURL?.absoluteString ?? "" },
            set: { newValue in
                store.updateMyProfile { person in
                    person.avatarURL = newValue.isEmpty ? nil : URL(string: newValue)
                }
            }
        )
    }

    private func text(_ keyPath: WritableKeyPath<Attendee, String>) -> Binding<String> {
        Binding(
            get: { store.profileStore?.profile[keyPath: keyPath] ?? "" },
            set: { newValue in store.updateMyProfile { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func optional(_ keyPath: WritableKeyPath<Attendee, String?>) -> Binding<String> {
        Binding(
            get: { store.profileStore?.profile[keyPath: keyPath] ?? "" },
            set: { newValue in
                store.updateMyProfile { person in
                    person[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                }
            }
        )
    }

    private func flag(_ keyPath: WritableKeyPath<AttendeePrivacy, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.profileStore?.profile.privacy[keyPath: keyPath] ?? false },
            set: { value in store.updateMyProfile { $0.privacy[keyPath: keyPath] = value } }
        )
    }

    private func addLink() {
        guard let url = URL(string: draftURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        store.updateMyProfile { $0.social.append(SocialLink(platform: draftPlatform, url: url)) }
        draftURL = ""
    }

    @ViewBuilder
    private var importControls: some View {
        #if os(iOS) || os(macOS) || os(visionOS)
        Button("Import a vCard") { importingFile = true }
        #else
        Text("Import a .vcf file on iPhone, iPad, Mac, or Vision Pro.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
        #if canImport(ContactsUI) && (os(iOS) || os(visionOS))
        Button("Import from Contacts") { importingContact = true }
        #endif
    }

    private func loadFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importError = "That file couldn’t be read."
            return
        }
        let cards = VCard.parse(text)
        guard !cards.isEmpty else {
            importError = "That file didn’t contain a contact card."
            return
        }
        importError = nil
        imported.append(contentsOf: cards)
    }
}

struct AttendeeShareSection: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var attendee: Attendee
    var allowsUnlisted: Bool
    @State private var showingComposer = false

    var body: some View {
        if let card = AttendeeShare.card(for: attendee, allowsUnlisted: allowsUnlisted) {
            VStack(alignment: .leading, spacing: 12) {
                AttendeeQRCode(payload: card.qrPayload)
                Text("The code and the card include only fields marked public.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #if !os(tvOS)
                ShareLink(
                    item: card.file,
                    preview: SharePreview(card.displayName, image: Image(systemName: "person.crop.rectangle"))
                ) {
                    Label("Share contact card", systemImage: "square.and.arrow.up")
                }
                #endif
                saveControl(card)
            }
            #if canImport(ContactsUI) && (os(iOS) || os(visionOS))
            .sheet(isPresented: $showingComposer) {
                ContactComposer(attendee: attendee)
            }
            #endif
        } else {
            Text("This person isn’t sharing a contact card.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func saveControl(_ card: AttendeeShareCard) -> some View {
        #if canImport(ContactsUI) && (os(iOS) || os(visionOS))
        Button {
            showingComposer = true
        } label: {
            Label("Save to Contacts", systemImage: "person.crop.circle.badge.plus")
        }
        #elseif canImport(Contacts) && (os(macOS) || os(watchOS))
        Button("Save to Contacts") {
            Task {
                router.statusMessage = await AttendeeContactSaving.save(attendee)
            }
        }
        #if os(macOS)
        Button("Open card in Contacts") {
            router.statusMessage = AttendeeContactSaving.openCard(card)
        }
        #endif
        #else
        Text("Save the card from a device that has Contacts.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }
}

struct AttendeeQRCode: View {
    var payload: String

    var body: some View {
        if let image = Self.image(for: payload) {
            image
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 220)
                .accessibilityLabel("QR code for the public contact card")
        } else {
            Text("QR isn’t available on this screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static func image(for payload: String) -> Image? {
        #if canImport(CoreImage) && !os(watchOS)
        guard !payload.isEmpty else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter?.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #elseif canImport(AppKit)
        return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }
}

enum AttendeeContactSaving {
    @MainActor
    static func save(_ attendee: Attendee) async -> String {
        #if canImport(Contacts) && !os(tvOS)
        do {
            let granted = try await CNContactStore().requestAccess(for: .contacts)
            guard granted else { return "Contacts access is off." }
            let store = CNContactStore()
            let contact = AttendeeContacts.makeContact(attendee)
            let request = CNSaveRequest()
            request.add(contact, toContainerWithIdentifier: nil)
            try store.execute(request)
            return "Saved \(attendee.hidingPrivateContactFields().displayName) to Contacts."
        } catch {
            return error.localizedDescription
        }
        #else
        return "Contacts isn’t available here."
        #endif
    }

    #if os(macOS)
    static func openCard(_ card: AttendeeShareCard) -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(card.suggestedFilename)
        do {
            try card.vCard.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
            return "Opened the contact card."
        } catch {
            return error.localizedDescription
        }
    }
    #endif
}

#if canImport(ContactsUI) && (os(iOS) || os(visionOS))
struct ContactComposer: UIViewControllerRepresentable {
    var attendee: Attendee
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: AttendeeContacts.makeContact(attendee))
        controller.delegate = context.coordinator
        controller.allowsActions = false
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.onDone = { dismiss() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, CNContactViewControllerDelegate, @unchecked Sendable {
        var onDone: (@MainActor () -> Void)?
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            Task { @MainActor in
                self.onDone?()
            }
        }
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (ParsedVCard) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactUrlAddressesKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        let pick = onPick
        context.coordinator.onPick = { card in pick(card) }
        context.coordinator.onDone = { dismiss() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, CNContactPickerDelegate, @unchecked Sendable {
        var onPick: (@MainActor (ParsedVCard) -> Void)?
        var onDone: (@MainActor () -> Void)?
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let card = ParsedVCard(contact: contact)
            Task { @MainActor in
                self.onPick?(card)
                self.onDone?()
            }
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            Task { @MainActor in
                self.onDone?()
            }
        }
    }
}

extension ParsedVCard {
    init(contact: CNContact) {
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        self.init(
            fullName: name.isEmpty ? "Imported contact" : name,
            organization: contact.organizationName.isEmpty ? nil : contact.organizationName,
            title: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
            emails: contact.emailAddresses.map { $0.value as String },
            phones: contact.phoneNumbers.map(\.value.stringValue),
            urls: contact.urlAddresses.compactMap { URL(string: $0.value as String) }
        )
    }
}
#endif

struct ConversationList: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool

    private var conversations: [AttendeeConversation] {
        store.inbox?.snapshot.sortedConversations ?? []
    }

    var body: some View {
        List {
            Section {
                Text("Local demo. Messages stay on this device. They are not delivered to another attendee.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let sample = sampleRecipient {
                    Button("Show a sample thread") {
                        Task {
                            await store.inbox?.receiveSample(
                                from: sample.id,
                                body: "Sample data on this device. \(sample.displayName) did not send this."
                            )
                        }
                    }
                }
            }
            if conversations.isEmpty {
                Text("No conversations yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(conversations) { conversation in
                Button {
                    router.openConversation(conversation.id, push: push)
                } label: {
                    conversationRow(conversation)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Messages")
        .task { await store.inbox?.refresh() }
    }

    private var sampleRecipient: Attendee? {
        guard let me = store.profileStore?.profile else { return nil }
        return store.manifest?.directoryAttendees().first { person in
            person.id != me.id && person.messagingConsent && me.privacy.discoverable && me.messagingConsent
        }
    }

    private func conversationRow(_ conversation: AttendeeConversation) -> some View {
        let localID = store.profileStore?.profile.id ?? ""
        let otherID = conversation.otherParticipantID(localUserID: localID)
        let name = otherID.flatMap { store.directoryAttendee(id: $0)?.displayName } ?? "Attendee"
        let preview = store.inbox?.snapshot.messages(in: conversation.id).last
        let unread = store.inbox?.snapshot.unreadCount(in: conversation, localUserID: localID) ?? 0
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                if let preview, !preview.isDemoNotice {
                    Text(preview.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("Demo transport").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.red, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
}

struct ConversationScreen: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var conversationID: String
    @State private var draft = ""
    @State private var reporting = false

    private var localID: String { store.profileStore?.profile.id ?? "" }

    private var otherID: String? {
        if let conversation = store.inbox?.snapshot.conversations.first(where: { $0.id == conversationID }) {
            return conversation.otherParticipantID(localUserID: localID)
        }
        return conversationID.split(separator: "|").map(String.init).first { $0 != localID }
    }

    private var other: Attendee? {
        otherID.flatMap { store.directoryAttendee(id: $0) ?? store.attendees.first { person in person.id == $0 } }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Demo transport. Nothing on this screen is sent to \(other?.displayName ?? "the other person").")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.inbox?.snapshot.messages(in: conversationID) ?? []) { message in
                        messageRow(message)
                    }
                }
                .padding()
            }
            if let error = store.inbox?.lastError, !error.isEmpty {
                Text(error).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
            composer
        }
        .navigationTitle(other?.displayName ?? "Message")
        .toolbar {
            if let otherID, otherID != localID {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(store.inbox?.isBlocked(otherID) == true ? "Unblock" : "Block") {
                            let blocked = store.inbox?.isBlocked(otherID) == true
                            Task { await store.inbox?.setBlocked(otherID, blocked: !blocked) }
                        }
                        Button("Report") { reporting = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Report this person", isPresented: $reporting, titleVisibility: .visible) {
            if let otherID {
                Button("Spam") { Task { await store.inbox?.report(otherID, reason: "Spam") } }
                Button("Harassment") { Task { await store.inbox?.report(otherID, reason: "Harassment") } }
                Button("Other") { Task { await store.inbox?.report(otherID, reason: "Other") } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await store.inbox?.refresh()
            await store.inbox?.markRead(conversationID: conversationID)
        }
    }

    @ViewBuilder
    private func messageRow(_ message: AttendeeMessage) -> some View {
        if message.isDemoNotice {
            Text(message.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            let mine = message.senderID == localID
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(10)
                    .background(mine ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                if mine {
                    Text(message.delivery == .demoOnDevice ? "On this device · not delivered" : message.delivery.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private var composer: some View {
        if let otherID, store.inbox?.isBlocked(otherID) == true {
            Text("You blocked this person.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        } else if let otherID, let context = store.messagingContext(for: otherID),
                  let denial = AttendeeMessagingPolicy.denial(context: context, storedBlockedIDs: Set(store.inbox?.snapshot.blockedIDs ?? [])) {
            Text(denial.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        } else {
            HStack {
                TextField("Message", text: $draft)
                Button("Send") {
                    let body = draft
                    draft = ""
                    guard let otherID else { return }
                    Task {
                        if let context = store.messagingContext(for: otherID) {
                            await store.inbox?.send(body: body, to: otherID, context: context)
                        }
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }
}

#if os(tvOS)
struct TVAttendeeGrid: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter

    private var people: [Attendee] {
        store.attendees(matching: AttendeeFilter(query: store.searchText))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 24) {
                    Button {
                        router.openMyProfile(push: true)
                    } label: {
                        Label("My Profile", systemImage: "person.crop.circle")
                            .padding(24)
                    }
                    .buttonStyle(.card)
                    Button {
                        router.openMessages(push: true)
                    } label: {
                        Label("Messages", systemImage: "bubble.left.and.bubble.right")
                            .padding(24)
                    }
                    .buttonStyle(.card)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 36)], spacing: 36) {
                    ForEach(people) { attendee in
                        Button {
                            router.openAttendee(attendee.id, push: true)
                        } label: {
                            VStack(spacing: 12) {
                                AttendeeAvatar(attendee: attendee, diameter: 96)
                                Text(attendee.displayName).font(.headline).lineLimit(2)
                                Text(attendee.affiliation).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .padding(24)
                            .frame(width: 320, height: 280)
                        }
                        .buttonStyle(.card)
                    }
                }
            }
            .padding(48)
        }
    }
}
#endif
