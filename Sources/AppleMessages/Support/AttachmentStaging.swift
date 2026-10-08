//
//  AttachmentStaging.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Copying a file where Messages can read it before it is sent.
///
/// Messages reads files from its own `~/Library/Messages/Attachments`
/// folder; from elsewhere — Downloads, the Desktop — its sandbox can leave
/// it with nothing to read, and the send goes out empty. steipete's imsg
/// stages under that folder for the same reason. Copies go in a folder of
/// their own, never among Messages' files, one per send so two files with
/// one name do not collide.
enum AttachmentStaging {

    /// Where staged copies live.
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/Attachments/AppleMessages", isDirectory: true)
    }

    /// How long a staged copy is kept.
    ///
    /// Messages uploads after the send call returns, so a copy cannot be
    /// deleted straight away; a day is long past any upload, and old copies
    /// are cleared on the next send.
    static let keep: TimeInterval = 24 * 60 * 60

    /// Copies a file into the staging folder, keeping its name.
    static func stage(_ file: URL) throws -> URL {
        prune()
        let send = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: send, withIntermediateDirectories: true)
            let copy = send.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.copyItem(at: file, to: copy)
            return copy
        } catch {
            throw MessagesError.sendFailed("could not stage \(file.lastPathComponent) for Messages: \(error.localizedDescription)")
        }
    }

    /// Removes staged copies older than ``keep``.
    static func prune(now: Date = Date()) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for entry in entries {
            let created = (try? entry.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? now
            if now.timeIntervalSince(created) > keep { try? fm.removeItem(at: entry) }
        }
    }
}
