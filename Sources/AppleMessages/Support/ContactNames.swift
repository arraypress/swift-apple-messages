//
//  ContactNames.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import ContactsKit
import Foundation

/// Names for addresses, from the address book.
///
/// The Messages database holds no names — only `+447700900123`. Names come
/// from Contacts, and this is the join: built once from the people a caller
/// read (needing Contacts permission, which is the caller's to have), then
/// applied to chats and messages without touching either store again.
public struct ContactNames: Sendable {

    private let people: [(name: String, phones: [String], emails: [String])]

    /// A lookup over these people.
    public init(_ people: [Person]) {
        self.people = people.compactMap { person in
            let name = person.displayName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return (name, person.phoneNumbers.map(\.value), person.emailAddresses.map(\.value))
        }
    }

    /// The name for an address, if a contact has it.
    public func name(for address: String) -> String? {
        let isEmail = address.contains("@")
        return people.first { person in
            isEmail
                ? person.emails.contains { AddressMatch.same($0, address) }
                : person.phones.contains { PhoneMatch.same($0, address) }
        }?.name
    }

    /// A handle with its name filled in.
    public func named(_ handle: Handle) -> Handle {
        Handle(address: handle.address, name: handle.name ?? name(for: handle.address))
    }
}
