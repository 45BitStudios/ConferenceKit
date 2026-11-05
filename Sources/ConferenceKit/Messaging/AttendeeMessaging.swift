import Foundation

/// How far a message got. The demo transport never leaves the device, so it
/// stops at `demoOnDevice`. `acceptedByService` is reserved for a later backend.
public enum MessageDeliveryState: String, Codable, Hashable, Sendable, CaseIterable {
    case queued
    case demoOnDevice
    case rejected
    case acceptedByService
}

public struct AttendeeConversation: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var participantIDs: [String]
    public var lastReadAt: Date?
    public var updatedAt: Date

    public init(id: String, participantIDs: [String], lastReadAt: Date? = nil, updatedAt: Date) {
        self.id = id
        self.participantIDs = participantIDs
        self.lastReadAt = lastReadAt
        self.updatedAt = updatedAt
    }

    public func otherParticipantID(localUserID: String) -> String? {
        participantIDs.first { $0 != localUserID }
    }
}

public struct AttendeeMessage: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var conversationID: String
    public var senderID: String
    public var body: String
    public var sentAt: Date
    public var delivery: MessageDeliveryState
    /// A line written by the local demo transport. It is not a message from an attendee.
    public var isDemoNotice: Bool

    public init(
        id: String = UUID().uuidString,
        conversationID: String,
        senderID: String,
        body: String,
        sentAt: Date,
        delivery: MessageDeliveryState,
        isDemoNotice: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.body = body
        self.sentAt = sentAt
        self.delivery = delivery
        self.isDemoNotice = isDemoNotice
    }
}

