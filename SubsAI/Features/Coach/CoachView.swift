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

                // Dashboard-style gradient background
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.65),
                        AppTheme.accent.opacity(0.40),
                        AppTheme.accent.opacity(0.15),
                        Color.black.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    RadialGradient(
                        colors: [AppTheme.accent.opacity(0.25), Color.clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 380
                    )
                    .frame(height: 360)
                    .ignoresSafeArea(edges: .top)

                    Spacer()
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {

                        Text("Coach")
                            .font(.system(size: 29, weight: .medium, design: .serif))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, 8)

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

                        if !vm.videos.isEmpty {

                            HStack {
                                Text("Your videos")
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Button {
                                    showSortSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 12))
                                        Text(sortOrder.rawValue)
                                            .font(.system(size: 13))
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
                .font(.system(size: 37))
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

// MARK: - NextUploadBriefingCard (Fixed for Light + Dark Mode)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)

                Text("BEFORE YOUR NEXT UPLOAD")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .kerning(1.2)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 16) {

                // CTR Line with bold percentage
                if channelAvgCTR > 0 {
                    let ctrText = "Avg CTR \(String(format: "%.1f", channelAvgCTR * 100))%"
                    let fullText = channelAvgCTR >= 0.05
                        ? "\(ctrText) — strong. Keep this thumbnail direction."
                        : "\(ctrText) — needs work. Rethink thumbnail before filming."

                    BriefingLine(icon: "cursorarrow.click", text: fullText, boldPart: ctrText)
                }

                // Best Video Line with bold "Best Performer"
                if let best = bestVideo {
                    let boldTitle = "Best Performer"
                    let fullText = "\(boldTitle): \"\(best.title.prefix(45))...\" — replicate this format."

                    BriefingLine(icon: "arrow.triangle.2.circlepath", text: fullText, boldPart: boldTitle)
                }

                // Posting Insight with bold day
                if let insight = postingTimeInsight, insight.isReliable {
                    let boldDay = "Monday is your best posting day"
                    let fullText = "\(boldDay) — lean into this on your next upload."

                    BriefingLine(icon: "clock", text: fullText, boldPart: boldDay)
                } else if let pattern = report?.winningPatterns.first {
                    BriefingLine(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "\(pattern.title) — lean into this pattern next."
                    )
                }
            }

            // Intelligence Link - Changed to Yellow for better visibility
            if let vm = vm {
                NavigationLink {
                    IntelligenceView(vm: vm)
                } label: {
                    HStack(spacing: 4) {
                        Text("See all patterns in Intelligence")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.yellow)                    // Changed to yellow
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "#181818"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Updated BriefingLine with Bold Support
struct BriefingLine: View {
    let icon: String
    let text: String
    var boldPart: String? = nil   // The part we want to make bold

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 20)

            // Support bold text using + operator
            if let bold = boldPart, text.contains(bold) {
                Text(bold)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.white)
                + Text(text.replacingOccurrences(of: bold, with: ""))
                    .font(.system(size: 14.5))
                    .foregroundColor(.white.opacity(0.85))
            } else {
                Text(text)
                    .font(.system(size: 14.5))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(3.5)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        }
    }

// MARK: - Backward Compatibility Structs (unchanged)
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
        if gqs.retentionStrength >= 0.40 { chips.append(("Retention ✓", .green)) }
        else if gqs.retentionStrength >= 0.25 { chips.append(("Retention low", .yellow)) }
        else { chips.append(("Retention ✗", .red)) }

        let avgCTR = report.channelAvgCTR
        if avgCTR >= 0.06 { chips.append(("CTR ✓", .green)) }
        else if avgCTR >= 0.04 { chips.append(("CTR low", .yellow)) }
        else { chips.append(("CTR needs work", .red)) }

        if gqs.composite >= 7.0 { chips.append(("Growth strong", .green)) }
        else if gqs.composite >= 5.0 { chips.append(("Growth moderate", .yellow)) }
        else { chips.append(("Growth low", .red)) }

        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                Circle().fill(AppTheme.accent).frame(width: 5, height: 5)
                Text("Channel diagnosis")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.accent)
                    .kerning(1.0)
                    .textCase(.uppercase)
            }
            Text(diagnosis.headline)
                .font(.system(size: 18, weight: .medium, design: .serif))
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
                            .font(.system(size: 13))
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
                                .font(.system(size: 11, weight: .medium))
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

struct DiagnosisCard: View {
    let diagnosis: ChannelDiagnosis

    var body: some View {
        ImprovedDiagnosisCard(diagnosis: diagnosis, report: nil)
    }
}
