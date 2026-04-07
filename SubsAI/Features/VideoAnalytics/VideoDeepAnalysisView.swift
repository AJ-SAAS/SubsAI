// Features/VideoAnalytics/VideoDeepAnalysisView.swift
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
        case hook      = "Hook 0–15s"
        case retention = "Retention"
        case compare   = "Compare"
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Video header
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                    Text(videoMetaText)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()

                // MARK: - Tab picker
                HStack(spacing: 0) {
                    ForEach(AnalysisTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tab.rawValue)
                                    .font(.system(size: 14))
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .foregroundColor(
                                        selectedTab == tab
                                            ? AppTheme.accent
                                            : AppTheme.textSecondary
                                    )
                                Rectangle()
                                    .fill(selectedTab == tab ? AppTheme.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Divider()

                // MARK: - Tab content
                if vm.isLoading {
                    loadingState
                } else if let analysis = vm.analysis {

                    if let error = vm.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    switch selectedTab {
                    case .hook:
                        HookAnalysisView(analysis: analysis)
                    case .retention:
                        RetentionCurveView(analysis: analysis)
                    case .compare:
                        VideoCompareView(currentVideo: video, allVideos: allVideos)
                    }
                }
            }
        }
        .navigationTitle("Deep Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Analyzing your video…")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var videoMetaText: String {
        let views = video.views > 0 ? "\(video.views.formatted()) views · " : ""
        let days = Calendar.current.dateComponents([.day], from: video.publishedAt, to: Date()).day ?? 0
        return "\(views)\(days)d ago"
    }
}
