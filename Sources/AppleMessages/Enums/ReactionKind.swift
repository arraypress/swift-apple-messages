//
//  ReactionKind.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A tapback.
///
/// Stored as a message of its own, with `associated_message_type` 2000–2006
/// to add one and 3000–3006 to take it back. They live in the same table as
/// messages, so a reader that does not set them apart lists every tapback as
/// a message of its own between the real conversation.
public enum ReactionKind: String, Sendable, Equatable, Codable, CaseIterable {
    case love
    case like
    case dislike
    case laugh
    case emphasize
    case question
    /// Any emoji, carried in ``Reaction/emoji``.
    case emoji
}
