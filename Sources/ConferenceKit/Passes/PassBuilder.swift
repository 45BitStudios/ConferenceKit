import CryptoKit
import Foundation

/// ZIP CRC-32 (ISO 3309), the checksum a `.pkpass` archive stores per file.
public enum PassArchiveChecksum {
    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { entry in
        var value = UInt32(entry)
        for _ in 0..<8 {
            if value & 1 == 1 {
                value = 0xEDB8_8320 ^ (value >> 1)
            } else {
                value >>= 1
            }
        }
        return value
    }
}

/// Builds the unsigned pieces of an event-ticket `.pkpass`.
///
/// A pass Wallet will accept is a zip of `pass.json`, `manifest.json`, a
/// `signature` (PKCS #7 detached), and at least `icon.png`. This type writes
/// `pass.json` and `manifest.json` (SHA-1 of each file, lowercase hex) and an
/// uncompressed zip. It does **not** sign.
///
/// Signing requires Vince's Pass Type ID and the Pass Type ID certificate from
/// the Apple Developer account, plus the Apple WWDR intermediate. Replace
/// `placeholderPassTypeIdentifier` and `placeholderTeamIdentifier` with those
/// values, add real `icon.png` / `logo.png` artwork, then sign with `signpass`
/// or `openssl smime`. Until that certificate is available, `isSigned` stays
/// false and the ticket screen shows the barcode instead of Add to Wallet.
public enum PassBuilder {
    /// Not a real Pass Type ID. Vince replaces this before anyone signs a pass.
    public static let placeholderPassTypeIdentifier = "pass.studio45.conferencekit.sgconf"
    /// Not a real Team ID. It has to match the certificate's team.
    public static let placeholderTeamIdentifier = "TEAMID"
    public static let organizationName = "45BitStudios"

    public static let signingRequirement = """
    Adding this ticket to Wallet needs a signed .pkpass. Signing requires Vince’s \
    Pass Type ID and the Pass Type ID certificate, plus the Apple WWDR intermediate. \
    PassBuilder writes pass.json, manifest.json, and an unsigned zip. It does not \
    create the signature file. Replace \(placeholderPassTypeIdentifier) and team \
    \(placeholderTeamIdentifier), add icon.png, then sign. The ticket QR works before that.
    """

    public static func sha1Hex(_ data: Data) -> String {
        Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func build(
        pass: ConferencePass,
        passTypeIdentifier: String = placeholderPassTypeIdentifier,
        teamIdentifier: String = placeholderTeamIdentifier,
        organizationName: String = organizationName,
        signature: Data? = nil
    ) throws -> PassPackage {
        let document = PassDocument(
            formatVersion: 1,
            passTypeIdentifier: passTypeIdentifier,
            serialNumber: pass.id,
            teamIdentifier: teamIdentifier,
            organizationName: organizationName,
            description: "\(pass.conferenceName) ticket",
            logoText: pass.conferenceName,
            foregroundColor: "rgb(255, 255, 255)",
            backgroundColor: "rgb(28, 28, 30)",
            labelColor: "rgb(255, 196, 120)",
            relevantDate: pass.relevantDate,
            eventTicket: PassEventTicket(
                primaryFields: [PassField(key: "attendee", label: "ATTENDEE", value: pass.attendeeName)],
                secondaryFields: [PassField(key: "ticket", label: "TICKET", value: pass.seatOrTicketType)],
                auxiliaryFields: [PassField(key: "venue", label: "VENUE", value: pass.venueName)],
                backFields: backFields(pass)
            ),
            barcode: PassBarcode(message: pass.barcodePayload),
            barcodes: [PassBarcode(message: pass.barcodePayload)]
        )
        let encoder = ConferenceLoader.makeEncoder()
        let passJSON = try encoder.encode(document)
        var files = ["pass.json": passJSON]
        let manifest = Dictionary(uniqueKeysWithValues: files.map { ($0.key, sha1Hex($0.value)) })
        let manifestJSON = try encoder.encode(manifest)
        files["manifest.json"] = manifestJSON
        let signatureBytes = signature.flatMap { $0.isEmpty ? nil : $0 }
        if let signatureBytes {
            files["signature"] = signatureBytes
        }
        let ordered = ["pass.json", "manifest.json", "signature"].compactMap { name -> (name: String, data: Data)? in
            guard let data = files[name] else { return nil }
            return (name, data)
        }
        return PassPackage(
            files: files,
            manifestJSON: manifestJSON,
            signature: signatureBytes,
            archive: StoreZip.archive(ordered)
        )
    }

    private static func backFields(_ pass: ConferencePass) -> [PassField] {
        var fields = [
            PassField(key: "barcode", label: "CODE", value: pass.barcodePayload),
            PassField(
                key: "signing",
                label: "WALLET",
                value: "This sample is unsigned until Vince’s Pass Type ID certificate is installed."
            )
        ]
        if let address = pass.venueAddress, !address.isEmpty {
            fields.insert(PassField(key: "address", label: "ADDRESS", value: address), at: 0)
        }
        return fields
    }
}

public struct PassPackage: Hashable, Sendable {
    /// `pass.json`, `manifest.json`, and `signature` when one was supplied.
    /// The manifest hashes `pass.json` only. `manifest.json` and `signature` are not hashed.
    public var files: [String: Data]
    public var manifestJSON: Data
    public var signature: Data?
    public var archive: Data

