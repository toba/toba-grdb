// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let darwinPlatforms: [Platform] = [
    .iOS,
    .macOS,
    .macCatalyst,
    .tvOS,
    .visionOS,
    .watchOS,
]
// Compilation options for the vendored SQLite amalgamation. SQLITE_ENABLE_PREUPDATE_HOOK is the
// reason this fork compiles its own SQLite: Apple ships the system library without it, and the
// CloudKit shadow tables in TobaData need sqlite3_preupdate_new to read a changed row. The
// amalgamation carries snapshot support on every platform, so upstream's Linux carve-out for
// SQLITE_DISABLE_SNAPSHOT is gone.
//
// The amalgamation compiles every virtual table module out by default, while the system library
// this fork replaced carried them. Each module option below restores one that GRDB exposes an API
// for. SQLITE_ENABLE_FTS3_PARENTHESIS is what makes AND, OR, NOT and grouping parentheses part of
// an FTS3 match pattern instead of ordinary tokens.
//
// SQLITE_USE_URI is off by default in the amalgamation and on in the system library. DatabaseQueue
// builds a file: uri for a named in-memory database, so without it SQLite reads that uri as a
// literal file name and writes a real file into the current directory.
let sqliteSettings: [CSetting] = [
    .define("SQLITE_ENABLE_SNAPSHOT"),
    .define("SQLITE_ENABLE_FTS3"),
    .define("SQLITE_ENABLE_FTS3_PARENTHESIS"),
    .define("SQLITE_ENABLE_FTS4"),
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_RTREE"),
    .define("SQLITE_ENABLE_MATH_FUNCTIONS"),
    .define("SQLITE_ENABLE_PREUPDATE_HOOK"),
    .define("SQLITE_USE_URI", to: "1"),
    .define("SQLITE_DQS", to: "0"),
    .define("SQLITE_LIKE_DOESNT_MATCH_BLOBS"),
    .define("SQLITE_OMIT_DEPRECATED"),
]

// Applied when clang builds the GRDBSQLite module for the Swift importer. That build does not see
// sqliteSettings, so sqlite3.h hides its preupdate declarations. shim.h re-declares them under this
// name to fill the gap.
var cSettings: [CSetting] = [.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK")]

// The same options as Swift conditionals. GRDB reads them to decide which of its own APIs to
// compile. SQLITE_DQS and SQLITE_USE_URI carry a value, so neither has a Swift form. Upstream
// gates the preupdate pair
// behind an environment variable it tells nobody to rely on. This fork applies both unconditionally,
// because the vendored amalgamation always carries the hook.
var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_SNAPSHOT"),
    .define("SQLITE_ENABLE_FTS3"),
    .define("SQLITE_ENABLE_FTS3_PARENTHESIS"),
    .define("SQLITE_ENABLE_FTS4"),
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_RTREE"),
    .define("SQLITE_ENABLE_MATH_FUNCTIONS"),
    .define("SQLITE_ENABLE_PREUPDATE_HOOK"),
    .define("SQLITE_LIKE_DOESNT_MATCH_BLOBS"),
    .define("SQLITE_OMIT_DEPRECATED"),
]
var dependencies: [PackageDescription.Package.Dependency] = []

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

// GRDB+SQLCipher: Uncomment those lines
//dependencies.append(.package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"))
//cSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLCipher"))

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        // One product over both targets. A consumer writes `import GRDB` and
        // `import GRDBSQLite`, and SwiftPM absorbs each target once.
        .library(name: "GRDB", targets: ["GRDB", "GRDBSQLite"]),
    ],
    dependencies: dependencies,
    targets: [
        // The vendored SQLite amalgamation. GRDB imports this module by name, so the target keeps
        // the name GRDB expects. shim.h comes from upstream and wraps the variadic C functions that
        // Swift cannot call. amalgamation.c is the only compiled source, and it includes sqlite3.c,
        // so the amalgamation stays byte for byte the sqlite.org release.
        .target(
            name: "GRDBSQLite",
            exclude: ["sqlite3.c"],
            cSettings: sqliteSettings),
        // GRDB+SQLCipher: Uncomment the GRDBSQLCipher target
        //.target(
        //    name: "GRDBSQLCipher",
        //    dependencies: [.product(name: "SQLCipher", package: "SQLCipher.swift")]
        //),
        .target(
            name: "GRDB",
            dependencies: [
                // GRDB+SQLCipher: Delete the GRDBSQLite dependency
                .target(name: "GRDBSQLite"),
                // GRDB+SQLCipher: Uncomment the SQLCipher and GRDBSQLCipher dependencies
                //.product(name: "SQLCipher", package: "SQLCipher.swift"),
                //.target(name: "GRDBSQLCipher"),
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/Core/DatabasePool/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/Private/InflectionsTests.json"),
                .copy("GRDBTests/ValueObservation/Issue1383.sqlite"),
                .copy("GRDBTests/GRDBCipher/db.SQLCipher3"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
