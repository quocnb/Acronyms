import Vapor
import Imperial
import Authentication

struct ImperialController: RouteCollection {
    func boot(router: Router) throws {
        guard let callbackUrl = Environment.get("GOOGLE_CALLBACK_URL") else {
            fatalError("Callback Url not set")
        }
        try router.oAuth(from: Google.self, authenticate: "login-google", callback: callbackUrl, scope: ["profile", "email", "openid"], completion: processGoogleLogin)
    }

    func processGoogleLogin(_ req: Request, token: String) throws -> Future<ResponseEncodable> {
        return try Google.getUser(on: req).flatMap(to: ResponseEncodable.self, { (userInfo) in
            return User.query(on: req).filter(\.username == userInfo.email).first()
                .flatMap(to: ResponseEncodable.self, { (user) in
                    guard let existingUser = user else {
                        let user = User(name: userInfo.name, username: userInfo.email, password: "")
                        return user.save(on: req).map(to: ResponseEncodable.self, { (user) in
                            try req.authenticateSession(user)
                            return req.redirect(to: "/")
                        })
                    }
                    try req.authenticateSession(existingUser)
                    return req.future(req.redirect(to: "/"))
                })
        })
    }
}

extension Google {
    static func getUser(on req: Request) throws -> Future<GoogleUserInfo> {
        var header = HTTPHeaders()
        header.bearerAuthorization = try BearerAuthorization(token: req.accessToken())
        let googleAPIURL = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
        return try req.client().get(googleAPIURL, headers: header).map(to: GoogleUserInfo.self, { (response) in
            guard response.http.status == HTTPResponseStatus.ok else {
                if response.http.status == HTTPResponseStatus.unauthorized {
                    throw Abort.redirect(to: "/login-google")
                } else {
                    throw Abort(HTTPResponseStatus.internalServerError)
                }
            }
            print(response.content)
            return try response.content.syncDecode(GoogleUserInfo.self)
        })
    }
}

struct GoogleUserInfo: Content {
    let email: String
    let name: String
}
