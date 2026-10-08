//
//  MessageStore.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Messages' own database, read and never written.
//

import Foundation

/// Everything Messages has stored, read-only.
///
/// ```swift
/// let store = try MessageStore()
/// for chat in try store.chats().prefix(10) {
///     print(ChatMatching.title(chat), chat.lastMessageAt ?? .distantPast)
/// }
/// let recent = try store.messages(MessageQuery(chatID: 42, limit: 20))
/// ```
///
/// Opens `~/Library/Messages/chat.db` read-only, with no copy. There is no
/// code path here that writes to it, and there should never be one: the
/// schema is Apple's, undocumented, and the database is being written by
/// Messages and synced through iCloud while this reads. Sending goes through
/// Messages itself — see ``MessageSender``.
public final class MessageStore {

    private let database: SQLiteDatabase

    /// Where the database lives.
    public let path: String

    /// Opens the Messages database, or says why it cannot.
    public init(path: String? = nil) throws {
        let resolved = path ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db").path
        self.path = resolved
        self.database = try SQLiteDatabase(path: resolved)
    }

    // MARK: - Conversations

    /// Every conversation, most recent first, with its participants.
    public func chats() throws -> [Chat] {
        var participants: [Int64: [Handle]] = [:]
        try database.query(MessageQueries.participants) { row in
            if let address = row.text(1) { participants[row.integer(0), default: []].append(Handle(address: address)) }
        }

        var chats: [Chat] = []
        try database.query(MessageQueries.chats) { row in
            let id = row.integer(0)
            chats.append(Chat(
                id: id,
                guid: row.text(1) ?? "",
                displayName: row.text(2).flatMap { $0.isEmpty ? nil : $0 },
                participants: participants[id] ?? [],
                // 43 is a group and 45 one person: every 45 checked had
                // exactly one participant, whose address is its identifier.
                isGroup: row.integer(3) == 43,
                service: Service(stored: row.text(4)),
                lastMessageAt: StoredDate.date(row.integer(5)),
                messageCount: Int(row.integer(6))
            ))
        }
        return chats
    }

    // MARK: - Messages

    /// The messages a query matches, with their attachments and reactions.
    public func messages(_ query: MessageQuery = MessageQuery()) throws -> [Message] {
        var handleIDs: [Int64]?
        if let from = query.from {
            handleIDs = try handles().filter { AddressMatch.same(from, $0.address) }.map(\.id)
            if handleIDs?.isEmpty == true { return [] }
        }

        let (sql, values) = MessageQueries.messages(query, handleIDs: handleIDs)
        var found: [Message] = []
        let wanted = query.text.flatMap { $0.isEmpty ? nil : $0 }
        try database.query(sql, values) { row in
            guard wanted == nil || found.count < query.limit else { return }
            let message = Self.message(from: row)
            // Text only in attributedBody could not be matched in SQL; it is
            // matched here, after decoding, and only then counted.
            if let wanted, !(message.text?.localizedCaseInsensitiveContains(wanted) ?? false) { return }
            found.append(message)
        }
        return try decorate(found)
    }

    /// One message by row.
    public func message(id: Int64) throws -> Message {
        var found: Message?
        try database.query(MessageQueries.message, [.integer(id)]) { row in found = Self.message(from: row) }
        guard let found else { throw MessagesError.noSuchMessage(id) }
        return try decorate([found])[0]
    }

    /// The newest message row, for watching from.
    public func latestID() throws -> Int64 {
        var latest: Int64 = 0
        try database.query(MessageQueries.latestID) { row in latest = row.integer(0) }
        return latest
    }

    /// Every handle, by row.
    func handles() throws -> [(id: Int64, address: String)] {
        var handles: [(Int64, String)] = []
        try database.query(MessageQueries.handles) { row in
            if let address = row.text(1) { handles.append((row.integer(0), address)) }
        }
        return handles
    }

    // MARK: - Assembly

