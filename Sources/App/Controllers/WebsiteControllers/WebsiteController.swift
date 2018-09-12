import Vapor
import Leaf
import Fluent
import Authentication

enum WebsiteTitle {
    static let index = "Homepage"
    static let login = "Log In"
    static let createAcronym = "Create An Acronym"
    static let editAcronym = "Edit Acronym"
}

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))

        // Index
        authSessionRoutes.get(use: indexHandler)

        // Users
        authSessionRoutes.get("users", User.parameter, use: userHandler)
        authSessionRoutes.get("users", use: allUsersHandler)

        // Categories
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)

        // Acronyms
        authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
        protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
        protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)

        // Login
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)

        authSessionRoutes.post("logout", use: logoutHandler)
    }
}
