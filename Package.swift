// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-apple-messages",
    platforms: [
        // macOS only, and not by choice: the Messages database and the app
        // that sends exist nowhere a third-party process can reach on iOS.
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleMessages", targets: ["AppleMessages"]),
    ],
    dependencies: [
        // For PhoneMatch and Person: the rule for whether "+44 7700 900123"
        // and "07700 900123" are the same number lives there, measured, and
        // is not written twice.
        .package(url: "https://github.com/arraypress/swift-contacts.git", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "AppleMessages",
            dependencies: [.product(name: "ContactsKit", package: "swift-contacts")]
        ),
        .testTarget(name: "AppleMessagesTests", dependencies: ["AppleMessages"]),
    ]
)
