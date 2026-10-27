//
//  MessagesError+SQLiteReader.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  chat.db is read through swift-sqlite-reader; its errors are reported as
//  this library's own, so callers and messages stay the same.
//

import Foundation
import SQLiteReader

extension MessagesError {

    /// This library's error for a reader's.
    init(_ error: SQLiteReaderError) {
        switch error {
        case .notFound(let path): self = .noDatabase(path)
        case .permissionDenied(let path): self = .notPermitted(path)
        case .unreadable(_, let reason): self = .readFailed(reason)
        }
    }
}
