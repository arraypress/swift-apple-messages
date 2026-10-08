//
//  DraftLink.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The `sms:` link that opens a filled-in draft.
enum DraftLink {

    /// `sms:+447700900123&body=Hello%20there`.
    ///
    /// The body is percent-encoded with everything outside unreserved
    /// characters escaped — `&` and `=` included, which `.urlQueryAllowed`
    /// leaves alone and which would cut the body short at the first
    /// ampersand.
    static func url(to address: String, body: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("&"), !trimmed.contains("?") else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "sms:\(trimmed.replacingOccurrences(of: " ", with: ""))&body=\(encoded)")
    }
}
