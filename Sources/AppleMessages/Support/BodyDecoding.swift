//
//  BodyDecoding.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  A message's text, out of whichever column it is in.
//

import Foundation

/// Reading a message's text.
///
/// Since Ventura most messages carry their text twice — the `text` column and
/// `attributedBody`, an `NSAttributedString` archived in Apple's old
/// typedstream format — and some carry it ONLY in `attributedBody`. Tools
/// that read `text` lose those; most that read `attributedBody` scan the
/// bytes for an `NSString` marker and slice, which is a guess at a format.
///
/// It is not a guess here. Foundation still ships `NSUnarchiver`, which reads
/// typedstream because it is the format's own reader. Checked against a full
/// database it decoded every body without a failure, in well under a second;
/// where both columns had text they agreed, apart from the U+FFFC marks
/// where attachments sit — so the column is preferred, and the body is the
/// fallback.
enum BodyDecoding {

    /// The object-replacement character marking where an attachment sits.
    static let attachmentMark: Character = "\u{FFFC}"

    /// What an iMessage app's card (Find My, measured) carries as its whole
    /// text: a replacement character with a "breadcrumb" attribute — not
    /// words, so never shown as `�`.
    static let appMark: Character = "\u{FFFD}"

    /// The text to show: the `text` column when it has any, else the
    /// decoded body, with attachment marks removed. `nil` when nothing is
    /// left — a message that is only a photo.
    static func text(column: String?, body: Data?) -> String? {
        if let column, let cleaned = clean(column) { return cleaned }
        guard let body, let decoded = decode(body) else { return nil }
        return clean(decoded)
    }

    /// An archived `attributedBody`'s plain string.
    ///
    /// `NSUnarchiver` is deprecated for WRITING — keyed archiving replaced
    /// it in 10.13 — but it is the only reader of this format Apple ships,
    /// and the format is still what Messages writes.
    static func decode(_ body: Data) -> String? {
        (NSUnarchiver.unarchiveObject(with: body) as? NSAttributedString)?.string
    }

    /// How many attachment marks the message's text carries — how many
    /// attachments it was sent with.
    static func placeholders(column: String?, body: Data?) -> Int {
        let source = column.flatMap { $0.isEmpty ? nil : $0 } ?? body.flatMap(decode) ?? ""
        return source.filter { $0 == attachmentMark }.count
    }

    /// Text without attachment marks, or `nil` when that leaves nothing.
    static func clean(_ text: String) -> String? {
        let cleaned = strip(text)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cleaned
    }

    /// Text without attachment or app marks.
    static func strip(_ text: String) -> String {
        text.filter { $0 != attachmentMark && $0 != appMark }
    }
}
