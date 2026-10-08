//
//  SummaryInfo.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Edit history and unsending, out of `message_summary_info`.
//

import Foundation

/// Reading `message_summary_info`.
///
/// A binary property list on nearly every row, keyed by short codes:
///
/// | key | holds | checked |
/// |---|---|---|
/// | `ec` | every version, by part: `[{d: date, t: archived text}]` | yes |
/// | `ep` | the parts that were edited | yes |
/// | `rp` | the parts that were unsent | yes |
///
/// **Neither date column can be trusted for this.** Most messages whose `ec`
/// held genuinely different earlier versions had no `date_edited`, and the
/// unsent messages checked — `rp` present, text and body gone — all had a
/// `date_retracted` of 0. The summary is what records both; the columns only
/// sometimes agree.
///
/// `ec`'s last entry is usually the CURRENT text; it is dropped so
/// ``edits(_:current:)`` returns only what the message used to say.
enum SummaryInfo {

    /// The plist, or `nil` for a blob that is not one.
    static func dictionary(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    /// Earlier versions of an edited message, oldest first — the current
    /// text left out.
    static func edits(_ summary: [String: Any]?, current: String?) -> [Edit] {
        guard let parts = summary?["ec"] as? [String: Any] else { return [] }
        var edits: [Edit] = []
        for key in parts.keys.sorted() {
            for entry in (parts[key] as? [[String: Any]]) ?? [] {
                guard let archived = entry["t"] as? Data,
                      let text = BodyDecoding.decode(archived).flatMap(BodyDecoding.clean) else { continue }
                let stamp = (entry["d"] as? NSNumber)?.int64Value
                edits.append(Edit(date: stamp.flatMap(StoredDate.date), text: text))
            }
        }
        edits.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        if let current, edits.last?.text == current { edits.removeLast() }
        return edits
    }

    /// When the message was last edited: the newest version's date.
    static func lastEdited(_ summary: [String: Any]?) -> Date? {
        guard let parts = summary?["ec"] as? [String: Any] else { return nil }
        return parts.values
            .flatMap { ($0 as? [[String: Any]]) ?? [] }
            .compactMap { ($0["d"] as? NSNumber)?.int64Value }
            .max()
            .flatMap(StoredDate.date)
    }

    /// Whether any part was unsent.
    static func isUnsent(_ summary: [String: Any]?) -> Bool {
        guard let parts = summary?["rp"] as? [Any] else { return false }
        return !parts.isEmpty
    }
}
