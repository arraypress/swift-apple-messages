//
//  AddressMatch.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import ContactsKit
import Foundation

/// Whether an address somebody typed is the one Messages stored.
public enum AddressMatch {

    /// Emails compare whole, ignoring case. Phone numbers compare by
    /// ContactsKit's `PhoneMatch` — the last nine digits — because Messages
    /// stores `+447700900123` and people type `07700 900123`, and neither is
    /// a suffix of the other.
    public static func same(_ typed: String, _ stored: String) -> Bool {
        if typed.contains("@") || stored.contains("@") {
            return typed.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(stored) == .orderedSame
        }
        return PhoneMatch.same(typed, stored)
    }

    /// Whether text looks like an address rather than a name.
    public static func looksLikeAddress(_ text: String) -> Bool {
        text.contains("@") || PhoneMatch.digits(text).count >= PhoneMatch.minimumDigits
    }
}
