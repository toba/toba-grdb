@testable import GRDB

/// A `Sendable` copy of a `Row`
///
/// A `ValueObservation` delivers its value across a concurrency boundary, so the observed value
/// must be `Sendable`. `Row` is not, because a fetched row can borrow the memory of the statement
/// that produced it. A test that observes rows observes this copy instead.
///
/// The copy holds the columns and the prefetched rows of the source row. It drops the row scopes,
/// and it flattens nested prefetches, because `Row` exposes prefetched rows by association key
/// alone.
struct SendableRow: Sendable, Equatable {
    /// A column name and the value stored under it
    struct Column: Sendable, Equatable {
        var name: String
        var value: DatabaseValue
    }

    /// The columns, in the order of the source row; a repeated name is kept
    var columns: [Column]

    /// The prefetched rows, by association key
    var prefetchedRows: [String: [SendableRow]] = [:]

    /// The copy without its prefetched rows, as `Row.unscoped` returns a row without its scopes and
    /// its prefetched rows
    var unscoped: SendableRow { .init(columns: columns) }

    /// A row that carries the same columns and prefetched rows
    ///
    /// Use it to decode a record from an observed value.
    var row: Row {
        let row = Row(impl: ArrayRowImpl(columns: columns.map { ($0.name, $0.value) }))
        for (key, rows) in prefetchedRows {
            row.prefetchedRows.setRows(rows.map(\.row), forKeyPath: [key])
        }
        return row
    }
}

extension SendableRow: FetchableRecord {
    init(row: Row) {
        columns = row.map { name, value in Column(name: name, value: value) }
        for key in row.prefetchedRows.keys {
            prefetchedRows[key] = row.prefetchedRows[key]?.map(SendableRow.init(row:))
        }
    }
}

extension SendableRow: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, any DatabaseValueConvertible?)...) {
        columns = elements.map { name, value in
            Column(name: name, value: value?.databaseValue ?? .null)
        }
    }
}

extension SendableRow: CustomStringConvertible {
    var description: String {
        "[" + columns.map { "\($0.name):\($0.value)" }.joined(separator: " ") + "]"
    }
}
