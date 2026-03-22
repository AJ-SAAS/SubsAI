// AppDelegate.swift
import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        print("AppDelegate: Starting application")

        // Restore previous sign-in FIRST
        // Post .authRestored when complete so everything else waits for this
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                print("✅ Previous sign-in restored: \(user.profile?.email ?? "unknown")")
                // Update AuthManager state to reflect restored session
                DispatchQueue.main.async {
                    AuthManager.shared.handleGoogleSignIn(user: user)
                    // Small delay to ensure state is fully propagated before API calls fire
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .authRestored, object: nil)
                    }
                }
            } else {
                print("No previous sign-in to restore")
            }
        }

        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
