//
//  ReactionCodes.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Tapbacks, as the database stores them, and as they stand.
//

import Foundation

/// Reading and settling tapbacks.
public enum ReactionCodes {

    /// One stored reaction row.
    struct Event: Equatable {
        let target: String
        let code: Int
        let emoji: String?
        let sender: String?
        let date: Int64
    }

    /// The kind a code names, and whether it takes one back.
    ///
    /// 2000–2006 add: love, like, dislike, laugh, emphasize, question, emoji.
    /// 3000–3006 remove the same. 2006 is the newer any-emoji reaction, its
    /// emoji in its own column, `associated_message_emoji`.
    public static func kind(_ code: Int) -> (kind: ReactionKind, removes: Bool)? {
        let removes = code >= 3000
        let base = removes ? code - 1000 : code
        let kinds: [ReactionKind] = [.love, .like, .dislike, .laugh, .emphasize, .question, .emoji]
        guard (2000...2006).contains(base) else { return nil }
        return (kinds[base - 2000], removes)
    }

    /// The guid a reaction points at.
    ///
    /// Stored as `p:<part>/<guid>` — the part of a multi-part message — or
    /// `bp:<guid>`. Both forms are in current databases.
    public static func target(_ associated: String) -> String {
        if associated.hasPrefix("p:"), let slash = associated.firstIndex(of: "/") {
            return String(associated[associated.index(after: slash)...])
        }
        if associated.hasPrefix("bp:") { return String(associated.dropFirst(3)) }
        return associated
    }

    /// The reactions that stand once every add and remove is applied, in
    /// date order.
    ///
    /// Keyed by who reacted and with what, so a laugh taken back removes
    /// that person's laugh and nobody else's.
    static func settle(_ events: [Event]) -> [Reaction] {
        var standing: [String: Reaction] = [:]
        var order: [String] = []
        for event in events.sorted(by: { $0.date < $1.date }) {
            guard let (kind, removes) = kind(event.code) else { continue }
            let key = "\(event.sender ?? "me")|\(kind.rawValue)|\(event.emoji ?? "")"
            if removes {
                standing[key] = nil
            } else {
                if standing[key] == nil { order.append(key) }
                standing[key] = Reaction(kind: kind, emoji: event.emoji, from: event.sender.map { Handle(address: $0) })
            }
        }
        return order.compactMap { standing[$0] }
    }
}
