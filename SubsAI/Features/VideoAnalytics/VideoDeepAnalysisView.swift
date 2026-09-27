// Features/VideoAnalytics/VideoDeepAnalysisView.swift
// Premium deep analysis: dark purple page, white cards, three tabs.
// Hook = the first minute. Retention = the whole video. Compare = vs your other videos.
// Uses ReviewLook + PremiumWhiteCard from CoachReviewView.swift and HomeLook from DashboardView.swift.
import SwiftUI

struct VideoDeepAnalysisView: View {
    let video: Video
    let allVideos: [Video]

    @StateObject private var vm: VideoDeepAnalysisViewModel
    @State private var selectedTab: AnalysisTab = .hook

    init(video: Video, allVideos: [Video]) {
        self.video = video
        self.allVideos = allVideos
        _vm = StateObject(wrappedValue: VideoDeepAnalysisViewModel(video: video))
    }

    enum AnalysisTab: String, CaseIterable {
        case hook      = "Hook"
        case retention = "Retention"
        case compare   = "Compare"
    }

    var body: some View {
        ZStack(alignment: .top) {
            ReviewLook.background.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.43, green: 0.24, blue: 1.0).opacity(0.35), .clear],
                center: .top, startRadius: 0, endRadius: 360
            )
            .frame(height: 420)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    tabPicker

                    if vm.isLoading && selectedTab != .compare {
                        loadingCard
                    } else {
                        switch selectedTab {
                        case .hook:
                            HookAnalysisView(vm: vm, allVideos: allVideos)
                        case .retention:
                            RetentionCurveView(vm: vm)
                        case .compare:
                            VideoCompareView(currentVideo: video, allVideos: allVideos)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Deep analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle").font(.system(size: 11, weight: .bold))
                    Text("Premium").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(ReviewLook.premium)
            }
        }
        .task { await vm.load(allVideos: allVideos) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VideoThumbnailView(video: video)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(metaText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }

    private var metaText: String {
        var parts: [String] = []
        if let d = vm.insights?.durationSeconds {
            parts.append(String(format: "%d:%02d long", d / 60, d % 60))
        }
        if video.views > 0 { parts.append("\(video.views.formatted()) views") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Tabs (glass pill, white when selected)

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(AnalysisTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? HomeLook.ink : .white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule().fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Reading how people watched this video...")
                .font(.system(size: 15))
                .foregroundColor(HomeLook.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }
}

// MARK: - Shared bits for the three tabs

enum DeepFormat {
    static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
    static func pct(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

struct DeepSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.1)
            .foregroundColor(HomeLook.secondary)
    }
}

/// Shown when YouTube doesn't have retention data for a video yet
struct DeepNoDataCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not enough data yet")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(HomeLook.ink)
            Text("YouTube shows how people watch once a video has more views. Check back in a few days.")
                .font(.system(size: 15))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }
}
