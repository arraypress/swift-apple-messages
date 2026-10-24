//
//  TextRun.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A stretch of a message's text with the same styling.
public struct TextRun: Sendable, Equatable, Codable {

    /// The words in this stretch.
    public let text: String

    /// Bold, italic, underline, strikethrough — any of them.
    public let styles: [TextStyle]

    /// The animation on it — `big`, `shake`, `explode`… — or `nil`.
    public let animation: String?

    public init(text: String, styles: [TextStyle] = [], animation: String? = nil) {
        self.text = text
        self.styles = styles
        self.animation = animation
    }

    /// Whether anything is applied to it.
    public var isPlain: Bool { styles.isEmpty && animation == nil }
}
