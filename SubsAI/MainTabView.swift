// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            VideoAnalyticsPlaceholderView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .onAppear {
            // Make tab bar look clean and modern
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}

// Beautiful placeholder until the real analytics screen is ready
struct VideoAnalyticsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .opacity(0.8)

                VStack(spacing: 12) {
                    Text("Video Analytics")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Coming Very Soon")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "dollarsign.circle.fill", text: "Revenue per video")
                    FeatureRow(icon: "eye.fill", text: "Click-through rate (CTR)")
                    FeatureRow(icon: "clock.fill", text: "Average view duration")
                    FeatureRow(icon: "brain.head.profile", text: "AI thumbnail & title suggestions")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            Text(text)
                .font(.body)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .opacity(0.6)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
