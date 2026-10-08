//
//  ArchiveSubstitute.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Stands in for any private class in a link preview's archive that is not
/// needed — the image and video placeholders Messages keeps beside the
/// metadata — so the unarchiver does not stop at the first one.
final class ArchiveSubstitute: NSObject, NSCoding {

    init?(coder: NSCoder) {}

    func encode(with coder: NSCoder) {}
}