    /// A message from a row of ``MessageQueries/messageColumns``.
    static func message(from row: SQLiteDatabase.Row) -> Message {
        let isFromMe = row.integer(4) == 1
        let chat = row.integer(2)
        let text = BodyDecoding.text(column: row.text(5), body: row.data(6))
        let summary = SummaryInfo.dictionary(row.data(13))
        let balloon = row.text(17)

        var link: LinkPreview?
        if balloon == MessageKinds.linkBalloon {
            link = RichLinkDecoding.preview(row.data(18)) ?? RichLinkDecoding.firstLink(in: text)
        }

        var message = Message(
            id: row.integer(0),
            guid: row.text(1) ?? "",
            chatID: chat == 0 ? nil : chat,
            sender: isFromMe ? nil : row.text(3).map { Handle(address: $0) },
            isFromMe: isFromMe,
            text: text,
            date: StoredDate.date(row.integer(7)) ?? Date(timeIntervalSinceReferenceDate: 0),
            readAt: StoredDate.date(row.integer(8)),
            editedAt: StoredDate.date(row.integer(9)) ?? SummaryInfo.lastEdited(summary),
            service: Service(stored: row.text(10)),
            replyTo: row.text(11).flatMap { $0.isEmpty ? nil : $0 },
            subject: row.text(12).flatMap { $0.isEmpty ? nil : $0 },
            edits: SummaryInfo.edits(summary, current: text),
            isUnsent: row.integer(14) > 0 || SummaryInfo.isUnsent(summary),
            effect: MessageKinds.effect(row.text(15)),
            isAudio: row.integer(16) == 1,
            link: link,
            app: MessageKinds.app(balloon),
            event: MessageKinds.event(itemType: row.integer(19), action: row.integer(20),
                                      title: row.text(21), other: row.text(22))
        )
        // Held here until the attachments are read; ``decorate(_:)`` turns it
        // into how many are missing.
        message.missingAttachments = BodyDecoding.placeholders(column: row.text(5), body: row.data(6))
        return message
    }

    /// Messages with their attachments and standing reactions.
    ///
    /// Two queries for the whole batch rather than two per message, in
    /// chunks under SQLite's bound-parameter limit.
    private func decorate(_ messages: [Message]) throws -> [Message] {
        guard !messages.isEmpty else { return messages }
        var attachments: [Int64: [Attachment]] = [:]
        var previews: [Int64: Int] = [:]
        var events: [String: [ReactionCodes.Event]] = [:]

        for chunk in stride(from: 0, to: messages.count, by: 500).map({ Array(messages[$0..<min($0 + 500, messages.count)]) }) {
            try database.query(MessageQueries.attachments(count: chunk.count), chunk.map { .integer($0.id) }) { row in
                let path = row.text(2).map { ($0 as NSString).expandingTildeInPath }
                // The data behind a link card is not a file anybody sent — but
                // it holds a placeholder in the text, so it is counted, or the
                // card would read as a missing attachment.
                guard !MessageKinds.isPreviewPayload(path) else {
                    previews[row.integer(0), default: 0] += 1
                    return
                }
                attachments[row.integer(0), default: []].append(Attachment(
                    name: row.text(1),
                    path: path,
                    mimeType: row.text(3),
                    bytes: row.integer(4),
                    isLocal: path.map { FileManager.default.fileExists(atPath: $0) } ?? false,
                    isSticker: row.integer(5) == 1
                ))
            }
            try database.query(MessageQueries.reactions(count: chunk.count), chunk.map { .text($0.guid) }) { row in
                guard let associated = row.text(0) else { return }
                let target = ReactionCodes.target(associated)
                events[target, default: []].append(ReactionCodes.Event(
                    target: target, code: Int(row.integer(1)), emoji: row.text(2),
                    sender: row.text(3), date: row.integer(4)
                ))
            }
        }

        return messages.map { message in
            var decorated = message
            decorated.attachments = attachments[message.id] ?? []
            decorated.missingAttachments = max(
                message.missingAttachments - decorated.attachments.count - (previews[message.id] ?? 0), 0
            )
            decorated.reactions = ReactionCodes.settle(events[message.guid] ?? [])
            return decorated
        }
    }
}