public struct AttendeeReport: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var attendeeID: String
    public var reason: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, attendeeID: String, reason: String, createdAt: Date) {
        self.id = id
        self.attendeeID = attendeeID
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct AttendeeInboxSnapshot: Codable, Hashable, Sendable {
    public var conversations: [AttendeeConversation]
    public var messages: [AttendeeMessage]
    public var blockedIDs: [String]
    public var reports: [AttendeeReport]

    public init(
        conversations: [AttendeeConversation] = [],
        messages: [AttendeeMessage] = [],
        blockedIDs: [String] = [],
        reports: [AttendeeReport] = []
    ) {
        self.conversations = conversations
        self.messages = messages
        self.blockedIDs = blockedIDs
        self.reports = reports
    }

    public func messages(in conversationID: String) -> [AttendeeMessage] {
        messages.filter { $0.conversationID == conversationID }.sorted { $0.sentAt < $1.sentAt }
    }

    public func unreadCount(in conversation: AttendeeConversation, localUserID: String) -> Int {
        let cutoff = conversation.lastReadAt ?? .distantPast
        return messages(in: conversation.id).filter { message in
            message.senderID != localUserID
                && !message.isDemoNotice
                && message.sentAt > cutoff
        }.count
    }

    public func totalUnread(localUserID: String) -> Int {
        conversations.reduce(0) { $0 + unreadCount(in: $1, localUserID: localUserID) }
    }

    public var sortedConversations: [AttendeeConversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }
}

public struct OutgoingAttendeeMessage: Hashable, Sendable {
    public var senderID: String
    public var recipientID: String
    public var body: String

    public init(senderID: String, recipientID: String, body: String) {
        self.senderID = senderID
        self.recipientID = recipientID
        self.body = body
    }
}

public struct IncomingDemoMessage: Hashable, Sendable {
    public var senderID: String
    public var recipientID: String
    public var body: String
    public var sentAt: Date

    public init(senderID: String, recipientID: String, body: String, sentAt: Date = .now) {
        self.senderID = senderID
        self.recipientID = recipientID
        self.body = body
        self.sentAt = sentAt
    }
}

public struct AttendeeVisibility: Hashable, Sendable {
    public var id: String
    public var discoverable: Bool
    public var messagingConsent: Bool

    public init(id: String, discoverable: Bool, messagingConsent: Bool) {
        self.id = id
        self.discoverable = discoverable
        self.messagingConsent = messagingConsent
    }

    public init(_ attendee: Attendee) {
        self.init(id: attendee.id, discoverable: attendee.privacy.discoverable, messagingConsent: attendee.messagingConsent)
    }
}

public struct AttendeeMessagingContext: Hashable, Sendable {
    public var sender: AttendeeVisibility
    public var recipient: AttendeeVisibility
    public var blockedIDs: Set<String>

    public init(sender: AttendeeVisibility, recipient: AttendeeVisibility, blockedIDs: Set<String> = []) {
        self.sender = sender
        self.recipient = recipient
        self.blockedIDs = blockedIDs
    }
}

public enum AttendeeMessagingDenial: String, Hashable, Sendable {
    case senderNotDiscoverable
    case recipientNotDiscoverable
    case senderDeclined
    case recipientDeclined
    case blocked
    case selfMessage

    public var explanation: String {
        switch self {
        case .senderNotDiscoverable:
            "Turn on Discoverable in My Profile before messaging."
        case .recipientNotDiscoverable:
            "This person isn’t in the directory."
        case .senderDeclined:
            "Turn on messaging in My Profile to send."
        case .recipientDeclined:
            "This person hasn’t turned on messages."
        case .blocked:
            "You blocked this person."
        case .selfMessage:
            "That’s your own profile."
        }
    }
}

public enum AttendeeMessagingError: Error, Hashable, Sendable {
    case notPermitted(AttendeeMessagingDenial)
    case emptyBody

    public var explanation: String {
        switch self {
        case .notPermitted(let denial): denial.explanation
        case .emptyBody: "Write a message first."
        }
    }
}

public enum AttendeeMessagingPolicy {
    public static func denial(context: AttendeeMessagingContext, storedBlockedIDs: Set<String> = []) -> AttendeeMessagingDenial? {
        if context.sender.id == context.recipient.id { return .selfMessage }
        if context.blockedIDs.contains(context.recipient.id) || storedBlockedIDs.contains(context.recipient.id) {
            return .blocked
        }
        if !context.sender.discoverable { return .senderNotDiscoverable }
        if !context.recipient.discoverable { return .recipientNotDiscoverable }
        if !context.sender.messagingConsent { return .senderDeclined }
        if !context.recipient.messagingConsent { return .recipientDeclined }
        return nil
    }
}

public struct AttendeeMessagingResult: Hashable, Sendable {
    public var snapshot: AttendeeInboxSnapshot
    public var message: AttendeeMessage
    /// Observed states for this send. The demo path is queued, then stored on device.
    public var deliveryStates: [MessageDeliveryState]

    public init(snapshot: AttendeeInboxSnapshot, message: AttendeeMessage, deliveryStates: [MessageDeliveryState]) {
        self.snapshot = snapshot
        self.message = message
        self.deliveryStates = deliveryStates
    }
}

public enum AttendeeMessaging {
    /// Sender id for lines the demo transport inserts. Not a real attendee.
    public static let demoTransportID = "conferencekit.demo-transport"
    public static let demoNotice = "Demo transport: this message stays on this device. It was not sent to the other attendee."

    public static func conversationID(participantIDs: [String]) -> String {
        participantIDs.sorted().joined(separator: "|")
    }
}

/// A later remote service replaces `LocalDemoMessageTransport` without changing the screens.
public protocol AttendeeMessageTransport: Sendable {
    func load() async -> AttendeeInboxSnapshot
    func send(_ draft: OutgoingAttendeeMessage, context: AttendeeMessagingContext, now: Date) async throws -> AttendeeMessagingResult
    /// Inserts a message that was not received from a network. Tests and the labeled sample button use this.
    func receiveDemo(_ incoming: IncomingDemoMessage) async -> AttendeeInboxSnapshot
    func markRead(conversationID: String, at: Date) async -> AttendeeInboxSnapshot
    func setBlocked(attendeeID: String, blocked: Bool) async -> AttendeeInboxSnapshot
    func report(attendeeID: String, reason: String, now: Date) async -> AttendeeInboxSnapshot
}

/// On-device stand-in. It persists JSON and never opens a connection.
public actor LocalDemoMessageTransport: AttendeeMessageTransport {
    public let directory: URL
    private var snapshot = AttendeeInboxSnapshot()
    private let fileURL: URL

    public init(directory: URL) {
        self.directory = directory
        fileURL = directory.appendingPathComponent("messages.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(AttendeeInboxSnapshot.self, from: data) {
            snapshot = stored
        }
    }

    public func load() async -> AttendeeInboxSnapshot { snapshot }

    public func send(_ draft: OutgoingAttendeeMessage, context: AttendeeMessagingContext, now: Date) async throws -> AttendeeMessagingResult {
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw AttendeeMessagingError.emptyBody }
        let blocked = Set(snapshot.blockedIDs)
        if let denial = AttendeeMessagingPolicy.denial(context: context, storedBlockedIDs: blocked) {
            throw AttendeeMessagingError.notPermitted(denial)
        }
        let conversationID = AttendeeMessaging.conversationID(participantIDs: [draft.senderID, draft.recipientID])
        if snapshot.conversations.contains(where: { $0.id == conversationID }) == false {
            snapshot.conversations.append(
                AttendeeConversation(
                    id: conversationID,
                    participantIDs: [draft.senderID, draft.recipientID].sorted(),
                    updatedAt: now
                )
            )
        }
        var message = AttendeeMessage(
            conversationID: conversationID,
            senderID: draft.senderID,
            body: body,
            sentAt: now,
            delivery: .queued
        )
        snapshot.messages.append(message)
        touch(conversationID, at: now)
        message.delivery = .demoOnDevice
        replace(message)
        let notice = AttendeeMessage(
            conversationID: conversationID,
            senderID: AttendeeMessaging.demoTransportID,
            body: AttendeeMessaging.demoNotice,
            sentAt: now.addingTimeInterval(0.001),
            delivery: .demoOnDevice,
            isDemoNotice: true
        )
        snapshot.messages.append(notice)
        touch(conversationID, at: notice.sentAt)
        persist()
        return AttendeeMessagingResult(
            snapshot: snapshot,
            message: message,
            deliveryStates: [.queued, .demoOnDevice]
        )
    }

    public func receiveDemo(_ incoming: IncomingDemoMessage) async -> AttendeeInboxSnapshot {
        let conversationID = AttendeeMessaging.conversationID(participantIDs: [incoming.senderID, incoming.recipientID])
        if snapshot.conversations.contains(where: { $0.id == conversationID }) == false {
            snapshot.conversations.append(
                AttendeeConversation(
                    id: conversationID,
                    participantIDs: [incoming.senderID, incoming.recipientID].sorted(),
                    updatedAt: incoming.sentAt
                )
            )
        }
        let message = AttendeeMessage(
            conversationID: conversationID,
            senderID: incoming.senderID,
            body: incoming.body,
            sentAt: incoming.sentAt,
            delivery: .demoOnDevice
        )
        snapshot.messages.append(message)
        touch(conversationID, at: incoming.sentAt)
        persist()
        return snapshot
    }

    public func markRead(conversationID: String, at: Date) async -> AttendeeInboxSnapshot {
        guard let index = snapshot.conversations.firstIndex(where: { $0.id == conversationID }) else { return snapshot }
        let latest = snapshot.messages(in: conversationID).map(\.sentAt).max() ?? at
        snapshot.conversations[index].lastReadAt = max(latest, at)
        persist()
        return snapshot
    }

    public func setBlocked(attendeeID: String, blocked: Bool) async -> AttendeeInboxSnapshot {
        var ids = Set(snapshot.blockedIDs)
        if blocked { ids.insert(attendeeID) } else { ids.remove(attendeeID) }
        snapshot.blockedIDs = ids.sorted()
        persist()
        return snapshot
    }

    public func report(attendeeID: String, reason: String, now: Date) async -> AttendeeInboxSnapshot {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.reports.append(
            AttendeeReport(attendeeID: attendeeID, reason: trimmed.isEmpty ? "Unspecified" : trimmed, createdAt: now)
        )
        persist()
        return snapshot
    }

    private func replace(_ message: AttendeeMessage) {
        guard let index = snapshot.messages.firstIndex(where: { $0.id == message.id }) else { return }
        snapshot.messages[index] = message
    }

    private func touch(_ conversationID: String, at date: Date) {
        guard let index = snapshot.conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        snapshot.conversations[index].updatedAt = date
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Screen-facing copy of the transport. The demo implementation is the default.
@Observable
@MainActor
public final class AttendeeInbox {
    public private(set) var snapshot = AttendeeInboxSnapshot()
    public private(set) var lastError: String?
    public var localUserID: String
    public let transportName = "Local demo"
    private let transport: any AttendeeMessageTransport

    public init(transport: any AttendeeMessageTransport, localUserID: String) {
        self.transport = transport
        self.localUserID = localUserID
    }

    public var unreadCount: Int {
        snapshot.totalUnread(localUserID: localUserID)
    }

    public func isBlocked(_ attendeeID: String) -> Bool {
        snapshot.blockedIDs.contains(attendeeID)
    }

    public func refresh() async {
        snapshot = await transport.load()
    }

    public func send(body: String, to recipientID: String, context: AttendeeMessagingContext) async {
        do {
            let result = try await transport.send(
                OutgoingAttendeeMessage(senderID: localUserID, recipientID: recipientID, body: body),
                context: context,
                now: .now
            )
            snapshot = result.snapshot
            lastError = nil
        } catch let error as AttendeeMessagingError {
            lastError = error.explanation
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func receiveSample(from attendeeID: String, body: String) async {
        snapshot = await transport.receiveDemo(
            IncomingDemoMessage(senderID: attendeeID, recipientID: localUserID, body: body)
        )
    }

    public func markRead(conversationID: String) async {
        snapshot = await transport.markRead(conversationID: conversationID, at: .now)
    }

    public func setBlocked(_ attendeeID: String, blocked: Bool) async {
        snapshot = await transport.setBlocked(attendeeID: attendeeID, blocked: blocked)
    }

    public func report(_ attendeeID: String, reason: String) async {
        snapshot = await transport.report(attendeeID: attendeeID, reason: reason, now: .now)
        lastError = "Report saved on this device. A messaging service would review it later."
    }
}
