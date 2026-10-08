//
//  LinkPreview.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The card Messages shows for a link.
public struct LinkPreview: Sendable, Equatable, Codable {

    /// Where it goes.
    public let url: String

    /// The page's title, when the preview carried one.
    public let title: String?

    /// A preview from its parts.
    public init(url: String, title: String? = nil) {
        self.url = url
        self.title = title
    }
}
