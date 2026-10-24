//
//  CardsAndStylesTests.swift
//  AppleMessagesTests
//
//  Created by David Sherlock on 2026.
//
//  Styled text, app cards and shared places, built in the shapes measured on
//  real messages (2026-10-25) — archived by the same Foundation classes
//  Messages uses. Every place and word is invented.
//

import Foundation
import XCTest
@testable import AppleMessages

final class TextStyleTests: XCTestCase {

    /// A body archived in typedstream, as Messages stores it.
    private func body(_ parts: [(String, [String: Any])]) -> Data {
        let attributed = NSMutableAttributedString()
        for (text, attributes) in parts {
            var keyed = attributes
            keyed["__kIMMessagePartAttributeName"] = 0
            attributed.append(NSAttributedString(string: text, attributes: Dictionary(uniqueKeysWithValues: keyed.map { (NSAttributedString.Key($0.key), $0.value) })))
        }
        return NSArchiver.archivedData(withRootObject: attributed)
    }

    func testEachStyleAndAnimationIsRead() throws {
        let runs = try XCTUnwrap(TextRuns.runs(body([
            ("Plain then ", [:]),
            ("bold", ["__kIMTextBoldAttributeName": 1]),
            (" and ", [:]),
            ("both", ["__kIMTextBoldAttributeName": 1, "__kIMTextItalicAttributeName": 1]),
            (" ", [:]),
            ("gone", ["__kIMTextStrikethroughAttributeName": 1]),
            (" ", [:]),
            ("under", ["__kIMTextUnderlineAttributeName": 1]),
            (" ", [:]),
            ("BOOM", ["__kIMTextEffectAttributeName": 12]),
        ])))
        XCTAssertEqual(runs[1], TextRun(text: "bold", styles: [.bold]))
        XCTAssertEqual(runs[3], TextRun(text: "both", styles: [.bold, .italic]))
        XCTAssertEqual(runs.last, TextRun(text: "BOOM", animation: "explode"))
        XCTAssertEqual(TextRuns.markdown(runs), "Plain then **bold** and ***both*** ~~gone~~ <u>under</u> BOOM")
    }

    func testTheMeasuredAnimationNumbers() {
        XCTAssertEqual([4, 5, 6, 8, 9, 10, 11, 12].map(TextRuns.animation),
                       ["ripple", "big", "bloom", "nod", "shake", "jitter", "small", "explode"])
        XCTAssertEqual(TextRuns.animation(7), "effect-7", "a number never measured is reported, not guessed")
    }

    func testPlainTextHasNoRunsAndMarksAreDropped() {
        XCTAssertNil(TextRuns.runs(body([("Just words", [:])])))
        XCTAssertNil(TextRuns.runs(nil))
        // A styled word beside an attachment mark: the mark is not text.
        let runs = TextRuns.runs(body([("\u{FFFC}", [:]), ("look", ["__kIMTextBoldAttributeName": 1])]))
        XCTAssertEqual(runs, [TextRun(text: "look", styles: [.bold])])
        // Markers hug the words, so Markdown renders them.
        XCTAssertEqual(TextRuns.markdown([TextRun(text: " hi ", styles: [.bold])]), " **hi** ")
    }

    func testAnAppCardsMarkIsNotText() {
        // Find My's card text is a lone U+FFFD: it must not print as `�`.
        XCTAssertNil(BodyDecoding.clean("\u{FFFD}"))
        XCTAssertNil(BodyDecoding.clean("\u{FFFC}"))
        XCTAssertEqual(BodyDecoding.clean("see \u{FFFC}this"), "see this")
    }
}

final class CardTests: XCTestCase {

    private func payload(url: String, app: String, lines: [String: String]) throws -> Data {
        let root: NSDictionary = [
            "URL": NSURL(string: url)!, "an": app, "userInfo": lines as NSDictionary,
            "layoutClass": "MSMessageTemplateLayout",
        ]
        return try NSKeyedArchiver.archivedData(withRootObject: root, requiringSecureCoding: false)
    }

