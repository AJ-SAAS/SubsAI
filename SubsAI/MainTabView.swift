// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {

            // MARK: - Home / Channel Overview
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // MARK: - Coach (Video Performance Guidance)
            CoachView()
                .tabItem {
                    Label("Coach", systemImage: "brain.head.profile")
                }

            // MARK: - Video Analytics
            VideoAnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }

            // MARK: - Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    // MARK: - Tab Bar Styling
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
