import XCTest
@testable import GRDB

private struct Player: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "player"

    var id: Int64
    var name: String
    var score: Int
}

/// Every SQLite feature the fork ungated
///
/// Upstream gates each of these behind an `@available` attribute that names an OS version as a
/// stand-in for a SQLite version. This fork compiles its own SQLite, so the version is the same on
/// every platform and at every OS version. No test here carries an availability check, so the file
/// stops compiling if a gate comes back. Each test also asserts the SQLite version the feature
/// needs, which fails rather than skips when a build links an older library.
final class VendoredSQLiteFeatureTests: GRDBTestCase {
    // MARK: - SQLite 3.27

    func testVacuumInto() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_027_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(
                sql: "CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT, score INTEGER)")
            try db.execute(sql: "INSERT INTO player (name, score) VALUES ('Arthur', 10)")
        }

        let copyPath = NSTemporaryDirectory()
            .appending(ProcessInfo.processInfo.globallyUniqueString)
            .appending("-vacuum-into.sqlite")
        try dbQueue.vacuum(into: copyPath)

        let copy = try DatabaseQueue(path: copyPath)
        try copy.read { db in
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player"), 1)
        }
    }

    func testUnicode61DiacriticsRemove() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_027_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(virtualTable: "document", using: FTS3()) { t in
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("content")
            }
            try db.execute(sql: "INSERT INTO document (content) VALUES ('déjà vu')")
            try XCTAssertEqual(
                Int.fetchOne(db, sql: "SELECT COUNT(*) FROM document WHERE document MATCH 'deja'"),
                1)
        }
    }

    // MARK: - SQLite 3.30

    func testAggregateFilterClause() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_030_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try createPlayerTable(db)
            try Player(id: 1, name: "Arthur", score: -10).insert(db)
            try Player(id: 2, name: "Barbara", score: 20).insert(db)
            try Player(id: 3, name: "Craig", score: 40).insert(db)

            let score = Column("score")
            let players = Table("player")

            try XCTAssertEqual(
                Double.fetchOne(db, players.select(average(score, filter: score > 0))), 30)
            try XCTAssertEqual(Int.fetchOne(db, players.select(max(score, filter: score > 0))), 40)
            try XCTAssertEqual(Int.fetchOne(db, players.select(min(score, filter: score > 0))), 20)
            try XCTAssertEqual(Int.fetchOne(db, players.select(sum(score, filter: score > 0))), 60)
            try XCTAssertEqual(
                Double.fetchOne(db, players.select(total(score, filter: score > 0))), 60)
        }
    }

    func testNullsOrdering() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_030_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text).notNull()
                t.column("score", .integer)
            }
            try db.execute(
                sql: """
                    INSERT INTO player (id, name, score) VALUES (1, 'Arthur', NULL);
                    INSERT INTO player (id, name, score) VALUES (2, 'Barbara', 20);
                    """)

            let name = Column("name")
            let score = Column("score")
            let players = Table("player").select(name)

            try XCTAssertEqual(
                String.fetchAll(db, players.order(score.ascNullsLast)),
                ["Barbara", "Arthur"])
            try XCTAssertEqual(
                String.fetchAll(db, players.order(score.descNullsFirst)),
                ["Arthur", "Barbara"])
        }
    }

    // MARK: - SQLite 3.31

    func testGeneratedColumn() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_031_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("score", .integer)
                t.column("bonus", .integer).generatedAs(Column("score") * 2)
                t.column("label", .text).generatedAs(sql: "'p' || id")
            }
            try db.execute(sql: "INSERT INTO player (id, score) VALUES (1, 21)")

            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT bonus, label FROM player"))
            XCTAssertEqual(row["bonus"] as Int, 42)
            XCTAssertEqual(row["label"] as String, "p1")
        }
    }

    // MARK: - SQLite 3.35

    func testReturningClause() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_035_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try createPlayerTable(db)

            let inserted = try Player(id: 1, name: "Arthur", score: 10).insertAndFetch(db)
            XCTAssertEqual(inserted, Player(id: 1, name: "Arthur", score: 10))

            let saved = try Player(id: 2, name: "Barbara", score: 20).saveAndFetch(db)
            XCTAssertEqual(saved, Player(id: 2, name: "Barbara", score: 20))

            let updated = try Player
                .filter(Column("id") == 1)
                .updateAndFetchAll(db, [Column("score") += 100])
            XCTAssertEqual(updated, [Player(id: 1, name: "Arthur", score: 110)])

            let deleted = try Player
                .filter(Column("id") == 2)
                .deleteAndFetchAll(db)
            XCTAssertEqual(deleted, [Player(id: 2, name: "Barbara", score: 20)])
        }
    }

    func testDropColumn() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_035_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try createPlayerTable(db)
            try db.alter(table: "player") { t in t.drop(column: "score") }
            let columnNames = try db.columns(in: "player").map(\.name)
            XCTAssertEqual(columnNames, ["id", "name"])
        }
    }

    // MARK: - SQLite 3.37

    func testStrictTable() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_037_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player", options: [.strict]) { t in
                t.primaryKey("id", .integer)
                t.column("score", .integer)
            }
            // a STRICT table refuses a value the column type does not accept
            try XCTAssertThrowsError(db.execute(
                sql: "INSERT INTO player (id, score) VALUES (1, 'ten')"))
        }
    }

    func testTableList() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_037_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player", options: [.withoutRowID]) { t in
                t.primaryKey("id", .text)
            }
            let info = try XCTUnwrap(db.table("player"))
            XCTAssertEqual(info.name, "player")
            XCTAssertEqual(info.kind.rawValue, "table")
            XCTAssertTrue(info.isWithoutRowIDTable)
        }
    }

    // MARK: - SQLite 3.38

    func testJSONExtractionOperators() throws {
        XCTAssertGreaterThanOrEqual(Database.sqliteLibVersionNumber, 3_038_000)

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.primaryKey("id", .integer)
                t.column("info", .jsonText)
            }
            try db.execute(sql: #"INSERT INTO player (id, info) VALUES (1, '{"score":42}')"#)

            let players = Table("player")
            let info = JSONColumn("info")

            try XCTAssertEqual(Int.fetchOne(db, players.select(info["score"])), 42)
            try XCTAssertEqual(
                String.fetchOne(db, players.select(info.jsonRepresentation(atPath: "score"))), "42")
            try XCTAssertEqual(
                Int.fetchOne(db, players.select(info.jsonExtract(atPath: "$.score"))), 42)
        }
    }

    private func createPlayerTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.primaryKey("id", .integer)
            t.column("name", .text).notNull()
            t.column("score", .integer).notNull()
        }
    }
}
