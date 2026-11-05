import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A contact card built only from fields the attendee marked public.
public struct AttendeeShareCard: Hashable, Sendable {
    public var attendeeID: String
    public var displayName: String
    public var role: String?
    public var company: String?
    public var bio: String
    public var email: String?
    public var phone: String?
    public var social: [SocialLink]
    public var vCard: String

    public init(
        attendeeID: String,
        displayName: String,
        role: String?,
        company: String?,
        bio: String,
        email: String?,
        phone: String?,
        social: [SocialLink],
        vCard: String
    ) {
        self.attendeeID = attendeeID
        self.displayName = displayName
        self.role = role
        self.company = company
        self.bio = bio
        self.email = email
        self.phone = phone
        self.social = social
        self.vCard = vCard
    }

    /// QR payloads are the filtered vCard, so a scan cannot reveal a hidden phone or email.
    public var qrPayload: String { vCard }

    public var suggestedFilename: String {
        let cleaned = displayName.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(cleaned)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let base = collapsed.isEmpty ? "attendee" : collapsed
        return base + ".vcf"
    }

    public var file: AttendeeVCardFile {
        AttendeeVCardFile(filename: suggestedFilename, text: vCard)
    }
}

public struct AttendeeVCardFile: Transferable, Hashable, Sendable {
    public var filename: String
    public var text: String

    public init(filename: String, text: String) {
        self.filename = filename
        self.text = text
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { file in
            Data(file.text.utf8)
        }
        .suggestedFileName(\.filename)
    }
}

public struct ParsedVCard: Hashable, Sendable {
    public var fullName: String
    public var organization: String?
    public var title: String?
    public var emails: [String]
    public var phones: [String]
    public var urls: [URL]
    public var note: String?

    public init(
        fullName: String,
        organization: String? = nil,
        title: String? = nil,
        emails: [String] = [],
        phones: [String] = [],
        urls: [URL] = [],
        note: String? = nil
    ) {
        self.fullName = fullName
        self.organization = organization
        self.title = title
        self.emails = emails
        self.phones = phones
        self.urls = urls
        self.note = note
    }
}

public enum AttendeeShare {
    /// `allowsUnlisted` is for My Profile, so someone can hand out a card without joining the directory.
    /// Other attendees only get a card when they are discoverable. Contact flags apply either way.
    public static func card(for attendee: Attendee, allowsUnlisted: Bool) -> AttendeeShareCard? {
        guard attendee.privacy.discoverable || allowsUnlisted else { return nil }
        let visible = attendee.hidingPrivateContactFields()
        let name = visible.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? "Attendee" : name
        let vCard = VCard.make(
            displayName: displayName,
            role: visible.role,
            company: visible.company,
            bio: visible.bio,
            email: visible.email,
            phone: visible.phone,
            urls: visible.social.map(\.url)
        )
        return AttendeeShareCard(
            attendeeID: attendee.id,
            displayName: displayName,
            role: visible.role,
            company: visible.company,
            bio: visible.bio,
            email: visible.email,
            phone: visible.phone,
            social: visible.social,
            vCard: vCard
        )
    }
}

/// vCard 3.0 (RFC 6350 escaping, CRLF, 75-octet folding).
public enum VCard {
    public static func make(from attendee: Attendee) -> String {
        let visible = attendee.hidingPrivateContactFields()
        return make(
            displayName: visible.displayName,
            role: visible.role,
            company: visible.company,
            bio: visible.bio,
            email: visible.email,
            phone: visible.phone,
            urls: visible.social.map(\.url)
        )
    }

