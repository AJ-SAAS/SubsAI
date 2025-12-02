// AppDelegate.swift
import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        print("AppDelegate: Starting application")

        // DO NOT hardcode client ID anymore
        // GoogleService-Info.plist handles everything automatically
        // This is the official, required way with GoogleSignIn 7+

        // Optional: Restore previous sign-in (recommended)
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if error != nil {
                // User not signed in or session expired
                print("No previous sign-in to restore")
            } else if let user = user {
                print("Previous sign-in restored for: \(user.profile?.email ?? "unknown")")
            }
        }

        return true
    }

    // This handles the Google Sign-In callback URL
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
