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
        return Acronym.query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                let acronymsData = acronyms.isEmpty ? nil : acronyms
                let userLoggedIn = try req.isAuthenticated(User.self)
                let showCookies = req.http.cookies["cookies-accepted"] == nil
                let context = IndexContext(
                    title: WebsiteTitle.index,
                    acronyms: acronymsData,
                    userLoggedIn: userLoggedIn,
                    showCookieMessage: showCookies
                )
                return try req.view().render("index", context)
        }
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}
