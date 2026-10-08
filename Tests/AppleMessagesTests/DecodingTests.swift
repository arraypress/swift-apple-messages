//
//  DecodingTests.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  Nothing here reads anybody's messages. Every fixture is built in the test
//  — archived by the same Foundation classes Messages uses — and these are
//  the rules that decide whether a conversation comes out readable.
//

import XCTest
@testable import AppleMessages

/// An `attributedBody` the way Messages stores one: an attributed string in
/// the old typedstream archive.
func archivedBody(_ text: String) -> Data {
    NSArchiver.archivedData(withRootObject: NSAttributedString(string: text))
}

final class BodyTests: XCTestCase {

    func testTheTextColumnWinsWhenItHasText() {
        XCTAssertEqual(BodyDecoding.text(column: "hello", body: archivedBody("ignored")), "hello")
    }

    func testTheBodyIsReadWhenTheColumnIsEmpty() {
        // Some messages carry their text ONLY here.
        XCTAssertEqual(BodyDecoding.text(column: nil, body: archivedBody("only in the body")), "only in the body")
        XCTAssertEqual(BodyDecoding.text(column: "", body: archivedBody("only in the body")), "only in the body")
    }

    func testAttachmentMarksAreNotText() {
        XCTAssertEqual(BodyDecoding.text(column: "look\u{FFFC}", body: nil), "look")
        XCTAssertNil(BodyDecoding.text(column: "\u{FFFC}", body: nil))
        XCTAssertEqual(BodyDecoding.placeholders(column: "\u{FFFC}\u{FFFC} two photos", body: nil), 2)
    }

    func testEmojiAndNewlinesSurvive() {
        XCTAssertEqual(BodyDecoding.text(column: nil, body: archivedBody("one\ntwo 😀")), "one\ntwo 😀")
    }
}

final class DateTests: XCTestCase {

    func testNanosecondsSinceTwoThousandOne() {
        // Nanoseconds since 2001: this is October 2026.
        let date = StoredDate.date(813_000_000_000_000_000)!
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.year, from: date), 2026)
    }

    func testOldSecondsValuesAreNotJanuary2001() {
        let date = StoredDate.date(500_000_000)!
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.year, from: date), 2016)
    }

    func testZeroIsNever() {
        XCTAssertNil(StoredDate.date(0))
    }

    func testRoundTrip() {
        let now = Date(timeIntervalSinceReferenceDate: 812_000_000.5)
        XCTAssertEqual(StoredDate.date(StoredDate.stored(now))!.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }
}

final class ReactionTests: XCTestCase {

    func testCodes() {
        XCTAssertEqual(ReactionCodes.kind(2000)?.kind, .love)
        XCTAssertEqual(ReactionCodes.kind(2003)?.kind, .laugh)
        XCTAssertEqual(ReactionCodes.kind(2006)?.kind, .emoji)
        XCTAssertEqual(ReactionCodes.kind(3003)?.removes, true)
        XCTAssertNil(ReactionCodes.kind(1000))
    }

    func testTargets() {
        XCTAssertEqual(ReactionCodes.target("p:0/ABC-123"), "ABC-123")
        XCTAssertEqual(ReactionCodes.target("p:2/ABC-123"), "ABC-123")
        XCTAssertEqual(ReactionCodes.target("bp:ABC-123"), "ABC-123")
        XCTAssertEqual(ReactionCodes.target("ABC-123"), "ABC-123")
    }

    func testATakenBackReactionIsGoneAndOnlyThatPersons() {
        let events = [
            ReactionCodes.Event(target: "G", code: 2003, emoji: nil, sender: "+44", date: 1),
            ReactionCodes.Event(target: "G", code: 2003, emoji: nil, sender: nil, date: 2),
            ReactionCodes.Event(target: "G", code: 3003, emoji: nil, sender: "+44", date: 3),
        ]
        let standing = ReactionCodes.settle(events)
        XCTAssertEqual(standing.count, 1)
        XCTAssertNil(standing[0].from, "my laugh stays; theirs was taken back")
    }

