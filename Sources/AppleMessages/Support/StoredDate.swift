//
//  StoredDate.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Messages' dates.
///
/// Counted from 1 January 2001, Apple's reference date, in NANOSECONDS on
/// current macOS. Databases from before High Sierra counted seconds, and a
/// nanosecond reading of a seconds value lands in January 2001; so a value
/// too small to be nanoseconds is read as seconds.
enum StoredDate {

    /// Below this, a stored value is seconds: 10^11 nanoseconds is under two
    /// minutes past the reference date, and 10^11 seconds is 3,000 years on.
    static let secondsThreshold: Int64 = 100_000_000_000

    /// A stored value as a date, or `nil` for 0 — Messages' "never".
    static func date(_ stored: Int64) -> Date? {
        guard stored > 0 else { return nil }
        let seconds = stored < secondsThreshold ? Double(stored) : Double(stored) / 1_000_000_000
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// A date as the nanosecond value queries compare against.
    static func stored(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSinceReferenceDate * 1_000_000_000)
    }
}
