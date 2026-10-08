//
//  MessageQueries.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  The SQL the database is read with. Values are always bound.
//

import Foundation

/// Queries against `chat.db`.
///
/// Written against the schema on macOS 27, reading only columns whose
/// meaning was checked against a live database: `message`, `chat`,
/// `handle`, `attachment` and the three join tables.
enum MessageQueries {

    /// Every conversation with its newest date and message count.
    ///
    /// Counts and dates leave out reactions (`associated_message_type`) and
    /// group events — renames, people joining (`item_type`) — which are rows
    /// in the same table and not messages anybody wrote.
    static let chats = """
        select c.ROWID, c.guid, c.display_name, c.style, c.service_name,
               max(m.date), count(m.ROWID)
        from chat c
        left join chat_message_join j on j.chat_id = c.ROWID
        left join message m on m.ROWID = j.message_id
                            and m.associated_message_type = 0 and m.item_type = 0
        group by c.ROWID
        order by max(m.date) desc
        """

    /// Every participant of every chat: chat row, address.
    static let participants = """
        select j.chat_id, h.id from chat_handle_join j join handle h on h.ROWID = j.handle_id
        order by j.chat_id, h.ROWID
        """

    /// Every handle: row, address.
    static let handles = "select ROWID, id from handle"

    /// The columns ``message(from:)`` reads, in order.
    static let messageColumns = """
        m.ROWID, m.guid, j.chat_id, h.id, m.is_from_me, m.text, m.attributedBody,
        m.date, m.date_read, m.date_edited, m.service, m.thread_originator_guid,
        m.subject, m.message_summary_info, m.date_retracted, m.expressive_send_style_id,
        m.is_audio_message, m.balloon_bundle_id, m.payload_data,
        m.item_type, m.group_action_type, m.group_title, oh.id,
        m.date_delivered, m.is_delivered, m.error
        """

    /// The joins every message query uses.
    static let messageJoins = """
        from message m
        left join chat_message_join j on j.message_id = m.ROWID
        left join handle h on h.ROWID = m.handle_id
        left join handle oh on oh.ROWID = m.other_handle
        """

    /// Messages for a query.
    ///
    /// - Parameters:
    ///   - handleIDs: The handle rows `query.from` resolved to.
    ///   - textFilter: When the query has text, the SQL narrows to messages
    ///     whose `text` matches OR whose text is only in `attributedBody` —
    ///     those cannot be matched in SQL, so they are decoded and checked by
    ///     the caller, and the limit is applied after that.
    static func messages(_ query: MessageQuery, handleIDs: [Int64]?) -> (String, [SQLiteValue]) {
        var conditions = ["m.associated_message_type = 0"]
        if !query.includeEvents { conditions.append("m.item_type = 0") }
        var values: [SQLiteValue] = []

        if !query.includeDeleted { conditions.append("j.chat_id is not null") }
        if let chat = query.chatID {
            conditions.append("j.chat_id = ?")
            values.append(.integer(chat))
        }
        if let fromMe = query.fromMe {
            conditions.append("m.is_from_me = ?")
            values.append(.integer(fromMe ? 1 : 0))
        }
        if let since = query.since {
            conditions.append("m.date >= ?")
            values.append(.integer(StoredDate.stored(since)))
        }
        if let until = query.until {
            conditions.append("m.date < ?")
            values.append(.integer(StoredDate.stored(until)))
        }
        if let after = query.afterID {
            conditions.append("m.ROWID > ?")
            values.append(.integer(after))
        }
        if let handleIDs {
            conditions.append("m.is_from_me = 0")
            conditions.append("m.handle_id in (\(handleIDs.map { _ in "?" }.joined(separator: ",")))")
            values.append(contentsOf: handleIDs.map { .integer($0) })
        }
        if let text = query.text, !text.isEmpty {
            conditions.append("(m.text like ? or ((m.text is null or m.text = '') and m.attributedBody is not null))")
            values.append(.text("%\(text)%"))
        }

        var sql = """
            select \(messageColumns) \(messageJoins)
            where \(conditions.joined(separator: " and "))
            order by m.date \(query.newestFirst ? "desc" : "asc")
            """
        if query.text == nil || query.text!.isEmpty {
            sql += " limit ?"
            values.append(.integer(Int64(query.limit)))
        }
        return (sql, values)
    }

    /// One message by row.
    static let message = "select \(messageColumns) \(messageJoins) where m.ROWID = ?"

    /// Reaction rows pointing at any of a set of guids. One `?` per guid.
    static func reactions(count: Int) -> String {
        """
        select r.associated_message_guid, r.associated_message_type, r.associated_message_emoji,
               case when r.is_from_me = 1 then null else h.id end, r.date
        from message r
        left join handle h on h.ROWID = r.handle_id
        where r.associated_message_type between 2000 and 3999
          and (case when r.associated_message_guid like 'p:%/%'
                    then substr(r.associated_message_guid, instr(r.associated_message_guid, '/') + 1)
                    when r.associated_message_guid like 'bp:%'
                    then substr(r.associated_message_guid, 4)
                    else r.associated_message_guid end)
              in (\(Array(repeating: "?", count: count).joined(separator: ",")))
        """
    }

    /// Attachments of any of a set of messages. One `?` per message.
    static func attachments(count: Int) -> String {
        """
        select j.message_id, a.transfer_name, a.filename, a.mime_type, a.total_bytes, a.is_sticker
        from message_attachment_join j join attachment a on a.ROWID = j.attachment_id
        where j.message_id in (\(Array(repeating: "?", count: count).joined(separator: ",")))
        order by j.message_id, a.ROWID
        """
    }

    /// The newest message row — where `watch` starts.
    static let latestID = "select coalesce(max(ROWID), 0) from message"
}
