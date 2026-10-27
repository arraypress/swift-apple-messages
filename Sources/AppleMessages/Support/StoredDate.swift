//
//  StoredDate.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SQLiteReader

/// Messages' dates.
///
/// Counted from 1 January 2001, Apple's reference date, in NANOSECONDS on
/// current macOS. Databases from before High Sierra counted seconds, and a
/// nanosecond reading of a seconds value lands in January 2001; so a value
/// too small to be nanoseconds is read as seconds — below 10^11, the rule
/// swift-sqlite-reader's `AppleTime` applies (10^11 nanoseconds is under two
/// minutes past the reference date, and 10^11 seconds is 3,000 years on).
enum StoredDate {

    /// A stored value as a date, or `nil` for 0 — Messages' "never".
    static func date(_ stored: Int64) -> Date? {
        AppleTime.date(Double(stored))
    }

    /// A date as the nanosecond value queries compare against.
    static func stored(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSinceReferenceDate * 1_000_000_000)
    }
}
