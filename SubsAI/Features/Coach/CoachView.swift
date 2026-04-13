// Features/Coach/CoachView.swift
import SwiftUI

enum VideoSortOrder: String, CaseIterable {
    case priority        = "Priority"
    case bestPerforming  = "Best performing"
    case leastPerforming = "Least performing"
    case latest          = "Latest"
    case oldest          = "Oldest"
    case mostViews       = "Most views"
}

struct CoachView: View {

    @ObservedObject var vm: CoachViewModel
    @State private var authError: AuthError?
    @State private var sortOrder: VideoSortOrder = .bestPerforming
    @State private var showSortSheet = false

    init(vm: CoachViewModel) {
        self.vm = vm
    }

    private var sortedVideos: [Video] {
        switch sortOrder {
        case .priority:        return vm.videosByPriority
        case .bestPerforming:  return vm.videos.sorted { $0.healthScore > $1.healthScore }
        case .leastPerforming: return vm.videos.sorted { $0.healthScore < $1.healthScore }
        case .latest:          return vm.videos.sorted { $0.publishedAt > $1.publishedAt }
        case .oldest:          return vm.videos.sorted { $0.publishedAt < $1.publishedAt }
        case .mostViews:       return vm.videos.sorted { $0.views > $1.views }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {

                        // MARK: - Title
                        Text("Coach")
                            .font(.system(size: 29, weight: .medium, design: .serif)) // was 28
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, 8)

                        // MARK: - Before your next upload card
                        if !vm.videos.isEmpty {
                            NextUploadBriefingCard(
                                videos: vm.videos,
                                report: vm.intelligenceReport,
                                postingTimeInsight: vm.postingTimeInsight,
                                vm: vm
                            )
                        } else if vm.isLoading {
                            diagnosisPlaceholder
                        }

                        // MARK: - Videos
                        if !vm.videos.isEmpty {

                            HStack {
                                Text("Your videos")
                                    .font(.system(size: 17, weight: .semibold, design: .serif)) // was 16
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Button {
                                    showSortSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 12)) // was 11
                                        Text(sortOrder.rawValue)
                                            .font(.system(size: 13)) // was 12
                                    }
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemFill))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.top, 4)

                            ForEach(sortedVideos) { video in
                                NavigationLink {
                                    CoachReviewView(
                                        video: video,
                                        allVideos: vm.videos,
                                        postingTimeInsight: vm.postingTimeInsight,
                                        vm: vm
                                    )
                                } label: {
                                    CoachVideoCard(
                                        video: video,
                                        replicationScore: vm.intelligenceReport?
                                            .replicationScore(for: video)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                        } else if vm.isLoading {
                            loadingState
                        } else {
                            emptyState
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .navigationBarHidden(true)
        }
        .confirmationDialog("Sort videos by", isPresented: $showSortSheet, titleVisibility: .visible) {
            ForEach(VideoSortOrder.allCases, id: \.self) { order in
                Button(order.rawValue) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortOrder = order
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            Task { await loadSafely() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .signInGoogleCompleted)) { _ in
            Task { await loadSafely() }
        }
        .alert(item: $authError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Placeholders
    private var diagnosisPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(AppTheme.accent.opacity(0.06))
            .frame(height: 140)
            .overlay(ProgressView())
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 0.5)
            )
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your videos…")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 37)) // was 36
                .foregroundColor(AppTheme.textTertiary)
            Text("No videos found")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Text("Videos from your channel will appear here once loaded.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func loadSafely() async {
        guard vm.videos.isEmpty else { return }
        do {
            _ = try await AuthManager.shared.getValidToken()
            await vm.loadVideos()
        } catch {
            authError = .sessionExpired
        }
    }
}

// MARK: - NextUploadBriefingCard
struct NextUploadBriefingCard: View {
    let videos: [Video]
    let report: ChannelIntelligenceReport?
    var postingTimeInsight: PostingTimeInsight? = nil
    var vm: CoachViewModel? = nil

    private var channelAvgCTR: Double {
        let ctrs = videos.compactMap { $0.analytics?.ctr }
        guard !ctrs.isEmpty else { return 0 }
        return ctrs.reduce(0, +) / Double(ctrs.count)
    }

    private var bestVideo: Video? {
        videos.filter { $0.growthPerView > 0 }
              .max(by: { $0.growthPerView < $1.growthPerView })
    }

    private var ctrLine: String {
        guard channelAvgCTR > 0 else { return "" }
        if channelAvgCTR >= 0.05 {
            return "Your avg CTR is \(String(format: "%.1f", channelAvgCTR * 100))% — above benchmark. Keep the same thumbnail style."
        } else {
            return "Your avg CTR is \(String(format: "%.1f", channelAvgCTR * 100))% — below the 5% benchmark. Change your thumbnail concept before you film, not after."
        }
    }

    private var ctrColor: Color {
        guard channelAvgCTR > 0 else { return AppTheme.textSecondary }
        return channelAvgCTR >= 0.05 ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 5) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 12)) // was 11
                    .foregroundColor(AppTheme.accent)
                Text("Before your next upload")
                    .font(.system(size: 11, weight: .medium)) // was 10
                    .foregroundColor(AppTheme.accent)
                    .kerning(1.0)
                    .textCase(.uppercase)
            }

            if channelAvgCTR > 0 {
                BriefingLine(
                    icon: "cursorarrow.click",
                    color: ctrColor,
                    text: ctrLine
                )
            }

            if let best = bestVideo {
                BriefingLine(
                    icon: "arrow.triangle.2.circlepath",
                    color: AppTheme.accent,
                    text: "Your best converter: \"\(String(best.title.prefix(40)))\" — study its format before you script your next video."
                )
            }

            if let pattern = report?.winningPatterns.first {
                BriefingLine(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    text: "\(pattern.title) — lean into this on your next upload."
                )
            }

            if let insight = postingTimeInsight {
                BriefingLine(
                    icon: "clock",
                    color: insight.isReliable ? .cyan : AppTheme.textSecondary,
                    text: insight.briefingLine
                )
            }

            if let vm = vm {
                NavigationLink {
                    IntelligenceView(vm: vm)
                } label: {
                    HStack(spacing: 5) {
                        Text("See all patterns in Intelligence")
                            .font(.system(size: 13)) // was 12
                            .foregroundColor(AppTheme.accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12)) // was 11
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.05))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - BriefingLine
struct BriefingLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12)) // was 11
                .foregroundColor(color)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13)) // was 12
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - ImprovedDiagnosisCard (kept for backward compat)
struct ImprovedDiagnosisCard: View {
    let diagnosis: ChannelDiagnosis
    let report: ChannelIntelligenceReport?

