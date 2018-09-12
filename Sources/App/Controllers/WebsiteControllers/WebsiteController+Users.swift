//
//  WebsiteController+Users.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Leaf
import Fluent

extension WebsiteController {
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
