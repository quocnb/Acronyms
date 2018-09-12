//
//  WebsiteController+Register.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Fluent
import Leaf
import Authentication

extension WebsiteController {
    func registerHandler(_ req: Request) throws -> Future<View> {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return try req.view().render("register", context)
    }

    func registerPostHandler( req: Request,
        data: RegisterData
        ) throws -> Future<Response> {
        do {
            try data.validate()
        } catch {
            let redirect: String
            if let error = error as? ValidationError,
                let message = error.reason.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed) {
                redirect = "/register?message=\(message)"
            } else {
                redirect = "/register?message=Unknown+error"
            }
            return req.future(req.redirect(to: redirect))
        }
        let password = try BCrypt.hash(data.password)
        // 3
        let user = User(
            name: data.name,
            username: data.username,
            password: password)
        // 4
        return user.save(on: req).map(to: Response.self) { user in
            // 5
            try req.authenticateSession(user)
            // 6
            return req.redirect(to: "/")
        } }
}

struct RegisterContext: Encodable {
    let title = WebsiteTitle.register
    let message: String?
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
}

extension RegisterData: Validatable, Reflectable {
    static func validations() throws -> Validations<RegisterData> {
        var validations = Validations(RegisterData.self)
        try validations.add(\.username, .ascii && .count(3...))
        try validations.add(\.password, .count(8...))
        validations.add("passwords match") { model in
            guard model.password == model.confirmPassword else {
                throw BasicValidationError("passwords don’t match")
            }
        }
        return validations
    }
}
