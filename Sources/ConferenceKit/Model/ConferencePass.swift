import Foundation

/// The attendee's event ticket. Wallet signing is separate; see `PassBuilder`.
public struct ConferencePass: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var attendeeName: String
    public var conferenceName: String
    public var seatOrTicketType: String
    public var barcodePayload: String
    public var relevantDate: Date
    public var venueName: String
    public var venueAddress: String?

    public init(
        id: String,
        attendeeName: String,
        conferenceName: String,
        seatOrTicketType: String,
        barcodePayload: String,
        relevantDate: Date,
        venueName: String,
        venueAddress: String? = nil
    ) {
        self.id = id
        self.attendeeName = attendeeName
        self.conferenceName = conferenceName
        self.seatOrTicketType = seatOrTicketType
        self.barcodePayload = barcodePayload
        self.relevantDate = relevantDate
        self.venueName = venueName
        self.venueAddress = venueAddress
    }
}
