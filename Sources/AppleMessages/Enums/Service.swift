//
//  Service.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How a message or conversation travels.
///
/// Three, not two: RCS arrived in Messages on the Mac, and RCS chats are
/// stored alongside the rest. A tool that assumed "iMessage or SMS" would
/// mislabel them.
public enum Service: String, Sendable, Equatable, Codable, CaseIterable {
    case iMessage
    case sms = "SMS"
    case rcs = "RCS"
    /// Anything else the database names — kept rather than guessed.
    case other

    /// The service a database value names.
    public init(stored: String?) {
        self = Service(rawValue: stored ?? "") ?? .other
    }
}
