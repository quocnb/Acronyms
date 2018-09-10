import Vapor
import Fluent
import Crypto

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        usersRoute.get(use: getAllUsers)
        usersRoute.get(User.parameter, use: getUser)
        usersRoute.get("first", use: getFirstUser)
        usersRoute.get("search", use: searchUser)
        usersRoute.get("sorted", use: sortedUser)

        usersRoute.delete(use: deleteUser)
        usersRoute.get(User.parameter, "acronyms", use: getAcronymHandler)
        let basicAuthMiddleware =
            User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        basicAuthGroup.post("login", use: loginHandler)

        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped([tokenAuthMiddleware, guardAuthMiddleware])
        tokenAuthGroup.post(User.self, use: createHandler)
    }

    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).convertToPublic()
    }

    func getAllUsers(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).decode(data: User.Public.self).all()
    }

    func getUser(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self).convertToPublic()
    }

    func deleteUser(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }

    func getFirstUser(req: Request) throws -> Future<User.Public> {
        return User.query(on: req).first().map(to: User.Public.self, { (user) in
            guard let user = user else {
                throw Abort(.notFound)
            }
            return user.convertToPublic()
        })
    }

    func searchUser(_ req: Request) throws -> Future<[User.Public]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
        return User.query(on: req).group(.or, closure: { (or) in
            or.filter(\.name == searchTerm)
            or.filter(\.username == searchTerm)
        }).decode(data: User.Public.self).all()
    }

    func sortedUser(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).sort(\.name, .ascending).decode(data: User.Public.self).all()
    }

    func getAcronymHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(User.self).flatMap(to: [Acronym].self, { user in
            try user.acronyms.query(on: req).all()
        })
    }

    func loginHandler(_ req: Request) throws -> Future<Token> {
        let user = try req.requireAuthenticated(User.self)
        let token = try Token.generate(for: user)
        return token.save(on: req)
    }
}
