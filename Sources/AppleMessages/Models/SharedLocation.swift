//
//  SharedLocation.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A place someone sent: a Find My location share, a maps pin or link.
///
/// **A snapshot.** It is where they were when they sent it. A Find My share
/// that runs for an hour updates in Find My, never in Messages — measured:
/// the message's payload does not change afterwards.
public struct SharedLocation: Sendable, Equatable, Codable {

    public let latitude: Double
    public let longitude: Double

    /// How far off it may be, in metres, when the sender's device said.
    public let accuracy: Double?

    /// When the device took the fix, when it said.
    public let measuredAt: Date?

    /// For a Find My share: how long they chose to share for, as Find My
    /// names it — `oneHour`, `untilEndOfDay`, `indefinitely`.
    public let sharingFor: String?

    /// Where it came from: `findmy`, `google-maps`, `apple-maps`.
    public let source: String

    /// A street address the card carried, when it carried one.
    public let streetAddress: String?

    public init(latitude: Double, longitude: Double, accuracy: Double? = nil, measuredAt: Date? = nil,
                sharingFor: String? = nil, source: String, streetAddress: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.measuredAt = measuredAt
        self.sharingFor = sharingFor
        self.source = source
        self.streetAddress = streetAddress
    }

    /// An Apple Maps link to the spot.
    public var mapsURL: String {
        "https://maps.apple.com/?ll=\(latitude),\(longitude)"
    }
}
