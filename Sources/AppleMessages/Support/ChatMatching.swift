//
//  ChatMatching.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which conversation somebody meant.
public enum ChatMatching {

    /// The chats a query names, best match only.
    ///
    /// In order, first rule that finds anything wins: the row id; the guid;
    /// a group's name exactly; a participant's address; a participant's name
    /// exactly; a group or participant name containing the text. Ignoring
    /// case. So "Ada" finds the one-to-one with Ada before every group she is
    /// in — and two Adas is two answers, which the caller is told.
    public static func select(_ query: String, from chats: [Chat]) -> [Chat] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return [] }
        if let id = Int64(wanted), let byID = chats.first(where: { $0.id == id }) { return [byID] }

        func named(_ name: String?) -> Bool {
            name?.compare(wanted, options: .caseInsensitive) == .orderedSame
        }
        func contains(_ name: String?) -> Bool {
            name?.range(of: wanted, options: .caseInsensitive) != nil
        }

        let rules: [(Chat) -> Bool] = [
            { $0.guid == wanted },
            { named($0.displayName) },
            { chat in AddressMatch.looksLikeAddress(wanted)
                && !chat.isGroup && chat.participants.contains { AddressMatch.same(wanted, $0.address) } },
            { chat in !chat.isGroup && chat.participants.contains { named($0.name) } },
            { chat in contains(chat.displayName) || chat.participants.contains { contains($0.name) } },
        ]
        for rule in rules {
            let found = chats.filter(rule)
            if !found.isEmpty { return found }
        }
        return []
    }

    /// What to call a chat: its name, or who is in it.
    public static func title(_ chat: Chat) -> String {
        if let name = chat.displayName, !name.isEmpty { return name }
        let people = chat.participants.map { $0.name ?? $0.address }
        guard !people.isEmpty else { return chat.guid }
        return people.count <= 3 ? people.joined(separator: ", ")
            : people.prefix(3).joined(separator: ", ") + " +\(people.count - 3)"
    }
}
