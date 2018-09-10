import Vapor
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let acronymsRoute = router.grouped("api", "acronyms")
        acronymsRoute.get(use: getAllHandler)
        acronymsRoute.get(Acronym.parameter, use: getHandler)
        acronymsRoute.get("search", use: searchHandler)
        acronymsRoute.get("first", use: getFirstHandler)
        acronymsRoute.get("sorted", use: sortedHandler)
        acronymsRoute.get(Acronym.parameter, "user", use: getUserHandle)
        acronymsRoute.get(Acronym.parameter, "categories", use: getCategoryHander)

//        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
//        let guardAuthMiddleware = User.guardAuthMiddleware()
//        let protected = acronymsRoute.grouped(basicAuthMiddleware, guardAuthMiddleware)
//        protected.post(Acronym.self, use: createHandler)

        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = acronymsRoute.grouped([tokenAuthMiddleware, guardAuthMiddleware])
        tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)

        tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
        tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
        tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoryHandler)
        tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: removeCategoryHandler)
    }

    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }

    func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
        let user = try req.requireAuthenticated(User.self)
        let acronym = try Acronym(short: data.short, long: data.long, userId: user.requireID())
        return acronym.save(on: req)
    }

    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }

    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(AcronymCreateData.self), { (acr, newAcr) in
            acr.short = newAcr.short
            acr.long = newAcr.long
            let user = try req.requireAuthenticated(User.self)
            acr.userId = try user.requireID()
            return acr.save(on: req)
        })
    }

    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }

    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
        return Acronym.query(on: req).group(.or, closure: { (or) in
                let short = \Acronym.short
                or.filter(short == searchTerm)
                or.filter(\.long==searchTerm)
            }).all()
    }

    func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
        return Acronym.query(on: req).first().map(to: Acronym.self, { (acr) in
            guard let acronym = acr else {
                throw Abort(.notFound)
            }
            return acronym
        })
    }

    func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).sort(\.short, .ascending).all()
    }
}

extension AcronymsController {
    func getUserHandle(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(Acronym.self).flatMap(to: User.Public.self, { (acronym) in
            acronym.user.get(on: req).convertToPublic()
        })
    }
}

extension AcronymsController {
    func addCategoryHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(
            to: HTTPStatus.self,
            req.parameters.next(Acronym.self),
            req.parameters.next(Category.self), { (acronym, cateogry) in
                return acronym.categories.attach(cateogry, on: req).transform(to: HTTPStatus.created)
        })
    }

    func getCategoryHander(_ req: Request) throws -> Future<[Category]> {
        return try req.parameters.next(Acronym.self).flatMap(to: [Category].self, { (acronym) in
            return try acronym.categories.query(on: req).all()
        })
    }

    func removeCategoryHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self), { (acronym, category) in
            acronym.categories.detach(category, on: req).transform(to: HTTPStatus.noContent)
        })
    }
}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}
