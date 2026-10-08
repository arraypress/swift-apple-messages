//
//  Edit.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An earlier version of an edited message.
public struct Edit: Sendable, Equatable, Codable {

    /// When this version was current.
    public let date: Date?

    /// What it said.
    public let text: String

    /// A version from its parts.
    public init(date: Date?, text: String) {
        self.date = date
        self.text = text
    }
}
