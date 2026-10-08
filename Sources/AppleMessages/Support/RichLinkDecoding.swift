//
//  RichLinkDecoding.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A link preview out of `payload_data`.
///
/// Nearly every preview decodes this way, with a URL and usually a title.
/// The exceptions are placeholders whose archive holds a `RichLink` and
/// nothing else — no metadata to read — and for those the link is taken from
/// the message's own text.
enum RichLinkDecoding {

    /// Private classes in preview archives, replaced rather than read.
    static let substituted = [
        "RichLinkImageAttachmentSubstitute",
        "RichLinkVideoAttachmentSubstitute",
        "RichLinkAudioAttachmentSubstitute",
    ]

    /// The preview, or `nil` for a payload that is not one.
    static func preview(_ payload: Data?) -> LinkPreview? {
        guard let payload, let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: payload) else { return nil }
        // Not secure coding: the root class is private, and the shim stands
        // in for it. The payload is Messages' own, read on this Mac.
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(RichLinkShim.self, forClassName: "RichLink")
        for name in substituted { unarchiver.setClass(ArchiveSubstitute.self, forClassName: name) }
        defer { unarchiver.finishDecoding() }

        guard let metadata = (unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? RichLinkShim)?.metadata,
              let url = metadata.url ?? metadata.originalURL else { return nil }
        return LinkPreview(url: url.absoluteString, title: metadata.title.flatMap { $0.isEmpty ? nil : $0 })
    }

    /// The first link in a message's text — for the placeholder previews
    /// that carry no metadata.
    static func firstLink(in text: String?) -> LinkPreview? {
        guard let text, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let url = match.url else { return nil }
        return LinkPreview(url: url.absoluteString)
    }
}
