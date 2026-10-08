//
//  ChatEvent.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Something that happened to a conversation rather than a message in it.
///
/// Stored as a row in the message table with a non-zero `item_type`.
/// Named only where the database says what it was: type 1 carries the
/// person (`other_handle`) and whether they were added or removed
/// (`group_action_type`); type 2 carries the new name (`group_title`).
/// Types 3, 4 and 5 carry neither text nor a person, and nothing beside them
/// in the database says what they were — so they are reported by their
/// code, not guessed at.
public struct ChatEvent: Sendable, Equatable, Codable {

    /// `member-added`, `member-removed`, `renamed`, or `event-<code>`.
    public let kind: String

    /// Who it concerned, for a membership change.
    public var who: Handle?

    /// The new name, for a rename.
    public let title: String?

    /// An event from its parts.
    public init(kind: String, who: Handle? = nil, title: String? = nil) {
        self.kind = kind
        self.who = who
        self.title = title
    }
}
