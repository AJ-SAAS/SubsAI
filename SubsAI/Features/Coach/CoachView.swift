// Features/Coach/CoachView.swift
// New look, same as Home, Settings and Intelligence: gradient header, white page,
// one black hero card, white video cards. Purple = good, orange = needs work.
// Uses HomeLook, GradientHeader, DeviceInsets (DashboardView.swift)
// and IntelCard, IntelBlackCard (IntelligenceView.swift).
import SwiftUI

enum VideoSortOrder: String, CaseIterable {
    case priority        = "Priority"
    case bestPerforming  = "Best performing"
    case leastPerforming = "Least performing"
    case latest          = "Latest"
    case oldest          = "Oldest"
    case mostViews       = "Most views"
}

private struct CoachScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct CoachView: View {

    @ObservedObject var vm: CoachViewModel
    @State private var authError: AuthError?
    // Newest first by default. The last choice is remembered.
    @AppStorage("coach.sortOrder") private var sortOrder: VideoSortOrder = .latest
    @State private var showSortSheet = false
    @State private var showPaywall = false
    @State private var scrollY: CGFloat = 0
    @ObservedObject private var premium = PremiumStatus.shared

    init(vm: CoachViewModel) {
        self.vm = vm
    }

    private var showingShorts: Bool { vm.hasBothFormats && vm.formatFilter == .shorts }

    private var sortedVideos: [Video] {
        switch sortOrder {
        case .priority:        return vm.videosByPriority
        case .bestPerforming:  return vm.shownVideos.sorted { $0.healthScore > $1.healthScore }
        case .leastPerforming: return vm.shownVideos.sorted { $0.healthScore < $1.healthScore }
        case .latest:          return vm.shownVideos.sorted { $0.publishedAt > $1.publishedAt }
        case .oldest:          return vm.shownVideos.sorted { $0.publishedAt < $1.publishedAt }
        case .mostViews:       return vm.shownVideos.sorted { $0.views > $1.views }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let topInset = max(geo.safeAreaInsets.top, DeviceInsets.top)

                ZStack(alignment: .top) {
                    HomeLook.page

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: CoachScrollKey.self,
                                    value: g.frame(in: .named("coachScroll")).minY
                                )
                            }
                            .frame(height: 0)

                            header
                                .padding(.top, topInset + 10)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 28)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(GradientHeader())

