//
//  WebsiteController+Login.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Leaf
import Authentication
import Fluent

extension WebsiteController {
    func loginHandler(_ req: Request) throws -> Future<View> {
        let context: LoginContext
        if req.query[Bool.self, at: "error"] != nil {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        return try req.view().render("login", context)
    }

    func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
         return User.authenticate(
            username: userData.username,
            password: userData.password,
            using: BCryptDigest(),
            on: req
            ).map(to: Response.self, { (user) in
                guard let user = user else {
                    return req.redirect(to: "/login?error")
                }
                try req.authenticateSession(user)
                return req.redirect(to: "/")
            })
    }

    func logoutHandler(_ req: Request) throws -> Response {
        try req.unauthenticateSession(User.self)
        return req.redirect(to: "/")
    }
}

struct LoginContext:Encodable {
    let title = WebsiteTitle.login
    let loginError: Bool

    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}
