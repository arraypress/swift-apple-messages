//
//  MessageQuery.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which messages to read.
public struct MessageQuery: Sendable, Equatable {

    /// Only this conversation.
    public var chatID: Int64?

    /// Text to find, ignoring case.
    public var text: String?

    /// Only messages from this address. Matched loosely for phone numbers —
    /// see ``AddressMatch``.
    public var from: String?

    /// Received on or after.
    public var since: Date?

    /// Received before.
    public var until: Date?

    /// Only messages after this row — what `watch` asks for.
    public var afterID: Int64?

    /// Include messages whose conversation was deleted.
    ///
    /// Off by default. Messages keeps the rows of a deleted conversation —
    /// still stored, never shown — and somebody who deleted a conversation
    /// does not expect a tool to bring it back unasked.
    public var includeDeleted: Bool

    /// Include conversation events — people added or removed, renames —
    /// beside the messages. Off by default: they are not things anybody said.
    public var includeEvents: Bool

    /// How many to return.
    public var limit: Int

    /// Newest first, the default; oldest first reads like a conversation.
    public var newestFirst: Bool

    /// A query; every filter optional.
    public init(
        chatID: Int64? = nil,
        text: String? = nil,
        from: String? = nil,
        since: Date? = nil,
        until: Date? = nil,
        afterID: Int64? = nil,
        includeDeleted: Bool = false,
        includeEvents: Bool = false,
        limit: Int = 50,
        newestFirst: Bool = true
    ) {
        self.chatID = chatID
        self.text = text
        self.from = from
        self.since = since
        self.until = until
        self.afterID = afterID
        self.includeDeleted = includeDeleted
        self.includeEvents = includeEvents
        self.limit = limit
        self.newestFirst = newestFirst
    }
}
