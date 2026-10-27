//
//  SQLiteRow+Columns.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  A row's columns read the way this library always has: an integer column
//  is 0 when NULL (SQLite's own column_int64 rule), and an empty blob is no
//  blob at all.
//

import Foundation
import SQLiteReader

extension SQLiteRow {

    /// An integer column, 0 for NULL; a real is truncated.
    func integer(_ index: Int32) -> Int64 {
        switch self[Int(index)] {
        case .integer(let number): number
        case .real(let number): Int64(exactly: number.rounded(.towardZero)) ?? 0
        case .text(let text): Int64(text.trimmingCharacters(in: .whitespaces)) ?? 0
        case .null, .blob: 0
        }
    }

    /// A text column, or `nil` for NULL.
    func text(_ index: Int32) -> String? {
        let value = self[Int(index)]
        if case .blob(let bytes) = value { return String(decoding: bytes, as: UTF8.self) }
        return value.string
    }

    /// A blob column, or `nil` for NULL or no bytes.
    func data(_ index: Int32) -> Data? {
        let value = self[Int(index)]
        let bytes = value.data ?? value.string.map { Data($0.utf8) }
        return bytes.flatMap { $0.isEmpty ? nil : $0 }
    }
}
