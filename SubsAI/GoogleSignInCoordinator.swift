import GoogleSignIn
import FirebaseAuth

class GoogleSignInCoordinator: NSObject {
    func signIn(presentingViewController: UIViewController, additionalScopes: [String], completion: @escaping (Result<(AuthCredential, String), Error>) -> Void) throws {
        print("GoogleSignInCoordinator: Starting sign-in with scopes: \(additionalScopes)")
        print("GoogleSignInCoordinator: Presenting view controller: \(presentingViewController.description)")

        guard let config = GIDSignIn.sharedInstance.configuration else {
            let error = NSError(domain: "GoogleSignInCoordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In configuration is missing"])
            print("GoogleSignInCoordinator: Error - \(error.localizedDescription)")
            throw error
        }
        print("GoogleSignInCoordinator: Configuration set with clientID: \(config.clientID)")

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: additionalScopes) { result, error in
            if let error = error {
                print("GoogleSignInCoordinator: Sign-in error: \(error.localizedDescription) (Code: \((error as NSError).code))")
                completion(.failure(error))
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                let error = NSError(domain: "GoogleSignInCoordinator", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing user or ID token"])
                print("GoogleSignInCoordinator: Error - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            let accessToken = user.accessToken.tokenString
            print("GoogleSignInCoordinator: Successfully signed in, user: \(user.profile?.email ?? "unknown"), access token: \(accessToken.prefix(10))...")
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            completion(.success((credential, accessToken)))
        }
    }
}
