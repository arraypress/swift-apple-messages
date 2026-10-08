//
//  Chat.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A conversation, as the Messages sidebar shows it.
public struct Chat: Sendable, Equatable, Codable, Identifiable {

    /// The database row — what every verb takes back.
    public let id: Int64

    /// Messages' own identifier: `any;-;+447700900123`, `any;+;chat8…`.
    ///
    /// Sent to verbatim, never built: on macOS 27 chat identifiers begin
    /// `any;`, where older write-ups — and tools built from them — assemble
    /// `iMessage;-;…`, which matches nothing.
    public let guid: String

    /// The group's name, when somebody gave it one. A group without one is
    /// called by who is in it; see ``ChatMatching/title(_:)``.
    public let displayName: String?

    /// Who else is in it.
    public var participants: [Handle]

    /// Whether it is a group rather than one person.
    public let isGroup: Bool

    /// How it travels.
    public let service: Service

    /// When the last message was sent or received.
    public let lastMessageAt: Date?

    /// How many messages it holds, reactions excluded.
    public let messageCount: Int

    /// A chat from its parts.
    public init(
        id: Int64,
        guid: String,
        displayName: String? = nil,
        participants: [Handle] = [],
        isGroup: Bool = false,
        service: Service = .iMessage,
        lastMessageAt: Date? = nil,
        messageCount: Int = 0
    ) {
        self.id = id
        self.guid = guid
        self.displayName = displayName
        self.participants = participants
        self.isGroup = isGroup
        self.service = service
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
    }
}
