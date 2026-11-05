import Foundation
#if canImport(Contacts) && !os(tvOS)
@preconcurrency import Contacts

/// Builds a contact from the public projection. The note field is omitted:
/// writing `CNContact.note` needs an entitlement this kit does not claim.
/// The vCard still carries the bio in `NOTE` for apps that import the file.
public enum AttendeeContacts {
    public static func makeContact(_ attendee: Attendee) -> CNMutableContact {
        let visible = attendee.hidingPrivateContactFields()
        let contact = CNMutableContact()
        let parts = visible.displayName.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.count >= 2 {
            contact.givenName = parts.dropLast().joined(separator: " ")
            contact.familyName = parts[parts.count - 1]
        } else {
            contact.givenName = visible.displayName
        }
        contact.organizationName = visible.company ?? ""
        contact.jobTitle = visible.role ?? ""
        if let email = visible.email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = visible.phone, !phone.isEmpty {
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))
            ]
        }
        contact.urlAddresses = visible.social.map {
            CNLabeledValue(label: $0.platform.label, value: $0.url.absoluteString as NSString)
        }
        return contact
    }
}
#endif
