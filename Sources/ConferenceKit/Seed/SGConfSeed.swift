import Foundation

/// Sample SG Conf news, resources, and a ticket. Remote URLs are placeholders
/// until the real files exist. The pass still needs Vince's signing certificate.
public enum SGConfSeed {
    public static let news: [ConferenceNewsItem] = [
        ConferenceNewsItem(
            id: "sg-doors",
            title: "SG Conf doors open at 8:30",
            body: "Alliance Française de Singapour. Coffee is in the lobby, and Newton is the closest MRT.",
            publishedAt: date("2027-01-18T02:00:00Z"),
            linkURL: URL(string: "https://iosconf.sg/"),
            imageName: "megaphone.fill",
            isPinned: true,
            announces: true
        ),
        ConferenceNewsItem(
            id: "sg-workshops",
            title: "Wednesday is workshop day",
            body: "Workshops run all day Wednesday. Talks are Thursday and Friday at Alliance Française.",
            publishedAt: date("2027-01-19T04:00:00Z"),
            linkURL: URL(string: "https://iosconf.sg/"),
            imageName: "hammer.fill",
            isPinned: false,
            announces: false
        ),
        ConferenceNewsItem(
            id: "sg-slides",
            title: "Slide uploads are open",
            body: "Speakers can send PDFs ahead of the talk. Attendees will find them under Resources.",
            publishedAt: date("2027-01-20T01:30:00Z"),
            isPinned: false,
            announces: false
        )
    ]

    public static let resources: [ConferenceResource] = [
        ConferenceResource(
            id: "sg-opening-slides",
            title: "Opening keynote slides",
            kind: .pdf,
            remoteURL: URL(string: "https://iosconf.sg/resources/opening-keynote.pdf")!,
            localFilename: "opening-keynote.pdf",
            fileSizeBytes: 2_400_000,
            category: "slides"
        ),
        ConferenceResource(
            id: "sg-venue-map",
            title: "Alliance Française venue map",
            kind: .pdf,
            remoteURL: URL(string: "https://iosconf.sg/resources/venue-map.pdf")!,
            localFilename: "venue-map.pdf",
            fileSizeBytes: 180_000,
            category: "map"
        ),
        ConferenceResource(
            id: "sg-sponsor-kit",
            title: "Sponsor prospectus",
            kind: .link,
            remoteURL: URL(string: "https://iosconf.sg/sponsors")!,
            category: "sponsor"
        )
    ]

    public static let pass = ConferencePass(
        id: "sg-2027-sample",
        attendeeName: "Alex Tan",
        conferenceName: "SG Conf",
        seatOrTicketType: "General Admission",
        barcodePayload: "SGCONF-2027-GA-ALEX-TAN",
        relevantDate: date("2027-01-21T01:00:00Z"),
        venueName: "Alliance Française de Singapour",
        venueAddress: "1 Sarkies Road, Singapore"
    )

    private static func date(_ raw: String) -> Date {
        if let date = ConferenceLoader.parseISO8601(raw) { return date }
        preconditionFailure("SG Conf seed date \(raw) is not ISO-8601.")
    }
}