    public var passJSON: Data { files["pass.json"] ?? Data() }

    /// True only when a signature blob was supplied. This builder never produces one.
    public var isSigned: Bool { signature?.isEmpty == false }

    public init(files: [String: Data], manifestJSON: Data, signature: Data?, archive: Data) {
        self.files = files
        self.manifestJSON = manifestJSON
        self.signature = signature
        self.archive = archive
    }
}

private struct PassDocument: Encodable {
    var formatVersion: Int
    var passTypeIdentifier: String
    var serialNumber: String
    var teamIdentifier: String
    var organizationName: String
    var description: String
    var logoText: String
    var foregroundColor: String
    var backgroundColor: String
    var labelColor: String
    var relevantDate: Date
    var eventTicket: PassEventTicket
    var barcode: PassBarcode
    var barcodes: [PassBarcode]
}

private struct PassEventTicket: Encodable {
    var primaryFields: [PassField]
    var secondaryFields: [PassField]
    var auxiliaryFields: [PassField]
    var backFields: [PassField]
}

private struct PassField: Encodable {
    var key: String
    var label: String
    var value: String
}

private struct PassBarcode: Encodable {
    var message: String
    var format: String = "PKBarcodeFormatQR"
    var messageEncoding: String = "iso-8859-1"
}

/// Store-method ZIP (no compression). Enough for a `.pkpass` once a signature exists.
enum StoreZip {
    static func archive(_ files: [(name: String, data: Data)]) -> Data {
        var local = Data()
        var central = Data()
        for file in files {
            let name = Data(file.name.utf8)
            let crc = PassArchiveChecksum.crc32(file.data)
            let size = UInt32(truncatingIfNeeded: file.data.count)
            let offset = UInt32(truncatingIfNeeded: local.count)
            local.appendLE(UInt32(0x0403_4B50))
            local.appendLE(UInt16(20))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0))
            local.appendLE(crc)
            local.appendLE(size)
            local.appendLE(size)
            local.appendLE(UInt16(name.count))
            local.appendLE(UInt16(0))
            local.append(name)
            local.append(file.data)

            central.appendLE(UInt32(0x0201_4B50))
            central.appendLE(UInt16(0x0314))
            central.appendLE(UInt16(20))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(crc)
            central.appendLE(size)
            central.appendLE(size)
            central.appendLE(UInt16(name.count))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt32(0))
            central.appendLE(offset)
            central.append(name)
        }
        var end = Data()
        let count = UInt16(files.count)
        end.appendLE(UInt32(0x0605_4B50))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(count)
        end.appendLE(count)
        end.appendLE(UInt32(truncatingIfNeeded: central.count))
        end.appendLE(UInt32(truncatingIfNeeded: local.count))
        end.appendLE(UInt16(0))
        return local + central + end
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
