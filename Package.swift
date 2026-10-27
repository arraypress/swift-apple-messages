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
        // Opening chat.db read-only and running queries over it.
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "AppleMessages",
            dependencies: [
                .product(name: "ContactsKit", package: "swift-contacts"),
                .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
            ]
        ),
        .testTarget(name: "AppleMessagesTests", dependencies: [
            "AppleMessages",
            .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
        ]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
