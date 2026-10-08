//
//  Reaction.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A tapback on a message.
public struct Reaction: Sendable, Equatable, Codable {

    /// Which one.
    public let kind: ReactionKind

    /// The emoji, for ``ReactionKind/emoji``.
    public let emoji: String?

    /// Who reacted. `nil` for you.
    public var from: Handle?

    /// A reaction from its parts.
    public init(kind: ReactionKind, emoji: String? = nil, from: Handle? = nil) {
        self.kind = kind
        self.emoji = emoji
        self.from = from
    }
}
