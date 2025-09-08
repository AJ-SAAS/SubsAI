import SwiftUI

@main
struct SubsAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            OnboardingView()
        }
    }
}