                            VStack(alignment: .leading, spacing: 12) {
                                if !vm.videos.isEmpty {
                                    NextUploadBriefingCard(
                                        videos: vm.shownVideos,
                                        report: vm.intelligenceReport,
                                        postingTimeInsight: vm.postingTimeInsight,
                                        vm: vm
                                    )
                                    .padding(.bottom, 10)

                                    videosHeader

                                    ForEach(sortedVideos) { video in
                                        videoRow(video)
                                    }
                                } else if vm.isLoading {
                                    diagnosisPlaceholder
                                    loadingState
                                } else {
                                    emptyState
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)

                            Spacer(minLength: 120)
                        }
                    }
                    .coordinateSpace(name: "coachScroll")
                    .refreshable { await vm.loadVideos() }
                    .onPreferenceChange(CoachScrollKey.self) { scrollY = $0 }

                    // Keeps the status bar readable once the header scrolls away
                    HomeLook.ink
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity)
                        .opacity(scrollY < -120 ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: scrollY < -120)
                        .allowsHitTesting(false)   // never blocks taps on the header
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
        }
        // Our own sort sheet: grey background, white text (the system one was hard to read)
        .sheet(isPresented: $showSortSheet) {
            SortSheet(selection: sortOrder) { order in
                withAnimation(.easeInOut(duration: 0.2)) { sortOrder = order }
                showSortSheet = false
            }
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.visible)
            .presentationBackground(SortSheet.background)
            .presentationCornerRadius(28)
        }
        .onAppear {
            Task { await loadSafely() }
            Task { await premium.refresh() }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            Task { await premium.refresh() }
        }) {
            PaywallContainer()
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Coach")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("What to fix next")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(showingShorts
                     ? "Every Short, checked. Tap one to see its review."
                     : "Every video, checked. Tap one to see its review.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Only shows when the channel makes both Shorts and long videos
            if vm.hasBothFormats {
                FormatSwitch(selection: $vm.formatFilter)
            }
        }
    }

    // MARK: - Your videos

    private var videosHeader: some View {
        HStack {
            Text(showingShorts ? "Your Shorts" : "Your videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(HomeLook.ink)

            Spacer()

            Button {
                showSortSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(sortOrder.rawValue)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(HomeLook.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(HomeLook.fill))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func videoRow(_ video: Video) -> some View {
        let card = CoachVideoCard(
            video: video,
            replicationScore: vm.intelligenceReport?.replicationScore(for: video)
        )
        if premium.isPremium {
            NavigationLink {
                CoachReviewView(
                    video: video,
                    allVideos: vm.videos,
                    postingTimeInsight: vm.postingTimeInsight,
                    vm: vm
                )
            } label: { card }
            .buttonStyle(.plain)
        } else {
            // Free users: video reviews are Premium (their latest video is free on Home)
            Button { showPaywall = true } label: {
                card
                    // Lock sits on the thumbnail, so it doesn't cover the score
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .padding(18)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Loading / empty

    private var diagnosisPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(HomeLook.ink)
            .frame(height: 170)
            .overlay(ProgressView().tint(.white))
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Loading your videos…")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(HomeLook.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash")
                .font(.system(size: 34))
                .foregroundColor(HomeLook.hairline)
            Text("No videos yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(HomeLook.ink)
            Text("Your videos will show up here once they load. Pull down to try again.")
                .font(.system(size: 15))
                .foregroundColor(HomeLook.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
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

// MARK: - Before your next upload (black hero card, like Home's latest video)

struct NextUploadBriefingCard: View {
    let videos: [Video]
    let report: ChannelIntelligenceReport?
    var postingTimeInsight: PostingTimeInsight? = nil
    var vm: CoachViewModel? = nil

    private var channelAvgCTR: Double {
        // Only videos where YouTube gave us a real CTR (Shorts never have one)
        let ctrs = videos.compactMap { $0.analytics }.filter { $0.hasCTR }.map { $0.ctr }
        guard !ctrs.isEmpty else { return 0 }
        return ctrs.reduce(0, +) / Double(ctrs.count)
    }

    // Best performer = most views (a ratio like subs per 1K can be won by a 40-view video)
    private var bestVideo: Video? {
        videos.filter { $0.views > 0 }.max(by: { $0.views < $1.views })
    }

    private func shortTitle(_ title: String) -> String {
        title.count > 45 ? String(title.prefix(45)).trimmingCharacters(in: .whitespaces) + "…" : title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BEFORE YOUR NEXT UPLOAD")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.1)
                .foregroundColor(HomeLook.purpleLight)

            VStack(alignment: .leading, spacing: 14) {
                if channelAvgCTR > 0 {
                    let ctrText = "Avg CTR \(String(format: "%.1f", channelAvgCTR * 100))%"
                    let fullText = channelAvgCTR >= 0.05
                        ? "\(ctrText). Strong. Keep this thumbnail style."
                        : "\(ctrText). Needs work. Plan the thumbnail before you film."
                    BriefingLine(icon: "cursorarrow.click", text: fullText, boldPart: ctrText)
                }

                if let best = bestVideo {
                    let boldTitle = "Best performer"
                    BriefingLine(
                        icon: "arrow.triangle.2.circlepath",
                        text: "\(boldTitle): \"\(shortTitle(best.title))\" Make more like this.",
                        boldPart: boldTitle
                    )
                }

                // Same best day as Intelligence (one shared calculation)
                if let insight = postingTimeInsight, insight.isReliable {
                    let boldDay = "\(insight.bestDay) is your best posting day"
                    BriefingLine(icon: "calendar", text: "\(boldDay). Post your next video then.", boldPart: boldDay)
                } else if let pattern = report?.winningPatterns.first {
                    BriefingLine(icon: "chart.line.uptrend.xyaxis", text: "\(pattern.title). Try this again next.")
                }
            }

            if let vm = vm {
                NavigationLink {
                    IntelligenceView(vm: vm, showsBack: true)
                } label: {
                    HStack(spacing: 6) {
                        Text("See all patterns in Intelligence")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(HomeLook.purpleLight)
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(IntelBlackCard())
    }
}

// MARK: - One line on the black card, with an optional bold start

struct BriefingLine: View {
    let icon: String
    let text: String
    var boldPart: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 20)
                .padding(.top, 1)

            if let bold = boldPart, text.contains(bold) {
                Text(bold)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                + Text(text.replacingOccurrences(of: bold, with: ""))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
            } else {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Backward compatibility (other screens may use these)

struct ImprovedDiagnosisCard: View {
    let diagnosis: ChannelDiagnosis
    let report: ChannelIntelligenceReport?

    private var bullets: [String] {
        let sentences = diagnosis.body.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(sentences.prefix(3))
    }

    private var healthChips: [(label: String, good: Bool)] {
        guard let report = report else { return [] }
        var chips: [(String, Bool)] = []
        let gqs = report.growthQualityScore
        chips.append(gqs.retentionStrength >= 0.40 ? ("Watch time good", true) : ("Watch time low", false))
        let avgCTR = report.channelAvgCTR   // 0 = not known yet
        if avgCTR >= 0.06 { chips.append(("CTR good", true)) }
        else if avgCTR > 0 { chips.append(("CTR low", false)) }
        chips.append(gqs.composite >= 7.0 ? ("Growth strong", true) : ("Growth slow", false))
        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHANNEL DIAGNOSIS")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.1)
                .foregroundColor(HomeLook.purple)
            Text(diagnosis.headline)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(HomeLook.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(HomeLook.purple)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(bullet + (bullet.hasSuffix(".") ? "" : "."))
                            .font(.system(size: 14))
                            .foregroundColor(HomeLook.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !healthChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(healthChips, id: \.label) { chip in
                            Text(chip.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(chip.good ? HomeLook.purple : HomeLook.orangeText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill((chip.good ? HomeLook.purple : HomeLook.orange).opacity(0.1)))
                        }
                    }
                }
            }
        }
        .modifier(IntelCard())
    }
}

struct CoachVideoCardWithReplication: View {
    let video: Video
    let report: ChannelIntelligenceReport?

    var body: some View {
        CoachVideoCard(video: video, replicationScore: report?.replicationScore(for: video))
    }
}

struct DiagnosisCard: View {
    let diagnosis: ChannelDiagnosis

    var body: some View {
        ImprovedDiagnosisCard(diagnosis: diagnosis, report: nil)
    }
}

// MARK: - Shorts vs long videos switch

/// "Long videos | Shorts". Shown on Coach and Intelligence only when a channel makes both.
struct FormatSwitch: View {
    @Binding var selection: CoachViewModel.FormatFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CoachViewModel.FormatFilter.allCases, id: \.self) { option in
                let isOn = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(option.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isOn ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Capsule().fill(isOn ? Color.white : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }
}


// MARK: - Sort sheet (grey, white text)

struct SortSheet: View {
    let selection: VideoSortOrder
    let onPick: (VideoSortOrder) -> Void

    static let background = Color(red: 0.17, green: 0.17, blue: 0.18)   // #2B2B2E
    private let row = Color.white.opacity(0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sort videos by")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                ForEach(Array(VideoSortOrder.allCases.enumerated()), id: \.element) { index, order in
                    if index > 0 {
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.leading, 18)
                    }
                    Button { onPick(order) } label: {
                        HStack {
                            Text(order.rawValue)
                                .font(.system(size: 16, weight: order == selection ? .semibold : .regular))
                                .foregroundColor(.white)
                            Spacer()
                            if order == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(row))
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .preferredColorScheme(.dark)
    }
}
