import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        print("AppDelegate: Starting application")

        // Hardcoded clientID from your GoogleService-Info.plist
        let clientID = "574710533522-h2civa8q5lpt3kv16ga0aemd5a4k4itt.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("AppDelegate: Google Sign-In configured with clientID: \(clientID)")

        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Google Sign-In redirect
        let handled = GIDSignIn.sharedInstance.handle(url)
        print("AppDelegate: Received URL: \(url), handled: \(handled)")
        return handled
    }
}
