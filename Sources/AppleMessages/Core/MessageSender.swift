//
//  MessageSender.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  The only way this library changes anything: by asking Messages to.
//
//  TWO ROADS, AND THE SAFER ONE IS THE DEFAULT. A draft opens Messages with
//  the text filled in and sends nothing — somebody reads it and presses
//  Send. Sending now goes through Messages' AppleScript `send`, and a message
//  that has reached somebody's phone cannot be taken back. The caller chooses;
//  this library never chooses for them.
//

import AppKit
import Foundation

/// Drafting and sending through Messages.app.
public enum MessageSender {

    // MARK: - Draft

    /// Opens Messages with a message to one address filled in, NOT sent.
    ///
    /// Measured: `sms:<address>&body=<text>` opened a compose to that
    /// address with the text in the field, and nothing was sent. The link
    /// takes one address, so a group cannot be drafted to.
    public static func draft(_ text: String, to address: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MessagesError.emptyMessage }
        guard let url = DraftLink.url(to: address, body: text) else {
            throw MessagesError.sendFailed("\(address) cannot be put in a Messages link")
        }
        guard NSWorkspace.shared.open(url) else { throw MessagesError.sendFailed("Messages would not open the draft") }
    }

    // MARK: - Send

    /// Sends text to an existing conversation, by its guid.
    ///
    /// The guid is the database's own (`any;-;+447700900123`), passed
    /// verbatim — so the reply goes to the same conversation, over the same
    /// service, that the person is already using.
    ///
    /// - Parameter runner: What runs the script — see ``AppleScriptRunner``.
    public static func send(_ text: String, toChat guid: String, runner: AppleScriptRunner) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MessagesError.emptyMessage }
        _ = try runner(SendScripts.toChat, [text, guid])
    }

    /// Sends text to an address with no conversation yet, over iMessage.
    public static func send(_ text: String, toAddress address: String, runner: AppleScriptRunner) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MessagesError.emptyMessage }
        _ = try runner(SendScripts.toAddress, [text, address])
    }

    /// Sends a file to an existing conversation.
    ///
    /// **The file is staged first.** Messages is sandboxed: handed a path in
    /// Downloads or on the Desktop, its AppleScript `send` succeeded, the
    /// message was even marked delivered — and it carried no attachment at
    /// all, an empty bubble. Messages reads its own attachments folder, so a
    /// copy goes there (see ``AttachmentStaging``) and that copy is sent. The
    /// original is not touched.
    ///
    /// - Returns: The name the attachment will carry, for a caller checking
    ///   that it really arrived.
    @discardableResult
    public static func send(file: URL, toChat guid: String, runner: AppleScriptRunner) throws -> String {
        guard FileManager.default.fileExists(atPath: file.path) else { throw MessagesError.noSuchFile(file.path) }
        let staged = try AttachmentStaging.stage(file)
        _ = try runner(SendScripts.fileToChat, [staged.path, guid])
        return staged.lastPathComponent
    }
}

/// Runs an AppleScript, its values as `argv`, and returns what it printed.
///
/// Injected rather than built in (0.2): running osascript well — a hard
/// timeout that kills a script stuck on a dialog, both pipes read together,
/// a `--` so a message starting `-e` stays a message, and an answer to
/// "did it send before it failed?" — is the caller's runner's job, and the
/// fleet's lives in CLIKit as `OSAScript.run`:
///
/// ```swift
/// try MessageSender.send(text, toChat: guid) { try OSAScript.run($0, arguments: $1) }
/// ```
///
/// Values go in as `arguments`, never pasted into the script's source: a
/// message containing `"` or `\` or `end tell` is text to send, and an
/// escaping mistake would make it code. Whatever the runner throws reaches
/// the caller unchanged.
public typealias AppleScriptRunner = @Sendable (_ source: String, _ arguments: [String]) throws -> String
