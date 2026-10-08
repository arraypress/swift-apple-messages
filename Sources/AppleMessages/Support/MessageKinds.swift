//
//  MessageKinds.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Effects, iMessage apps and conversation events, out of their columns.
//

import Foundation

/// The parts of a message that are not its text.
enum MessageKinds {

    /// The bundle Messages uses for an ordinary link card.
    static let linkBalloon = "com.apple.messages.URLBalloonProvider"

    /// A send effect's name from its identifier.
    ///
    /// Mechanical, not a table: `com.apple.messages.effect.CKLasersEffect`
    /// → `lasers`, `com.apple.MobileSMS.expressivesend.impact` → `impact`.
    /// A table would have to guess the names of effects never seen; this
    /// reports each one as Apple named it.
    static func effect(_ identifier: String?) -> String? {
        guard let identifier, !identifier.isEmpty else { return nil }
        var name = identifier.split(separator: ".").last.map(String.init) ?? identifier
        if name.hasPrefix("CK") { name.removeFirst(2) }
        if name.hasSuffix("Effect") { name.removeLast(6) }
        return name.isEmpty ? identifier : name.prefix(1).lowercased() + name.dropFirst()
    }

    /// The iMessage app a balloon came from, or `nil` for a link card or
    /// none.
    ///
    /// Plugin balloons are `…MSMessageExtensionBalloonPlugin:<team>:<bundle>`
    /// — Find My's are — so the app is the last part.
    static func app(_ balloon: String?) -> String? {
        guard let balloon, !balloon.isEmpty, balloon != linkBalloon else { return nil }
        return balloon.split(separator: ":").last.map(String.init) ?? balloon
    }

    /// A conversation event, for a row with a non-zero `item_type`.
    static func event(itemType: Int64, action: Int64, title: String?, other: String?) -> ChatEvent? {
        switch itemType {
        case 0:
            return nil
        case 1:
            return ChatEvent(kind: action == 1 ? "member-removed" : "member-added",
                             who: other.map { Handle(address: $0) })
        case 2:
            return ChatEvent(kind: "renamed", title: title)
        default:
            return ChatEvent(kind: "event-\(itemType)", who: other.map { Handle(address: $0) }, title: title)
        }
    }

    /// Whether an attachment is the data behind a link card rather than a
    /// file anybody sent. These are all named `.pluginPayloadAttachment`.
    static func isPreviewPayload(_ path: String?) -> Bool {
        path?.hasSuffix(".pluginPayloadAttachment") ?? false
    }
}
