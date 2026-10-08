//
//  SendScripts.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The AppleScript that sends, with every value taken from `argv`.
///
/// Messages' dictionary, read from the macOS 27 SDK's app: `send` takes text
/// or a file, `to` a participant or a chat; chats are addressed by `id`, and
/// accounts carry a `service type` of SMS, iMessage or RCS.
enum SendScripts {

    /// `argv`: text, chat guid.
    static let toChat = """
        on run argv
            tell application "Messages" to send (item 1 of argv) to chat id (item 2 of argv)
        end run
        """

    /// `argv`: text, address. A new conversation, over iMessage.
    static let toAddress = """
        on run argv
            tell application "Messages"
                set target to participant (item 2 of argv) of (1st account whose service type = iMessage)
                send (item 1 of argv) to target
            end tell
        end run
        """

    /// `argv`: file path, chat guid.
    static let fileToChat = """
        on run argv
            tell application "Messages" to send (POSIX file (item 1 of argv)) to chat id (item 2 of argv)
        end run
        """
}
