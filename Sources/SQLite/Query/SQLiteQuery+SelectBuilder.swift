extension SQLiteQuery {
    public final class SelectBuilder: SQLitePredicateBuilder {
        public var select: Select
        public var predicate: SQLiteQuery.Expression? {
            get { return select.predicate }
            set { select.predicate = newValue }
        }
        
        public let connection: SQLiteConnection
        
        init(on connection: SQLiteConnection) {
            self.select = .init()
            self.connection = connection
        }
        
        @discardableResult
        public func all() -> Self {
            return columns(.all(nil))
        }
        
        @discardableResult
        public func columns(_ columns: Select.ResultColumn...) -> Self {
            select.columns += columns
            return self
        }
        
        public func from(_ tables: TableOrSubquery...) -> Self {
            select.tables += tables
            return self
        }
        
        public func from<Table>(_ table: Table.Type) -> Self where Table: SQLiteTable {
            select.tables.append(.table(.init(stringLiteral: Table.sqliteTableName)))
            return self
        }
        
        public func run<D>(decoding type: D.Type) -> Future<[D]>
            where D: Decodable
        {
            return run().map { try $0.map { try SQLiteRowDecoder().decode(D.self, from: $0) } }
        }
        
        public func run() -> Future<[[SQLiteColumn: SQLiteData]]> {
            return connection.query(.select(select))
        }
    }
}

public func ==<Table, Value>(_ lhs: KeyPath<Table, Value>, _ rhs: Value) throws -> SQLiteQuery.Expression
    where Table: SQLiteTable, Value: Encodable
{
    return try _binary(.equal, lhs, rhs)
}

public func !=<Table, Value>(_ lhs: KeyPath<Table, Value>, _ rhs: Value) throws -> SQLiteQuery.Expression
    where Table: SQLiteTable, Value: Encodable
{
    return try _binary(.notEqual, lhs, rhs)
}

private func _binary<Table, Value>(
    _ op: SQLiteQuery.Expression.BinaryOperator,
    _ lhs: KeyPath<Table, Value>,
    _ rhs: Value
) throws -> SQLiteQuery.Expression
    where Table: SQLiteTable, Value: Encodable
{
    guard let property = try Table.reflectProperty(forKey: lhs) else {
        fatalError()
    }
    let column: SQLiteQuery.Expression = .column(.init(
        table: Table.sqliteTableName,
        name: .init(property.path[0])
    ))
    return try .binary(column, op, .bind(rhs))
}

public protocol SQLiteTable: Codable, Reflectable {
    static var sqliteTableName: String { get }
}

extension SQLiteTable {
    public static var sqliteTableName: String {
        return "\(Self.self)"
    }
}

extension SQLiteConnection {
    public func select() -> SQLiteQuery.SelectBuilder {
        return .init(on: self)
    }
}
