//
//  WebsiteController+Index.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Leaf
import Fluent

extension WebsiteController {
    func indexHandler(_ req: Request) throws -> Future<View> {
        // 1
        return Acronym.query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                // 2
                let acronymsData = acronyms.isEmpty ? nil : acronyms
                let userLoggedIn = try req.isAuthenticated(User.self)
                let context = IndexContext(
                    title: WebsiteTitle.index,
                    acronyms: acronymsData,
                    userLoggedIn: userLoggedIn
                )
                return try req.view().render("index", context)
        }
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
    let userLoggedIn: Bool
}
