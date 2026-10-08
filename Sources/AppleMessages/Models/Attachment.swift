//
//  Attachment.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A file sent or received with a message.
public struct Attachment: Sendable, Equatable, Codable {

    /// The name it was sent with: `IMG_2041.HEIC`.
    public let name: String?

    /// Where it is on this Mac, `~` expanded.
    public let path: String?

    /// `image/heic`, when Messages recorded one.
    public let mimeType: String?

    /// Its size in bytes.
    public let bytes: Int64

    /// Whether the file is on this Mac. A record can outlive its file once
    /// Messages has offloaded it to iCloud.
    public let isLocal: Bool

    /// Whether it is a sticker.
    public let isSticker: Bool

    /// An attachment from its parts.
    public init(name: String?, path: String?, mimeType: String?, bytes: Int64, isLocal: Bool, isSticker: Bool = false) {
        self.name = name
        self.path = path
        self.mimeType = mimeType
        self.bytes = bytes
        self.isLocal = isLocal
        self.isSticker = isSticker
    }
}
