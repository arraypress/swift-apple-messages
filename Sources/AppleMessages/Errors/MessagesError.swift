//
//  MessagesError.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading or sending messages.
public enum MessagesError: Error, Equatable, Sendable, LocalizedError {

    /// Messages has never run here, or its data lives somewhere else.
    case noDatabase(String)

    /// The database is there, but this process may not read it.
    ///
    /// Almost always Full Disk Access: `~/Library/Messages` is protected, and
    /// SQLite reports the refusal as a bare "unable to open database file".
    case notPermitted(String)

    /// SQLite refused.
    case readFailed(String)

    /// No conversation matches.
    case noSuchChat(String)

    /// More than one conversation matches. Carries their identifiers.
    case ambiguousChat(String, [String])

    /// No message with that identifier.
    case noSuchMessage(Int64)

    /// Messages refused to send, or could not be asked.
    case sendFailed(String)

    /// A group chat cannot be drafted — Messages' compose link takes one
    /// address. Sending to a group needs `now`.
    case cannotDraftToGroup(String)

    /// Nothing to send.
    case emptyMessage

    /// A file to send is not there.
    case noSuchFile(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .noDatabase(let path):
            "No Messages data at \(path) — Messages may never have run on this Mac"
        case .notPermitted(let path):
            "Not allowed to read \(path) — grant Full Disk Access to your terminal in "
                + "System Settings ▸ Privacy & Security ▸ Full Disk Access"
        case .readFailed(let reason):
            "Could not read the Messages database: \(reason)"
        case .noSuchChat(let what):
            "No conversation matches \(what)"
        case .ambiguousChat(let what, let ids):
            "\(what) matches \(ids.count) conversations"
        case .noSuchMessage(let id):
            "No message with id \(id)"
        case .sendFailed(let reason):
            "Messages did not send: \(reason)"
        case .cannotDraftToGroup(let chat):
            "\(chat) is a group — a draft can only be opened to one person"
        case .emptyMessage:
            "Nothing to send"
        case .noSuchFile(let path):
            "No file at \(path)"
        }
    }
}
