import Vapor
import FluentPostgreSQL

final class Acronym: Codable {
    var id: Int?
    var short: String
    var long: String
    var userId: User.ID

    init(short: String, long: String, userId: User.ID) {
        self.short = short
        self.long = long
        self.userId = userId
    }
}

extension Acronym {
    var user: Parent<Acronym, User> {
        return parent(\.userId)
    }
}

extension Acronym: PostgreSQLModel {
}

extension Acronym: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: conn, closure: { (model) in
            try addProperties(to: model)
            model.reference(from: \.userId, to: \User.id)
        })
    }
}

extension Acronym: Content {
}

extension Acronym: Parameter {
}
