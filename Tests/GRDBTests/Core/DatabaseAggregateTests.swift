import GRDB
import XCTest

private struct CustomValueType: DatabaseValueConvertible {
    var databaseValue: DatabaseValue { "CustomValueType".databaseValue }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(dbValue), string == "CustomValueType"
        else { return nil }
        return CustomValueType()
    }
}

class DatabaseAggregateTests: GRDBTestCase {
    // MARK: - Return values

    func testAggregateReturningNull() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { nil }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(DatabaseValue.fetchOne(db, sql: "SELECT f()")!.isNull)
        }
    }

    func testAggregateReturningInt64() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { Int64(1) }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(Int64.fetchOne(db, sql: "SELECT f()")!, Int64(1))
        }
    }

    func testAggregateReturningDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { 1e100 }
        }
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(Double.fetchOne(db, sql: "SELECT f()")!, 1e100)
        }
    }

    func testAggregateReturningString() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { "foo" }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT f()")!, "foo")
        }
    }

    func testAggregateReturningData() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { "foo".data(using: .utf8) }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(Data.fetchOne(db, sql: "SELECT f()")!, "foo".data(using: .utf8))
        }
    }

    func testAggregateReturningCustomValueType() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { CustomValueType() }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(CustomValueType.fetchOne(db, sql: "SELECT f()") != nil)
        }
    }

    // MARK: - Argument values

    func testAggregateArgumentNil() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) { result = dbValues[0].isNull }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(Bool.fetchOne(db, sql: "SELECT f(NULL)")!)
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT f(1)")!)
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT f(1.1)")!)
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT f('foo')")!)
            try XCTAssertFalse(
                Bool.fetchOne(db, sql: "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!)
            try XCTAssertFalse(Bool.fetchOne(db, sql: "SELECT f(?)", arguments: [Data()])!)
        }
    }

    func testAggregateArgumentInt64() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Int64.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(Int64.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            try XCTAssertEqual(Int64.fetchOne(db, sql: "SELECT f(1)")!, 1)
            try XCTAssertEqual(Int64.fetchOne(db, sql: "SELECT f(1.1)")!, 1)
        }
    }

    func testAggregateArgumentDouble() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Double.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(Double.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            try XCTAssertEqual(Double.fetchOne(db, sql: "SELECT f(1)")!, 1.0)
            try XCTAssertEqual(Double.fetchOne(db, sql: "SELECT f(1.1)")!, 1.1)
        }
    }

    func testAggregateArgumentString() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = String.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(String.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT f('foo')")!, "foo")
        }
    }

    func testAggregateArgumentBlob() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Data.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(Data.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            try XCTAssertEqual(
                Data.fetchOne(db, sql: "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!,
                "foo".data(using: .utf8))
            try XCTAssertEqual(Data.fetchOne(db, sql: "SELECT f(?)", arguments: [Data()])!, Data())
        }
    }

    func testAggregateArgumentCustomValueType() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = CustomValueType.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertTrue(CustomValueType.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            try XCTAssertTrue(
                CustomValueType.fetchOne(db, sql: "SELECT f('CustomValueType')") != nil)
        }
    }

    // MARK: - Argument count

    func testAggregateWithoutArgument() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { "foo" }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(String.fetchOne(db, sql: "SELECT f()")!, "foo")
            do {
                try db.execute(sql: "SELECT f(1)")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f(1)")
                XCTAssertEqual(
                    error.description,
                    "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f(1)`"
                )
            }
        }
    }

    func testAggregateOfOneArgument() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = String.fromDatabaseValue(dbValues[0])?.uppercased()
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(
                String.fetchOne(db, sql: "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
            try XCTAssertEqual(
                String.fetchOne(db, sql: "SELECT f(?)", arguments: ["Roué"])!, "ROUÉ")
            try XCTAssertTrue(String.fetchOne(db, sql: "SELECT f(NULL)") == nil)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(
                    error.description,
                    "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f()`"
                )
            }
        }
    }

    func testAggregateOfTwoArguments() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                let ints = dbValues.compactMap { Int.fromDatabaseValue($0) }
                result = ints.reduce(0, +)
            }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 2, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT f(1, 2)")!, 3)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(
                    error.description,
                    "SQLite error 1: wrong number of arguments to function f() - while executing `SELECT f()`"
                )
            }
        }
    }

    func testVariadicFunction() throws {
        struct Aggregate: DatabaseAggregate {
            var result: any DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) { result = dbValues.count }
            func finalize() -> any DatabaseValueConvertible? { result }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT f()")!, 0)
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT f(1)")!, 1)
            try XCTAssertEqual(Int.fetchOne(db, sql: "SELECT f(1, 1)")!, 2)
        }
    }

    // MARK: - Step Errors

    func testAggregateStepThrowingDatabaseErrorWithMessage() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) throws {
                throw DatabaseError(message: "custom error message")
            }
            func finalize() -> any DatabaseValueConvertible? { fatalError() }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateStepThrowingDatabaseErrorWithCode() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) throws {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123))
            }
            func finalize() -> any DatabaseValueConvertible? { fatalError() }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "unknown error")
            }
        }
    }

    func testAggregateStepThrowingDatabaseErrorWithMessageAndCode() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) throws {
                throw DatabaseError(
                    resultCode: ResultCode(rawValue: 123), message: "custom error message")
            }
            func finalize() -> any DatabaseValueConvertible? { fatalError() }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateStepThrowingCustomError() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) throws {
                throw NSError(
                    domain: "CustomErrorDomain", code: 123,
                    userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
            func finalize() -> any DatabaseValueConvertible? { fatalError() }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                XCTAssertTrue(error.message!.contains("123"))
                XCTAssertTrue(error.message!.contains("custom error message"))
            }
        }
    }

    // MARK: - Result Errors

    func testAggregateResultThrowingDatabaseErrorWithMessage() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() throws -> any DatabaseValueConvertible? {
                throw DatabaseError(message: "custom error message")
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateResultThrowingDatabaseErrorWithCode() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() throws -> any DatabaseValueConvertible? {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123))
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "unknown error")
            }
        }
    }

    func testAggregateResultThrowingDatabaseErrorWithMessageAndCode() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() throws -> any DatabaseValueConvertible? {
                throw DatabaseError(
                    resultCode: ResultCode(rawValue: 123), message: "custom error message")
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateResultThrowingCustomError() throws {
        struct Aggregate: DatabaseAggregate {
            func step(_: [DatabaseValue]) {}
            func finalize() throws -> any DatabaseValueConvertible? {
                throw NSError(
                    domain: "CustomErrorDomain", code: 123,
                    userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", aggregate: Aggregate.self)
            db.add(function: fn)
            do {
                try db.execute(sql: "SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                XCTAssertTrue(error.message!.contains("123"))
                XCTAssertTrue(error.message!.contains("custom error message"))
            }
        }
    }

    // MARK: - Aggregation

    func testAggregation() throws {
        struct Aggregate: DatabaseAggregate {
            var sum: Int?
            mutating func step(_ dbValues: [DatabaseValue]) {
                if let int = Int.fromDatabaseValue(dbValues[0]) { sum = (sum ?? 0) + int }
            }
            func finalize() throws -> any DatabaseValueConvertible? { sum }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            try XCTAssertEqual(
                Int.fetchOne(
                    db,
                    sql: "SELECT f(a) FROM (SELECT 1 AS a UNION ALL SELECT 2 UNION ALL SELECT 3)")!,
                6)
        }
    }

    func testParallelAggregation() throws {
        struct Aggregate: DatabaseAggregate {
            var sum: Int?
            mutating func step(_ dbValues: [DatabaseValue]) {
                if let int = Int.fromDatabaseValue(dbValues[0]) { sum = (sum ?? 0) + int }
            }
            func finalize() throws -> any DatabaseValueConvertible? { sum }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
            db.add(function: fn)
            let row = try Row.fetchOne(
                db,
                sql: "SELECT f(a), f(b) FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 2, 4 UNION ALL SELECT 3, 6)"
            )!
            XCTAssertEqual(row[0], 6)
            XCTAssertEqual(row[1], 12)
        }
    }

    // MARK: - Deallocation

    func testDeallocationAfterSuccess() throws {
        final class Aggregate: DatabaseAggregate {
            // the database queue calls the aggregate one step at a time
            nonisolated(unsafe) static var onInit: (() -> Void)?
            nonisolated(unsafe) static var onDeinit: (() -> Void)?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_: [DatabaseValue]) {}
            func finalize() -> any DatabaseValueConvertible? { nil }
        }
        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = { aliveCount -= 1 }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            try db.execute(sql: "SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }

    func testDeallocationAfterStepError() throws {
        final class Aggregate: DatabaseAggregate {
            // the database queue calls the aggregate one step at a time
            nonisolated(unsafe) static var onInit: (() -> Void)?
            nonisolated(unsafe) static var onDeinit: (() -> Void)?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_: [DatabaseValue]) throws { throw DatabaseError(message: "boo") }
            func finalize() -> any DatabaseValueConvertible? { fatalError() }
        }
        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = { aliveCount -= 1 }

        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            _ = try? db.execute(sql: "SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }

    func testDeallocationAfterResultError() throws {
        final class Aggregate: DatabaseAggregate {
            // the database queue calls the aggregate one step at a time
            nonisolated(unsafe) static var onInit: (() -> Void)?
            nonisolated(unsafe) static var onDeinit: (() -> Void)?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_: [DatabaseValue]) {}
            func finalize() throws -> any DatabaseValueConvertible? {
                throw DatabaseError(message: "boo")
            }
        }

        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = { aliveCount -= 1 }

        let dbQueue = try makeDatabaseQueue()
        dbQueue.inDatabase { db in
            let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
            db.add(function: fn)
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            _ = try? db.execute(sql: "SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }
}
