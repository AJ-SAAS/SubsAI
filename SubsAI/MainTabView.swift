import SwiftUI

struct MainTabView: View {

    @StateObject private var coachVM = CoachViewModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            IntelligenceView(vm: coachVM)
                .tabItem {
                    Label("Intelligence", systemImage: "brain.head.profile")
                }

            CoachView(vm: coachVM)
                .tabItem {
                    Label("Coach", systemImage: "figure.mind.and.body")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(AppTheme.accent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            // ✅ UIColor not Color
            appearance.backgroundColor = UIColor.systemBackground
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
