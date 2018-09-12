//
//  WebsiteController+Categories.swift
//  App
//
//  Created by Quoc Nguyen on 2018/09/12.
//

import Vapor
import Leaf
import Fluent

extension WebsiteController {
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
