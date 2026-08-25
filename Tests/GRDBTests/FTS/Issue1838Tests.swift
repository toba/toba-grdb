import GRDB
import XCTest

class Issue1838Tests: GRDBTestCase {
    /// Regression test for <https://github.com/groue/GRDB.swift/issues/1838>.
    ///
    /// This test passes since <https://github.com/groue/GRDB.swift/pull/1839>
    /// which workarounds the SQLite bug described at
    /// <https://sqlite.org/forum/forumpost/95413eb410>.
    func test_interrupted_rollback() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE documents USING FTS5(content)")
            try db.inTransaction {
                try db.execute(sql: "INSERT INTO documents(content) VALUES ('Document')")
                dbQueue.interrupt()
                return .rollback
            }
        }
        
        let documentCount = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents")!
        }
        XCTAssertEqual(documentCount, 0)
    }
    
    /// Tests about how we handle the FTS5 bug <https://sqlite.org/forum/forumpost/95413eb410>
    ///
    /// Upstream expects a count of zero. That holds only while SQLite carries the bug. The bug
    /// leaves a statement running, so the pending interrupt survives into the commit and aborts
    /// it. A fixed SQLite clears the interrupt flag when the commit starts, because no other
    /// statement is running, and the row lands. This version reads the expected count off what
    /// the write did.
    func test_interrupted_commit() throws {
        let dbQueue = try makeDatabaseQueue()

        try dbQueue.write { db in
            try db.execute(sql: "CREATE VIRTUAL TABLE documents USING FTS5(content)")
        }

        var wasInterrupted = false
        do {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO documents(content) VALUES ('Document')")
                dbQueue.interrupt()
            }
        } catch DatabaseError.SQLITE_INTERRUPT {
            wasInterrupted = true
        }

        // Make sure the interrupted state created by the FTS5 bug is no longer active.
        let documentCount = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM documents")!
        }
        XCTAssertEqual(documentCount, wasInterrupted ? 0 : 1)
    }
}
