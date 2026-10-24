//
//  CardDecoding.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//
//  iMessage app cards and the places in them, out of `payload_data`.
//
//  MEASURED on macOS 27.0.1 (2026-10-25), a Find My share and a Google Maps
//  share sent in a test chat:
//  - An app card's payload is a keyed archive whose root is a plain
//    NSDictionary: `URL` (NSURL), `an` (the app's name), `userInfo` (the
//    card's lines: caption, subcaption, secondary-/tertiary-subcaption,
//    image-title, image-subtitle) and layout keys. Standard classes only, so
//    it decodes with secure coding.
//  - Find My's URL is only a query: `FindMyMessagePayloadVersionKey` and
//    `FindMyMessagePayloadZippedDataKey` — base64 (standard alphabet: a `+`
//    is data, not a space) of RAW deflate of JSON:
//    `initialLocation.{latitude, longitude, horizontalAccuracy, timestamp}`
//    (that timestamp is Unix time, 3.7 s before sending), `kind.share.duration`
//    (`oneHour`), and a top-level `timestamp` in seconds since 2001 (the send).
//  - Google Maps' URL is `https://www.google.com/maps/place/<lat>+<lon>/?entry=im`
//    and its card carries the address.
//

import Foundation

/// Reading cards and places. Pure.
enum CardDecoding {

    /// The card in an app payload, or `nil` for a payload that is not one.
    static func card(_ payload: Data?) -> (card: AppCard, url: String?)? {
        guard let payload,
              let root = try? NSKeyedUnarchiver.unarchivedObject(
                  ofClasses: [NSDictionary.self, NSArray.self, NSString.self, NSURL.self, NSData.self, NSNumber.self],
                  from: payload) as? [String: Any]
        else { return nil }
        let lines = root["userInfo"] as? [String: Any] ?? [:]
        func line(_ key: String) -> String? {
            (lines[key] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        }
        let url = (root["URL"] as? URL)?.absoluteString ?? (root["URL"] as? String)
        let web = url.flatMap { $0.hasPrefix("http://") || $0.hasPrefix("https://") ? $0 : nil }
        let card = AppCard(appName: (root["an"] as? String)?.replacingOccurrences(of: "\u{00A0}", with: " "),
                           caption: line("caption"), subcaption: line("subcaption"),
                           secondarySubcaption: line("secondary-subcaption"), tertiarySubcaption: line("tertiary-subcaption"),
                           imageTitle: line("image-title"), imageSubtitle: line("image-subtitle"), url: web)
        return (card, url)
    }

    /// The place a card stands for: Find My's packed share, else a maps link.
    static func location(cardURL: String?, card: AppCard?) -> SharedLocation? {
        guard let cardURL else { return nil }
        if let shared = findMy(cardURL) { return shared }
        guard let place = coordinates(cardURL) else { return nil }
        // The address is the line that is not an instruction ("Tap to open…").
        let address = [card?.caption, card?.subcaption, card?.imageTitle, card?.secondarySubcaption]
            .compactMap { $0 }.first { !$0.lowercased().hasPrefix("tap to") }
        return SharedLocation(latitude: place.latitude, longitude: place.longitude, source: place.source, streetAddress: address)
    }

    /// A Find My share, unpacked from its URL's query.
    static func findMy(_ url: String) -> SharedLocation? {
        guard let query = url.split(separator: "?", maxSplits: 1).last.map(String.init) else { return nil }
        var fields: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            // Percent-decoding only: in this base64 a `+` is data, not a space.
            if parts.count == 2 { fields[parts[0]] = parts[1].removingPercentEncoding ?? parts[1] }
        }
        guard var packed = fields["FindMyMessagePayloadZippedDataKey"] else { return nil }
        packed += String(repeating: "=", count: (4 - packed.count % 4) % 4)
        guard let zipped = Data(base64Encoded: packed),
              let json = try? (zipped as NSData).decompressed(using: .zlib) as Data,   // Apple's .zlib is raw deflate
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let fix = object["initialLocation"] as? [String: Any],
              let latitude = (fix["latitude"] as? NSNumber)?.doubleValue,
              let longitude = (fix["longitude"] as? NSNumber)?.doubleValue,
              valid(latitude, longitude)
        else { return nil }
        let accuracy = (fix["horizontalAccuracy"] as? NSNumber)?.doubleValue
        let measured = (fix["timestamp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        let duration = ((object["kind"] as? [String: Any])?["share"] as? [String: Any])?["duration"]
        let sharingFor = (duration as? [String: Any])?.keys.sorted().first ?? (duration as? String)
        return SharedLocation(latitude: latitude, longitude: longitude, accuracy: accuracy.flatMap { $0 >= 0 ? $0 : nil },
                              measuredAt: measured, sharingFor: sharingFor, source: "findmy")
    }

    /// Coordinates in a Google or Apple Maps link: `/maps/place/<lat>+<lon>`,
    /// `/@<lat>,<lon>`, `?q=` / `?ll=` / `?query=` / `?coordinate=`. A link
    /// to a named place without coordinates (or a short `goo.gl` link, which
    /// needs the network to open) is not a location here.
    static func coordinates(_ link: String) -> (latitude: Double, longitude: Double, source: String)? {
        guard let parts = URLComponents(string: link), let host = parts.host?.lowercased() else { return nil }
        let source: String
        if host == "maps.apple.com" || host.hasSuffix(".maps.apple.com") {
            source = "apple-maps"
        } else if host.contains("google.") && (parts.path.hasPrefix("/maps") || host.hasPrefix("maps.")) {
            source = "google-maps"
        } else {
            return nil
        }
        var candidates = (parts.queryItems ?? []).filter { ["ll", "q", "query", "coordinate", "sll", "center"].contains($0.name) }.compactMap(\.value)
        let path = parts.percentEncodedPath.removingPercentEncoding ?? parts.path
        if let range = path.range(of: "/place/") { candidates.insert(String(path[range.upperBound...].prefix { $0 != "/" }), at: 0) }
        if let at = path.range(of: "/@") { candidates.insert(String(path[at.upperBound...]), at: 0) }
        for candidate in candidates {
            let numbers = candidate.split(whereSeparator: { $0 == "," || $0 == "+" || $0 == " " }).prefix(2).compactMap { Double($0) }
            if numbers.count == 2, valid(numbers[0], numbers[1]) { return (numbers[0], numbers[1], source) }
        }
        return nil
    }

    static func valid(_ latitude: Double, _ longitude: Double) -> Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude) && !(latitude == 0 && longitude == 0)
    }
}
