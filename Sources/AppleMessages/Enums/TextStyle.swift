//
//  TextStyle.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

/// A text style a sender put on part of a message (iOS 18 / macOS 15 and later).
public enum TextStyle: String, Sendable, Codable, CaseIterable {
    case bold
    case italic
    case underline
    case strikethrough
}
