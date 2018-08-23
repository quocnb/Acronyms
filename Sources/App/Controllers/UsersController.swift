import Vapor
import Fluent

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        usersRoute.post(User.self, use: createHandler)
        usersRoute.get(use: getAllUsers)
        usersRoute.get("first", use: getFirstUser)
        usersRoute.get("search", use: searchUser)
        usersRoute.get("sorted", use: sortedUser)
        usersRoute.delete(use: deleteUser)
    }

    func createHandler(_ req: Request, user: User) throws -> Future<User> {
        return user.save(on: req)
    }

    func getAllUsers(_ req: Request) throws -> Future<[User]> {
        return User.query(on: req).all()
    }

    func deleteUser(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }

    func getFirstUser(req: Request) throws -> Future<User> {
        return User.query(on: req).first().map(to: User.self, { (user) in
            guard let user = user else {
                throw Abort(.notFound)
            }
            return user
        })
    }

    func searchUser(_ req: Request) throws -> Future<[User]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
        return User.query(on: req).group(.or, closure: { (or) in
            or.filter(\.name == searchTerm)
            or.filter(\.username == searchTerm)
        }).all()
    }

    func sortedUser(_ req: Request) throws -> Future<[User]> {
        return User.query(on: req).sort(\.name, .ascending).all()
    }
}
