//
//  AppCard.swift
//  AppleMessages
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The card an iMessage app sends — a Find My location, a Google Maps
/// place, a game turn: the captions it shows and the link behind it.
public struct AppCard: Sendable, Equatable, Codable {

    /// The app's display name, e.g. `Google Maps`.
    public let appName: String?

    /// The card's lines, as the app laid them out.
    public let caption: String?
    public let subcaption: String?
    public let secondarySubcaption: String?
    public let tertiarySubcaption: String?
    public let imageTitle: String?
    public let imageSubtitle: String?

    /// What tapping the card opens, when it is a web link (an app's private
    /// payload URL is not repeated here).
    public let url: String?

    public init(appName: String? = nil, caption: String? = nil, subcaption: String? = nil, secondarySubcaption: String? = nil,
                tertiarySubcaption: String? = nil, imageTitle: String? = nil, imageSubtitle: String? = nil, url: String? = nil) {
        self.appName = appName
        self.caption = caption
        self.subcaption = subcaption
        self.secondarySubcaption = secondarySubcaption
        self.tertiarySubcaption = tertiarySubcaption
        self.imageTitle = imageTitle
        self.imageSubtitle = imageSubtitle
        self.url = url
    }
}