    func testEmojiReactionsCarryTheirEmoji() {
        let standing = ReactionCodes.settle([ReactionCodes.Event(target: "G", code: 2006, emoji: "🔥", sender: "a@b.c", date: 1)])
        XCTAssertEqual(standing.first?.emoji, "🔥")
    }
}

final class SummaryTests: XCTestCase {

    func summary(_ versions: [(Int64, String)], unsent: Bool = false) -> [String: Any] {
        var dictionary: [String: Any] = [
            "ec": ["0": versions.map { ["d": NSNumber(value: $0.0), "t": archivedBody($0.1)] }],
            "ep": [0],
        ]
        if unsent { dictionary["rp"] = [0] }
        return dictionary
    }

    func testEarlierVersionsWithoutTheCurrentOne() {
        // `ec` usually ends with the current text; it is not an earlier version.
        let info = summary([(813_000_000_000_000_000, "helo"), (813_000_001_000_000_000, "hello")])
        XCTAssertEqual(SummaryInfo.edits(info, current: "hello").map(\.text), ["helo"])
        XCTAssertNotNil(SummaryInfo.lastEdited(info))
    }

    func testUnsentIsTheSummarysWord() {
        // `date_retracted` was 0 on the unsent messages checked.
        XCTAssertTrue(SummaryInfo.isUnsent(summary([], unsent: true)))
        XCTAssertFalse(SummaryInfo.isUnsent(summary([])))
        XCTAssertFalse(SummaryInfo.isUnsent(nil))
    }

    func testTheBlobIsAPropertyList() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: summary([(1, "x")]), format: .binary, options: 0)
        XCTAssertNotNil(SummaryInfo.dictionary(data)?["ec"])
        XCTAssertNil(SummaryInfo.dictionary(Data("nope".utf8)))
    }
}

final class KindTests: XCTestCase {

    func testEffectsAreNamedAsAppleNamedThem() {
        XCTAssertEqual(MessageKinds.effect("com.apple.messages.effect.CKLasersEffect"), "lasers")
        XCTAssertEqual(MessageKinds.effect("com.apple.messages.effect.CKHappyBirthdayEffect"), "happyBirthday")
        XCTAssertEqual(MessageKinds.effect("com.apple.MobileSMS.expressivesend.impact"), "impact")
        XCTAssertNil(MessageKinds.effect(nil))
    }

    func testAppsFromBalloons() {
        XCTAssertEqual(MessageKinds.app("com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.findmy.FindMyMessagesApp"),
                       "com.apple.findmy.FindMyMessagesApp")
        XCTAssertNil(MessageKinds.app("com.apple.messages.URLBalloonProvider"), "a link card is a link, not an app")
    }

    func testEventsAreNamedOnlyWhereTheDatabaseSays() {
        XCTAssertEqual(MessageKinds.event(itemType: 1, action: 0, title: nil, other: "+44")?.kind, "member-added")
        XCTAssertEqual(MessageKinds.event(itemType: 1, action: 1, title: nil, other: "+44")?.kind, "member-removed")
        XCTAssertEqual(MessageKinds.event(itemType: 2, action: 0, title: "Trip", other: nil)?.title, "Trip")
        XCTAssertEqual(MessageKinds.event(itemType: 5, action: 0, title: nil, other: nil)?.kind, "event-5")
        XCTAssertNil(MessageKinds.event(itemType: 0, action: 0, title: nil, other: nil))
    }

    func testPreviewPayloadsAreNotFilesAnybodySent() {
        XCTAssertTrue(MessageKinds.isPreviewPayload("/x/ABC.pluginPayloadAttachment"))
        XCTAssertFalse(MessageKinds.isPreviewPayload("/x/IMG_1.HEIC"))
    }

    func testPlaceholderPreviewsFallBackToTheLinkInTheText() {
        XCTAssertEqual(RichLinkDecoding.firstLink(in: "look https://example.com/a here")?.url, "https://example.com/a")
        XCTAssertNil(RichLinkDecoding.firstLink(in: "no link"))
        XCTAssertNil(RichLinkDecoding.preview(Data("not an archive".utf8)))
    }
}

