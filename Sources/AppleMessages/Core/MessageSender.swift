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
    public static func send(_ text: String, toChat guid: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MessagesError.emptyMessage }
        try run(SendScripts.toChat, [text, guid])
    }

    /// Sends text to an address with no conversation yet, over iMessage.
    public static func send(_ text: String, toAddress address: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MessagesError.emptyMessage }
        try run(SendScripts.toAddress, [text, address])
    }

    /// Sends a file to an existing conversation.
    public static func send(file: URL, toChat guid: String) throws {
        guard FileManager.default.fileExists(atPath: file.path) else { throw MessagesError.noSuchFile(file.path) }
        try run(SendScripts.fileToChat, [file.path, guid])
    }

    /// Runs a send script with its values as arguments.
    ///
    /// Values go in as `argv`, never pasted into the script's source: a
    /// message containing `"` or `\` or `end tell` is text to send, and an
    /// escaping mistake would make it code.
    private static func run(_ script: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script] + arguments
        let error = Pipe()
        process.standardError = error
        process.standardOutput = FileHandle.nullDevice
        do { try process.run() } catch { throw MessagesError.sendFailed(error.localizedDescription) }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw MessagesError.sendFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
