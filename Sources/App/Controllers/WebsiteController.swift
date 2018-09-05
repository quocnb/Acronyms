import Vapor
import Leaf

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        // 3
        router.get(use: indexHandler)
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", User.parameter, use: userHandler)
        router.get("users", use: allUsersHandler)
        router.get("categories", use: allCategoriesHandler)
        router.get("categories", Category.parameter, use: categoryHandler)
        router.get("acronyms", "create", use: createAcronymHandler)
        router.post(Acronym.self, at: "acronyms", "create", use: createAcronymPostHandler)

        router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)

        router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
    }

    func indexHandler(_ req: Request) throws -> Future<View> {
        // 1
        return Acronym.query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                // 2
                let acronymsData = acronyms.isEmpty ? nil : acronyms
                let context = IndexContext(
                    title: "Homepage",
                    acronyms: acronymsData)
                return try req.view().render("index", context)
        }
    }

    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                return acronym.user
                    .get(on: req)
                    .flatMap(to: View.self) { user in
                        // 4
                        let context = AcronymContext(
                            title: acronym.short,
                            acronym: acronym,
                            user: user)
                        return try req.view().render("acronym", context)
                }
        }
    }

    func userHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(User.self)
            .flatMap(to: View.self) { user in
                return try user.acronyms
                    .query(on: req)
                    .all()
                    .flatMap(to: View.self) { acronyms in
                        let context = UserContext(
                            title: user.name,
                            user: user,
                            acronyms: acronyms)
                        return try req.view().render("user", context)
                }
        }
    }

    func allUsersHandler(_ req: Request) throws -> Future<View> {
        // 2
        return User.query(on: req)
            .all()
            .flatMap(to: View.self) { users in
                // 3
                let context = AllUsersContext(
                    title: "All Users",
                    users: users)
                return try req.view().render("allUsers", context)
        }
    }

    func allCategoriesHandler(_ req: Request) throws
        -> Future<View> {
            let categories = Category.query(on: req).all()
            let context = AllCategoriesContext(categories: categories)
            return try req.view().render("allCategories", context)
    }

    func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Category.self)
            .flatMap(to: View.self) { category in
                let acronyms = try category.acronyms.query(on: req).all()
                let context = CategoryContext(
                    title: category.name,
                    category: category,
                    acronyms: acronyms)
                return try req.view().render("category", context)
        }
    }

    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        let context = CreateAcronymContext(users: User.query(on: req).all())
        return try req.view().render("createAcronym", context)
    }

    func createAcronymPostHandler(_ req: Request, acronym: Acronym) throws -> Future<Response> {
        return acronym.save(on: req).map(to: Response.self, { (acro) in
            guard let id = acro.id else {
                throw Abort(HTTPResponseStatus.internalServerError)
            }
            return req.redirect(to: "/acronyms/\(id)")
        })
    }

    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self, { (acronym) in
            let context = EditAcronymContext(acronym: acronym, users: User.query(on: req).all())
            return try req.view().render("createAcronym", context)
        })
    }

    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self), { (acronym, data) in
            acronym.short = data.short
            acronym.long = data.long
            acronym.userId = data.userId

            return acronym.save(on: req).map(to: Response.self, { (savedAcronym) in
                guard let id = savedAcronym.id else {
                    throw Abort(HTTPResponseStatus.internalServerError)
                }
                return req.redirect(to: "/acronyms/\(id)")
            })
        })
    }

    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self).delete(on: req).transform(to: req.redirect(to: "/"))
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    // 1
    let title = "All Categories"
    // 2
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    // 1
    let title: String
    // 2
    let category: Category
    // 3
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create new acronym"
    let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
    let title = "Edit acronym"
    let acronym: Acronym
    let users: Future<[User]>
    let editing = true
}