final class MatchingTests: XCTestCase {

    let chats = [
        Chat(id: 20, guid: "any;-;+447700900123", participants: [Handle(address: "+447700900123", name: "Ada Lovelace")]),
        Chat(id: 21, guid: "any;-;ada@example.com", participants: [Handle(address: "ada@example.com", name: "Ada Lovelace")]),
        Chat(id: 30, guid: "any;+;chat1", displayName: "Analytical Engine", participants: [
            Handle(address: "+447700900123", name: "Ada Lovelace"), Handle(address: "+447700900999", name: "Charles"),
        ], isGroup: true),
    ]

    func testAPhoneNumberAsPeopleTypeIt() {
        XCTAssertEqual(ChatMatching.select("07700 900123", from: chats).map(\.id), [20])
    }

    func testANameFindsEveryOneToOneAndNoGroup() {
        // Ada on two addresses is two answers — the caller is told, not given one.
        XCTAssertEqual(ChatMatching.select("ada lovelace", from: chats).map(\.id), [20, 21])
    }

    func testIDsGuidsAndGroupNames() {
        XCTAssertEqual(ChatMatching.select("30", from: chats).map(\.id), [30])
        XCTAssertEqual(ChatMatching.select("any;-;ada@example.com", from: chats).map(\.id), [21])
        XCTAssertEqual(ChatMatching.select("analytical engine", from: chats).map(\.id), [30])
    }

    func testTitles() {
        XCTAssertEqual(ChatMatching.title(chats[2]), "Analytical Engine")
        XCTAssertEqual(ChatMatching.title(chats[0]), "Ada Lovelace")
    }

    func testAddresses() {
        XCTAssertTrue(AddressMatch.same("ADA@example.com", "ada@example.com"))
        XCTAssertTrue(AddressMatch.same("07700 900123", "+447700900123"))
        XCTAssertFalse(AddressMatch.same("07700 900124", "+447700900123"))
    }
}

final class SendingTests: XCTestCase {

    func testDraftLinksEscapeEverything() throws {
        let url = try XCTUnwrap(DraftLink.url(to: "+44 7700 900123", body: "fish & chips = 5"))
        XCTAssertEqual(url.absoluteString, "sms:+447700900123&body=fish%20%26%20chips%20%3D%205")
        XCTAssertNil(DraftLink.url(to: "a&b", body: "x"))
    }

    func testValuesNeverEnterTheScriptSource() {
        // Text and guid arrive as argv; nothing a message says can become
        // AppleScript.
        for script in [SendScripts.toChat, SendScripts.toAddress, SendScripts.fileToChat] {
            XCTAssertTrue(script.contains("item 1 of argv"))
            XCTAssertTrue(script.hasPrefix("on run argv"))
        }
    }

    func testEmptyMessagesAreRefusedBeforeMessagesIsAsked() {
        XCTAssertThrowsError(try MessageSender.send("  \n", toChat: "any;-;x")) {
            XCTAssertEqual($0 as? MessagesError, .emptyMessage)
        }
    }
}

final class QueryTests: XCTestCase {

    func testDeletedConversationsAndEventsAreLeftOutUnlessAsked() {
        let (plain, _) = MessageQueries.messages(MessageQuery(), handleIDs: nil)
        XCTAssertTrue(plain.contains("j.chat_id is not null"))
        XCTAssertTrue(plain.contains("m.item_type = 0"))
        let (everything, _) = MessageQueries.messages(MessageQuery(includeDeleted: true, includeEvents: true), handleIDs: nil)
        XCTAssertFalse(everything.contains("j.chat_id is not null"))
        XCTAssertFalse(everything.contains("m.item_type = 0"))
    }

    func testTextSearchAlsoReachesBodyOnlyMessages() {
        let (sql, values) = MessageQueries.messages(MessageQuery(text: "hello"), handleIDs: nil)
        XCTAssertTrue(sql.contains("m.attributedBody is not null"))
        XCTAssertFalse(sql.contains("limit ?"), "the limit is applied after decoding")
        XCTAssertEqual(values.count, 1)
    }
}
