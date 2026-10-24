//
//  TextRuns.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Text styles and animations, out of `attributedBody`.
//
//  MEASURED on macOS 27.0.1 (2026-10-25), one test message per style, on
//  both the sent and the received copy: each style is its own attribute set
//  to 1 — `__kIMTextBoldAttributeName`, `…Italic…`, `…Underline…`,
//  `…Strikethrough…` — and every text animation is ONE attribute,
//  `__kIMTextEffectAttributeName`, holding a number: Ripple 4, Big 5,
//  Bloom 6, Nod 8, Shake 9, Jitter 10, Small 11, Explode 12 (7 never came up
//  from the menu). Whole-bubble and full-screen effects are a separate column
//  (`Message.effect`).
//

import Foundation

/// Reading styling. Pure.
enum TextRuns {

    static let styleAttributes: [(String, TextStyle)] = [
        ("__kIMTextBoldAttributeName", .bold),
        ("__kIMTextItalicAttributeName", .italic),
        ("__kIMTextUnderlineAttributeName", .underline),
        ("__kIMTextStrikethroughAttributeName", .strikethrough),
    ]

    static let effectAttribute = "__kIMTextEffectAttributeName"

    /// The animations by number, as measured.
    static let animations: [Int: String] = [
        4: "ripple", 5: "big", 6: "bloom", 8: "nod", 9: "shake", 10: "jitter", 11: "small", 12: "explode",
    ]

    /// An animation's name; a number never measured is reported as itself.
    static func animation(_ number: Int) -> String {
        animations[number] ?? "effect-\(number)"
    }

    /// The runs of an archived body, attachment and app marks removed — or
    /// `nil` when nothing in it is styled or animated (most messages).
    static func runs(_ body: Data?) -> [TextRun]? {
        guard let body, let attributed = NSUnarchiver.unarchiveObject(with: body) as? NSAttributedString else { return nil }
        return runs(attributed)
    }

    static func runs(_ attributed: NSAttributedString) -> [TextRun]? {
        var runs: [TextRun] = []
        let string = attributed.string as NSString
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, range, _ in
            let text = BodyDecoding.strip(string.substring(with: range))
            guard !text.isEmpty else { return }
            let keys = Dictionary(uniqueKeysWithValues: attributes.map { ($0.key.rawValue, $0.value) })
            let styles = styleAttributes.compactMap { name, style in (keys[name] as? NSNumber)?.boolValue == true ? style : nil }
            let effect = (keys[effectAttribute] as? NSNumber).map { animation($0.intValue) }
            // Neighbours with the same styling read as one run.
            if let last = runs.last, last.styles == styles, last.animation == effect {
                runs[runs.count - 1] = TextRun(text: last.text + text, styles: styles, animation: effect)
            } else {
                runs.append(TextRun(text: text, styles: styles, animation: effect))
            }
        }
        return runs.contains { !$0.isPlain } ? runs : nil
    }

    /// The runs as Markdown: `**bold**`, `*italic*`, `~~struck~~`,
    /// `<u>underlined</u>` (Markdown has no underline). Animations are not
    /// Markdown; they are named in `TextRun.animation`.
    static func markdown(_ runs: [TextRun]) -> String {
        runs.map { run in
            // Markers hug the words: Markdown ignores "** bold **".
            let core = run.text.trimmingCharacters(in: .whitespaces)
            guard !core.isEmpty, !run.styles.isEmpty else { return run.text }
            let leading = String(run.text.prefix { $0 == " " })
            let trailing = String(run.text.reversed().prefix { $0 == " " })
            var wrapped = core
            if run.styles.contains(.underline) { wrapped = "<u>\(wrapped)</u>" }
            if run.styles.contains(.strikethrough) { wrapped = "~~\(wrapped)~~" }
            if run.styles.contains(.italic) { wrapped = "*\(wrapped)*" }
            if run.styles.contains(.bold) { wrapped = "**\(wrapped)**" }
            return leading + wrapped + trailing
        }.joined()
    }
}