    public static func make(
        displayName: String,
        role: String?,
        company: String?,
        bio: String,
        email: String?,
        phone: String?,
        urls: [URL]
    ) -> String {
        var lines = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "PRODID:-//45BitStudios//ConferenceKit//EN",
            "N:\(structuredName(displayName))",
            "FN:\(escape(displayName))"
        ]
        if let company, !company.isEmpty {
            lines.append("ORG:\(escape(company))")
        }
        if let role, !role.isEmpty {
            lines.append("TITLE:\(escape(role))")
        }
        if let email, !email.isEmpty {
            lines.append("EMAIL;TYPE=INTERNET:\(escape(email))")
        }
        if let phone, !phone.isEmpty {
            lines.append("TEL;TYPE=CELL:\(escape(phone))")
        }
        for url in urls {
            lines.append("URL:\(escape(url.absoluteString))")
        }
        if !bio.isEmpty {
            lines.append("NOTE:\(escape(bio))")
        }
        lines.append("END:VCARD")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    public static func parse(_ text: String) -> [ParsedVCard] {
        let unfolded = unfold(text)
        let blocks = unfolded.components(separatedBy: "BEGIN:VCARD")
        return blocks.compactMap { block in
            guard let end = block.range(of: "END:VCARD") else { return nil }
            let body = block[..<end.lowerBound]
            var card = ParsedVCard(fullName: "")
            for rawLine in body.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let colon = line.firstIndex(of: ":") else { continue }
                let left = String(line[..<colon])
                let value = unescape(String(line[line.index(after: colon)...]))
                let name = propertyName(left)
                switch name {
                case "FN":
                    card.fullName = value
                case "ORG":
                    card.organization = value
                case "TITLE":
                    card.title = value
                case "EMAIL":
                    if !value.isEmpty { card.emails.append(value) }
                case "TEL":
                    if !value.isEmpty { card.phones.append(value) }
                case "URL":
                    if let url = URL(string: value) { card.urls.append(url) }
                case "NOTE":
                    card.note = value
                default:
                    break
                }
            }
            if card.fullName.isEmpty { return nil }
            return card
        }
    }

    static func escape(_ value: String) -> String {
        var result = ""
        for character in value {
            switch character {
            case "\\": result += "\\\\"
            case ",": result += "\\,"
            case ";": result += "\\;"
            case "\n": result += "\\n"
            case "\r": continue
            default: result.append(character)
            }
        }
        return result
    }

    static func unescape(_ value: String) -> String {
        var result = ""
        var escaped = false
        for character in value {
            if escaped {
                switch character {
                case "n", "N": result.append("\n")
                case "\\", ",", ";": result.append(character)
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        if escaped { result.append("\\") }
        return result
    }

    private static func structuredName(_ displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(",") || trimmed.contains(";") {
            return ";\(escape(trimmed));;;"
        }
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.count >= 2 {
            let family = escape(parts[parts.count - 1])
            let given = escape(parts.dropLast().joined(separator: " "))
            return "\(family);\(given);;;"
        }
        return ";\(escape(trimmed));;;"
    }

    private static func propertyName(_ left: String) -> String {
        let withoutGroup = left.split(separator: ".").last.map(String.init) ?? left
        return withoutGroup.split(separator: ";").first.map { String($0).uppercased() } ?? ""
    }

    /// Fold at 75 octets. Continuation lines start with a single space.
    static func fold(_ line: String) -> String {
        let bytes = Array(line.utf8)
        if bytes.count <= 75 { return line }
        var chunks: [String] = []
        var index = 0
        var budget = 75
        while index < bytes.count {
            var end = min(index + budget, bytes.count)
            if end < bytes.count {
                while end > index && (bytes[end] & 0xC0) == 0x80 { end -= 1 }
                if end == index { end = min(index + budget, bytes.count) }
            }
            chunks.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end
            budget = 74
        }
        return chunks.enumerated().map { offset, chunk in
            offset == 0 ? chunk : " \(chunk)"
        }.joined(separator: "\r\n")
    }

    static func unfold(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output = ""
        for (index, line) in lines.enumerated() {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                output += line.dropFirst()
            } else {
                if index > 0 { output.append("\n") }
                output += line
            }
        }
        return output
    }
}
