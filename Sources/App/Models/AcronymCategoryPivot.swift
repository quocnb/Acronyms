import Vapor
import FluentPostgreSQL

final class AcronymCategoryPivot: PostgreSQLUUIDPivot, ModifiablePivot {

    typealias Left = Acronym
    typealias Right = Category

    var acronymID: Acronym.ID
    var categoryID: Category.ID

    var id: UUID?

    static let leftIDKey: LeftIDKey = \.acronymID
    static let rightIDKey: RightIDKey = \.categoryID

    init(_ left: AcronymCategoryPivot.Left, _ right: AcronymCategoryPivot.Right) throws {
        self.acronymID = try left.requireID()
        self.categoryID = try right.requireID()
    }
}
extension AcronymCategoryPivot: Migration {
    // 2
    static func prepare(
        on connection: PostgreSQLConnection
        ) -> Future<Void> {
        // 3
        return Database.create(self, on: connection) { builder in
            // 4
            try addProperties(to: builder)
            // 5
            builder.reference(
                from: \.acronymID,
                to: \Acronym.id,
                onDelete: .cascade)
            // 6
            builder.reference(
                from: \.categoryID,
                to: \Category.id,
                onDelete: .cascade)
        } }
}

