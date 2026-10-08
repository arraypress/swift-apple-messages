//
//  Handle.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Somebody on the other end: a phone number or an email address.
public struct Handle: Sendable, Equatable, Hashable, Codable {

    /// The address as Messages stores it: `+447700900123`, `ada@example.com`.
    public let address: String

    /// Their name, when a caller has supplied one — from Contacts, usually.
    /// The database itself holds no names.
    public var name: String?

    /// A handle from its parts.
    public init(address: String, name: String? = nil) {
        self.address = address
        self.name = name
    }
}
