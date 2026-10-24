//
//  TextRun+Markdown.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

/// Styled runs as Markdown: `**bold**`, `*italic*`, `~~struck~~`,
/// `<u>underlined</u>`. Animations are not Markdown; each run names its own.
public extension Array where Element == TextRun {
    var markdown: String { TextRuns.markdown(self) }
}
