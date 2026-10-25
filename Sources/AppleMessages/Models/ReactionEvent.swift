//
//  ReactionEvent.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One tapback as it happened: added or taken back, by whom, on what.
///
/// ``Message/reactions`` is the settled state — what stands on a message
/// now. This is the stream that produced it, for a reader following new rows
/// as they arrive, which needs to hear "Ada laughed at that" when Ada does.
public struct ReactionEvent: Sendable, Equatable, Codable {

    /// The reaction's own row.
    public let id: Int64

    /// The reaction's own guid.
    public let guid: String

    /// Its conversation's row, when it is in one.
    public let chatID: Int64?

    /// Which one.
    public let kind: ReactionKind

    /// The emoji, for ``ReactionKind/emoji``.
    public let emoji: String?

    /// Whether this takes a reaction back rather than adds one.
    public let removes: Bool

    /// Who reacted. `nil` for you.
    public var from: Handle?

    /// Whether you reacted.
    public let isFromMe: Bool

    /// The guid of the message reacted to.
    public let targetGUID: String

    /// When.
    public let date: Date

    /// How it travelled.
    public let service: Service

    public init(id: Int64, guid: String, chatID: Int64?, kind: ReactionKind, emoji: String? = nil,
                removes: Bool = false, from: Handle? = nil, isFromMe: Bool = false, targetGUID: String,
                date: Date, service: Service = .iMessage) {
        self.id = id
        self.guid = guid
        self.chatID = chatID
        self.kind = kind
        self.emoji = emoji
        self.removes = removes
        self.from = from
        self.isFromMe = isFromMe
        self.targetGUID = targetGUID
        self.date = date
        self.service = service
    }
}
