import Vapor
import FluentPostgreSQL
import Foundation
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String

    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }

    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

extension User.Public: Content {}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension Future where T: User {
    func convertToPublic() -> Future<User.Public> {
        return self.map(to: User.Public.self) { user in
            return user.convertToPublic()
        }
    }
}

extension User {
    var acronyms: Children<User, Acronym> {
        return children(\.userId)
    }
}

extension User: PostgreSQLUUIDModel {}

extension User: Content {}

extension User: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: conn, closure: { (builder) in
            try addProperties(to: builder)
            builder.unique(on: \.username)
        })
    }
}

extension User: Parameter {}

extension User: BasicAuthenticatable {
    static var usernameKey: UsernameKey {
        return \User.username
    }

    static var passwordKey: PasswordKey {
        return \User.password
    }
}

extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

struct AdminUser: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        let password = try? BCrypt.hash("password")
        guard let hashed = password else {
            fatalError("Failed to create admin")
        }
        let user = User(name: "Assmin", username: "admin", password: hashed)
        return user.save(on: conn).transform(to: ())
    }

    static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
        return .done(on: conn)
    }

    typealias Database = PostgreSQLDatabase
}
