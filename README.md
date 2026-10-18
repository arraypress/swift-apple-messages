# Swift Apple Messages

Read everything Messages has stored — iMessage, SMS and RCS — as values, and
draft or send through Messages itself.

```swift
import AppleMessages

let store = try MessageStore()
let chats = try store.chats()

for chat in chats.prefix(10) {
    print(chat.id, ChatMatching.title(chat), chat.service, chat.lastMessageAt ?? .distantPast)
}

let chat = chats[0]
for message in try store.messages(MessageQuery(chatID: chat.id, limit: 20)) {
    print(message.isFromMe ? "me" : message.sender?.address ?? "?", message.text ?? "")
    print("  reactions:", message.reactions.map(\.kind), "edited:", !message.edits.isEmpty)
}

try MessageSender.draft("On my way", to: "+447700900123")   // opens a draft, sends nothing
try MessageSender.send("On my way", toChat: chat.guid,     // sends, through your
                       runner: { try OSAScript.run($0, arguments: $1) })  // AppleScript runner
```

## What it decodes

Not just the text column. Each of these is its own format, and each is read:

| Part | How it is read |
|---|---|
| **Text** | the `text` column, or — when that is empty — the archived `attributedBody`, read by Foundation's own typedstream reader |
| **Reactions** | tapbacks settled onto the message they react to, a reaction taken back removed, emoji reactions with their emoji |
| **Edits** | every earlier version, from `message_summary_info` — not from `date_edited`, which is usually unset |
| **Unsent** | from the summary's `rp` — `date_retracted` stays 0 |
| **Link previews** | URL and title, from the `LPLinkMetadata` inside Messages' private `RichLink` archive |
| **Attachments** | name, type, size, path, whether it is still on this Mac, stickers — and how many a message HAD whose records are gone |
| **Effects** | `lasers`, `heart`, `impact` — named as Apple names them, not from a table |
| **iMessage apps** | the app a balloon came from: Find My, Apple Pay, games |
| **Voice messages, threaded replies, subjects** | flagged on the message |
| **Delivery and read** | delivered (with its time, when Messages recorded one — none is invented), read, and send errors |
| **Group events** | people added or removed, renames — opt-in, since they are not things anybody said |
| **Deleted conversations** | left out by default, as Messages leaves them out |

Names come from Contacts through
[swift-contacts](https://github.com/arraypress/swift-contacts):
`ContactNames(people)` fills them in, matching a number however it is
written — `07700 900123` is `+447700900123`.

## Read-only, and structurally so

`MessageStore` opens `~/Library/Messages/chat.db` with `SQLITE_OPEN_READONLY`
and no copy. Nothing in this library writes to it, and nothing should: the
schema is Apple's, undocumented, and the file is being written by Messages and
synced through iCloud while this reads.

Not `immutable=1` either — one published iMessage server opens it that way.
SQLite's documentation says the flag turns off locking and change detection;
it promises the file never changes. A single read cannot tell the
difference; a reader that stays open, as `watch` does, can.

## Sending — the safe road first

`MessageSender.draft` opens Messages with the text filled in, addressed to
one person, and sends nothing — somebody reads it and presses Send. Verified:
an `sms:<address>&body=<text>` link produced exactly that.

`MessageSender.send` sends, through Messages' AppleScript `send`, to the
conversation's own id — so a reply goes to the same thread, over the same
service, the person already uses. The text and the id reach the script as
`argv`, never pasted into its source, so nothing a message says can become
AppleScript.

**The script runner is yours (0.2).** `send` takes an `AppleScriptRunner` —
`(source, arguments) throws -> String` — rather than starting osascript
itself. Running it well is not this library's job: a hard timeout that kills a
script stuck behind a dialog, both pipes read together, a `--` before the
values (without it osascript reads a message that begins `-e` or `-s` as its
own flag), and an answer to "did it send before it failed?". CLIKit's
`OSAScript.run` does all four; whatever the runner throws reaches you
unchanged.

**Messages saying it sent is not the message existing.** macOS 26's Messages
can report a successful send while writing an empty row attached to no
conversation (found by OpenClaw's imsg). Confirm a send by finding YOUR new row
in the TARGET conversation with the text you sent — the `imessage` CLI does
exactly that, and calls anything less unconfirmed.

Sending needs Automation permission for Messages, which macOS asks for once.

## Things that cost an afternoon

**Since Ventura the text is often not in `text`.** It is in `attributedBody`,
an `NSAttributedString` archived in Apple's old typedstream format, and for
some messages ONLY there. Most tools scan those bytes for an `NSString` marker
and slice. Foundation still ships the format's own reader, `NSUnarchiver` —
deprecated for writing, still the only reader — and across a full database it
decoded every body without a failure. It is the one deprecation warning in
this build, on purpose.

**The date columns lie about edits and unsends.** `date_edited` is unset on
most edited messages and `date_retracted` stayed 0 on unsent ones; the truth
is in `message_summary_info`, a property list whose `ec` holds every version
of an edited message — usually ending with the current one, which is dropped.

**A message that was only a photo can look blank.** It keeps a placeholder
(U+FFFC) after the photo's record is removed — storage cleanup, or a voice
message gone once played. `Message.missingAttachments` counts those, so the
message reads as "a photo that is gone" rather than as nothing.

**Link cards carry a hidden attachment.** The preview's data is stored as a
`.pluginPayloadAttachment` file with a placeholder in the text of its own;
those are kept out of `attachments` and counted so the card does not read as
a missing photo.

**Chat ids changed shape.** On macOS 27 they begin `any;` — `any;-;+44…`,
`any;+;chat…`. Older write-ups, and tools built from them, assemble
`iMessage;-;…`, which matches no chat. This sends to the stored id, verbatim.

**RCS is a third service**, stored alongside iMessage and SMS.

**A file Messages cannot read goes out as an empty message.** Handed a path
in Downloads, AppleScript's `send` succeeded and the message was marked
delivered — with no attachment at all. Messages is sandboxed and reads its
own `~/Library/Messages/Attachments` reliably, so `send(file:toChat:)` stages
a copy there first (as steipete's imsg does) and returns the name the
attachment will carry, so a caller can confirm it arrived. Staged copies are
cleared after a day.

**Group events say only some of what they were.** Type 1 names the person and
whether they were added or removed; type 2 carries the new name. Types 3–5
carry neither, so they are reported by code rather than guessed at.

## Not verified

- **Group chats.** Reading and naming them is built and unit-tested; sending to
  a group and group events have not been checked against a live group.

## Requirements

macOS 14+. **Full Disk Access** for whatever runs it — `~/Library/Messages` is
protected, and without it the open fails as `notPermitted`. Automation
permission for Messages to send. Contacts permission, only for names.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-apple-messages.git", from: "0.2.0")
```

## Licence

MIT.
