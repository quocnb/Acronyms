//
//  WebsiteController+Acronyms.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Leaf
import Fluent
import Authentication

extension WebsiteController {
    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                return acronym.user
                    .get(on: req)
                    .flatMap(to: View.self) { user in
                        let categories = try acronym.categories.query(on: req).all()
                        let context = AcronymContext(
                            title: acronym.short,
                            acronym: acronym,
                            user: user,
                            categories: categories)
                        return try req.view().render("acronym", context)
                }
        }
    }

    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        let token = try CryptoRandom().generateData(count: 16).base64EncodedString()
        let context = CreateAcronymContext(csrfToken: token)
        try req.session()["CSRF_TOKEN"] = token
        return try req.view().render("createAcronym", context)
    }

    func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
        let expectedToken = try req.session()["CSRF_TOKEN"]
        try req.session()["CSRF_TOKEN"] = nil
        guard expectedToken == data.csrfToken else {
            throw Abort(.badRequest)
        }
        let user = try req.requireAuthenticated(User.self)
        let acronym = try Acronym(short: data.short, long: data.long, userId: user.requireID())
        return acronym.save(on: req).flatMap(to: Response.self) { acronym in
            guard let id = acronym.id else {
                throw Abort(.internalServerError)
            }
            var categorySaves: [Future<Void>] = []
            for category in data.categories ?? [] {
                try categorySaves.append(Category.addCategory(category, to: acronym, on: req))
            }
            let redirect = req.redirect(to: "/acronyms/\(id)")
            return categorySaves.flatten(on: req).transform(to: redirect)
        }
    }

    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self, { (acronym) in
            let categories = try acronym.categories.query(on: req).all()
            let context = EditAcronymContext(
                acronym: acronym,
                categories: categories)
            return try req.view().render("createAcronym", context)
        })
    }

    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try flatMap(
            to: Response.self,
            req.parameters.next(Acronym.self),
            req.content.decode(CreateAcronymData.self)) { acronym, data in
                let user = try req.requireAuthenticated(User.self)
                acronym.short = data.short
                acronym.long = data.long
                acronym.userId = try user.requireID()
                return acronym.save(on: req).flatMap(to: Response.self) { savedAcronym in
                    guard let id = savedAcronym.id else {
                        throw Abort(.internalServerError)
                    }
                    return try acronym.categories.query(on: req).all().flatMap(to: Response.self) { existingCategories in
                        let existingStringArray = existingCategories.map { $0.name }
                        let existingSet = Set<String>(existingStringArray)
                        let newSet = Set<String>(data.categories ?? [])
                        let categoriesToAdd = newSet.subtracting(existingSet)
                        let categoriesToRemove = existingSet.subtracting(newSet)
                        var categoryResults: [Future<Void>] = []
                        for newCategory in categoriesToAdd {
                            categoryResults.append(
                                try Category.addCategory(
                                    newCategory,
                                    to: acronym,
                                    on: req))
                        }
                        for categoryNameToRemove in categoriesToRemove {
                            let categoryToRemove = existingCategories.first {
                                $0.name == categoryNameToRemove
                            }
                            if let category = categoryToRemove {
                                categoryResults.append(acronym.categories.detach(category, on: req))
                            }
                        }
                        return categoryResults.flatten(on: req).transform(to: req.redirect(to: "/acronyms/\(id)"))
                    }
                }
        }
    }

    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self).delete(on: req).transform(to: req.redirect(to: "/"))
    }
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct CreateAcronymContext: Encodable {
    let title = WebsiteTitle.createAcronym
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    let title = WebsiteTitle.editAcronym
    let acronym: Acronym
    let editing = true
    let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String
}