    private var bullets: [String] {
        let body = diagnosis.body
        let sentences = body.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(sentences.prefix(3))
    }

    private var healthChips: [(label: String, color: Color)] {
        guard let report = report else { return [] }
        var chips: [(String, Color)] = []
        let gqs = report.growthQualityScore
        if gqs.retentionStrength >= 0.40 {
            chips.append(("Retention ✓", .green))
        } else if gqs.retentionStrength >= 0.25 {
            chips.append(("Retention low", .yellow))
        } else {
            chips.append(("Retention ✗", .red))
        }
        let avgCTR = report.channelAvgCTR
        if avgCTR >= 0.06 {
            chips.append(("CTR ✓", .green))
        } else if avgCTR >= 0.04 {
            chips.append(("CTR low", .yellow))
        } else {
            chips.append(("CTR needs work", .red))
        }
        if gqs.composite >= 7.0 {
            chips.append(("Growth strong", .green))
        } else if gqs.composite >= 5.0 {
            chips.append(("Growth moderate", .yellow))
        } else {
            chips.append(("Growth low", .red))
        }
        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 5, height: 5)
                Text("Channel diagnosis")
                    .font(.system(size: 11, weight: .medium)) // was 10
                    .foregroundColor(AppTheme.accent)
                    .kerning(1.0)
                    .textCase(.uppercase)
            }
            Text(diagnosis.headline)
                .font(.system(size: 18, weight: .medium, design: .serif)) // was 17
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(3)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.top, 5)
                        Text(bullet + (bullet.hasSuffix(".") ? "" : "."))
                            .font(.system(size: 13)) // was 12
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !healthChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(healthChips, id: \.label) { chip in
                            Text(chip.label)
                                .font(.system(size: 11, weight: .medium)) // was 10
                                .foregroundColor(chip.color)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(chip.color.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.accent.opacity(0.06))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - CoachVideoCardWithReplication (kept for backward compat)
struct CoachVideoCardWithReplication: View {
    let video: Video
    let report: ChannelIntelligenceReport?

    var body: some View {
        CoachVideoCard(
            video: video,
            replicationScore: report?.replicationScore(for: video)
        )
    }
}

// MARK: - DiagnosisCard (kept for backward compat)
struct DiagnosisCard: View {
    let diagnosis: ChannelDiagnosis

    var body: some View {
        ImprovedDiagnosisCard(diagnosis: diagnosis, report: nil)
    }
}