    /// A Find My URL as measured: version, then base64 of raw-deflated JSON.
    private func findMyURL(latitude: Double, longitude: Double, accuracy: Double, fixTime: Double, duration: String) throws -> String {
        let json = try JSONSerialization.data(withJSONObject: [
            "timestamp": fixTime - 978_307_200 + 3.7,
            "id": "TEST",
            "kind": ["share": ["isFromRequest": false, "duration": [duration: [:] as [String: Any]]]],
            "initialLocation": ["latitude": latitude, "longitude": longitude, "horizontalAccuracy": accuracy, "timestamp": fixTime,
                                "speed": -1, "course": 0, "altitude": 12.5],
            "isFromResend": false,
        ] as [String: Any])
        let packed = try (json as NSData).compressed(using: .zlib) as Data
        // Percent-encoded as Messages writes it; `+` stays a literal plus.
        let base64 = packed.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "+")))!
        return "?FindMyMessagePayloadVersionKey=v0&FindMyMessagePayloadZippedDataKey=\(base64)"
    }

    func testAFindMyShareUnpacks() throws {
        // A spot whose base64 is likely to contain `+`: run a few to be sure one does.
        var sawPlus = false
        for accuracy in [5.0, 8.2, 13.7, 21.1, 34.9] {
            let url = try findMyURL(latitude: 51.500729, longitude: -0.124625, accuracy: accuracy, fixTime: 1_761_000_000, duration: "oneHour")
            sawPlus = sawPlus || url.contains("+")
            let card = try XCTUnwrap(CardDecoding.card(payload(url: url, app: "Find\u{00A0}My", lines: ["caption": "Started Sharing Location"])))
            XCTAssertEqual(card.card.appName, "Find My")
            XCTAssertNil(card.card.url, "Find My's private query is not a link")
            let place = try XCTUnwrap(CardDecoding.location(cardURL: card.url, card: card.card))
            XCTAssertEqual(place.latitude, 51.500729, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, -0.124625, accuracy: 1e-9)
            XCTAssertEqual(place.accuracy ?? 0, accuracy, accuracy: 1e-9)
            XCTAssertEqual(place.measuredAt, Date(timeIntervalSince1970: 1_761_000_000), "the fix's time is Unix time")
            XCTAssertEqual(place.sharingFor, "oneHour")
            XCTAssertEqual(place.source, "findmy")
        }
        XCTAssertTrue(sawPlus, "at least one payload must carry a + so the space trap is exercised")
    }

    func testAGoogleMapsCardIsAPlaceWithItsAddress() throws {
        let card = try XCTUnwrap(CardDecoding.card(payload(
            url: "https://www.google.com/maps/place/48.858370+2.294481/?entry=im", app: "Google Maps",
            lines: ["caption": "1 Example Street, Testville", "subcaption": "Tap to open in Google Maps"])))
        XCTAssertEqual(card.card.url, "https://www.google.com/maps/place/48.858370+2.294481/?entry=im")
        let place = try XCTUnwrap(CardDecoding.location(cardURL: card.url, card: card.card))
        XCTAssertEqual(place.latitude, 48.85837, accuracy: 1e-9)
        XCTAssertEqual(place.longitude, 2.294481, accuracy: 1e-9)
        XCTAssertEqual(place.source, "google-maps")
        XCTAssertEqual(place.streetAddress, "1 Example Street, Testville")
        XCTAssertNil(place.accuracy)
    }

    func testMapLinksAndNot() {
        XCTAssertEqual(CardDecoding.coordinates("https://maps.apple.com/?ll=40.7128,-74.006&q=Somewhere")?.source, "apple-maps")
        XCTAssertEqual(CardDecoding.coordinates("https://www.google.com/maps/@35.6762,139.6503,15z")?.latitude, 35.6762)
        XCTAssertEqual(CardDecoding.coordinates("https://maps.google.com/?q=-33.8688,151.2093")?.longitude, 151.2093)
        XCTAssertNil(CardDecoding.coordinates("https://www.google.com/maps/place/Some+Cafe/"), "a named place has no coordinates")
        XCTAssertNil(CardDecoding.coordinates("https://example.com/?ll=1,2"), "not a maps site")
        XCTAssertNil(CardDecoding.coordinates("https://maps.apple.com/?ll=95,10"), "latitude out of range")
        XCTAssertNil(CardDecoding.card(Data("not an archive".utf8)))
        XCTAssertNil(CardDecoding.findMy("?FindMyMessagePayloadZippedDataKey=%%%"))
    }
}
