//
//  RichLinkShim.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation
import LinkPresentation

/// Stands in for Messages' private `RichLink` class while a link preview is
/// unarchived.
///
/// The archive's root is a `RichLink` holding `richLinkMetadata` — an
/// `LPLinkMetadata`, LinkPresentation's public, `NSSecureCoding` type with
/// `URL` and `title`. Only the wrapper is private; this replaces it with a
/// class that reads that one key.
final class RichLinkShim: NSObject, NSCoding {

    /// The metadata inside.
    let metadata: LPLinkMetadata?

    init?(coder: NSCoder) {
        metadata = coder.decodeObject(forKey: "richLinkMetadata") as? LPLinkMetadata
    }

    func encode(with coder: NSCoder) {}
}
