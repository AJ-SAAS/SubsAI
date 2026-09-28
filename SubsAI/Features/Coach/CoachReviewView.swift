// Features/Coach/CoachReviewView.swift
// Premium video review: dark purple to black page, white cards.
// Order: your next fix (with why we picked it), deep analysis (gold), views trend, compared to your usual, what's working.
// Uses HomeLook colors from DashboardView.swift.
import SwiftUI

// MARK: - Colors for this page

/// Shared with the deep analysis pages
enum ReviewLook {
    static let good      = Color(red: 0.122, green: 0.659, blue: 0.400)  // #1FA866 lines + bars
    static let goodText  = Color(red: 0.082, green: 0.525, blue: 0.310)  // #15864F text on white
    static let bad       = HomeLook.orange                               // #E8772E
    static let badText   = HomeLook.orangeText                           // #B45309
    static let usualBar  = HomeLook.purpleLight                         // #8C63FF "your usual" bars
    static let premium   = Color(red: 0.718, green: 0.612, blue: 1.0)    // #B79CFF

    static let background = LinearGradient(
        stops: [
            .init(color: Color(red: 0.149, green: 0.067, blue: 0.310), location: 0),     // #26114F
            .init(color: Color(red: 0.090, green: 0.039, blue: 0.200), location: 0.25),  // #170A33
            .init(color: Color(red: 0.043, green: 0.024, blue: 0.094), location: 0.55),  // #0B0618
            .init(color: Color(red: 0.020, green: 0.020, blue: 0.020), location: 1)      // #050505
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let gold = LinearGradient(
        stops: [
            .init(color: Color(red: 0.965, green: 0.863, blue: 0.557), location: 0),     // #F6DC8E
            .init(color: Color(red: 0.890, green: 0.714, blue: 0.298), location: 0.55),  // #E3B64C
            .init(color: Color(red: 0.788, green: 0.588, blue: 0.184), location: 1)      // #C9962F
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let goldInk = Color(red: 0.102, green: 0.071, blue: 0.024)                    // #1A1206
}

struct CoachReviewView: View {
    let video: Video
    var allVideos: [Video] = []
    var postingTimeInsight: PostingTimeInsight? = nil   // kept so CoachView still compiles
    var vm: CoachViewModel? = nil
    /// Free users get the full review on their latest video only (from Home).
    /// Deep analysis stays locked, and an upgrade card shows at the bottom.
    var isFreePreview: Bool = false

    @State private var showPaywall = false
    @State private var dailyViews: [Double]? = nil
    @State private var dailyMinutes: [Double] = []
    @State private var dailySubs: [Double] = []
    @State private var ctrHistory = YouTubeService.CTRHistory()
    @State private var loadingStep = 0

    /// What the "Checking this video" card says while the numbers load (last one stays)
    private var loadingSteps: [String] {
        var steps = ["Getting the numbers from YouTube…"]
        if !video.isShort { steps.append("Checking how many people clicked…") }
        steps += [
            "Finding where people stopped watching…",
            "Comparing it to your other videos…",
            "Picking the one fix that helps most…"
        ]
        return steps
    }
    @State private var insights: VideoInsights? = nil
    @State private var hookBaseline: HookBaseline? = nil
    @State private var insightsLoaded = false

    private var stats: VideoAnalytics? { video.analytics }

    var body: some View {
        ZStack(alignment: .top) {
            ReviewLook.background.ignoresSafeArea()

            // Soft purple glow behind the top of the page
            RadialGradient(
                colors: [Color(red: 0.43, green: 0.24, blue: 1.0).opacity(0.35), .clear],
                center: .top, startRadius: 0, endRadius: 360
            )
            .frame(height: 420)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    nextFixCard
                    deepAnalysisButton
                    viewsCard
                    watchTimeCard
                    if !video.isShort { ctrCard }
                    subscribersCard
                    compareCard
                    workingCard
                    if isFreePreview { upgradeCard }
                    footnote
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Video review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                    Text(isFreePreview ? "Free preview" : "Premium")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(ReviewLook.premium)
            }
        }
        .task {
            guard !insightsLoaded else { return }
            // Shorts compare to Shorts, long videos to long videos
            let recent = allVideos
                .filter { $0.videoId != video.videoId && $0.isSameFormat(as: video) }
                .sorted { $0.publishedAt > $1.publishedAt }

            async let daily = YouTubeService.shared.fetchVideoDaily(videoId: video.videoId, publishedAt: video.publishedAt)
            async let loadedInsights = YouTubeService.shared.fetchVideoInsights(videoId: video.videoId, publishedAt: video.publishedAt)
            async let baseline = YouTubeService.shared.fetchHookBaseline(recentVideos: recent)

            let numbers = await daily
            dailyViews = numbers.views
            dailyMinutes = numbers.minutes
            dailySubs = numbers.subs
            // Shorts have no thumbnail CTR (people swipe to them)
            if !video.isShort {
                ctrHistory = YouTubeService.shared.thumbnailCTRHistory(videoId: video.videoId)
            }
            var loaded = await loadedInsights
            loaded.isShort = video.isShort
            insights = loaded
            hookBaseline = await baseline
            withAnimation(.easeOut(duration: 0.25)) { insightsLoaded = true }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            Task { await PremiumStatus.shared.refresh() }
        }) {
            PaywallContainer()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VideoThumbnailView(video: video)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(video.isShort ? "Short · posted \(postedText)" : "Posted \(postedText)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var postedText: String {
        if video.ageInDays == 0 { return "today" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: video.publishedAt, relativeTo: Date())
    }

    // MARK: - Your next fix (the main card)

    private var diagnosis: VideoDiagnosis {
        VideoDiagnosis.make(video: video, allVideos: allVideos, insights: insights, hookBaseline: hookBaseline)
    }

    @ViewBuilder
    private var nextFixCard: some View {
        if !insightsLoaded && video.analytics != nil && video.ageInDays >= 2 {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOUR NEXT FIX")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
                    .foregroundColor(HomeLook.purple)
                HStack(spacing: 14) {
                    ThinkingSpark(size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Checking this video")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(HomeLook.ink)
                        Text(loadingSteps[loadingStep % loadingSteps.count])
                            .font(.system(size: 14))
                            .foregroundColor(HomeLook.secondary)
                            .id(loadingStep)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 10)
                .task {
                    // A new line every 1.6s, so people can see it's working
                    while !Task.isCancelled && !insightsLoaded {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        guard !Task.isCancelled, !insightsLoaded else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            loadingStep = min(loadingStep + 1, loadingSteps.count - 1)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PremiumWhiteCard())
        } else {
            let d = diagnosis
            let c = d.content

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(c.label)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(c.kind == .healthy ? ReviewLook.goodText : HomeLook.purple)
                    Spacer()
                    if let tag = c.tag {
                        Text(tag)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ReviewLook.badText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(ReviewLook.bad.opacity(0.12)))
                    }
                }

                Text(c.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(HomeLook.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(c.evidence, id: \.self) { line in
                        Text(LocalizedStringKey(line))
                            .font(.system(size: 15))
                            .foregroundColor(HomeLook.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if c.showTraffic, let groups = insights?.trafficGroups, !groups.isEmpty {
                    trafficBar(groups)
                }

                if !c.searchTerms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("PEOPLE FOUND IT BY SEARCHING")
                        ForEach(c.searchTerms) { term in
                            HStack(spacing: 6) {
                                Text(term.term)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(HomeLook.ink)
                                Text(Self.shortNumber(Double(term.views)))
                                    .font(.system(size: 13))
                                    .foregroundColor(HomeLook.secondary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(HomeLook.fill))
                            .textSelection(.enabled)
                        }
                    }
                }

                if c.actionIntro != nil || c.actionText != nil {
                    tryThisBox(c)
                }

                if let example = c.example {
                    Text(LocalizedStringKey(example))
                        .font(.system(size: 13))
                        .foregroundColor(HomeLook.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let pattern = c.pattern {
                    noteLine(icon: "square.stack.3d.up", text: pattern)
                }
                if let note = c.extraNote {
                    noteLine(icon: "bubble.left", text: note)
                }

                if c.kind == .fix || c.kind == .healthy {
                    Rectangle().fill(HomeLook.hairline).frame(height: 1)
                    sectionLabel(c.kind == .fix ? "WHY WE PICKED THIS" : "HOW EACH STEP IS DOING")
                    chainStrip(d.checks, steps: d.steps)
                    Text(c.whyText)
                        .font(.system(size: 13))
                        .foregroundColor(HomeLook.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PremiumWhiteCard())
        }
    }

    private func noteLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Where views came from: one bar split into Home, Suggested, Search, Other
    private func trafficBar(_ groups: [VideoInsights.TrafficGroup]) -> some View {
        let colors: [String: Color] = [
            "Home": HomeLook.purple,
            "Suggested": HomeLook.purpleLight,
            "Search": ReviewLook.bad,
            "Other": Color(red: 0.84, green: 0.84, blue: 0.86)
        ]
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("WHERE VIEWS CAME FROM")
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(groups) { group in
                        Rectangle()
                            .fill(colors[group.name] ?? .gray)
                            .frame(width: max(3, (g.size.width - CGFloat(groups.count - 1) * 2) * CGFloat(group.share)))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 6) {
                ForEach(groups) { group in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors[group.name] ?? .gray)
                            .frame(width: 8, height: 8)
                        Text("\(group.name) \(Int((group.share * 100).rounded()))%")
                            .font(.system(size: 12))
                            .foregroundColor(HomeLook.secondary)
                    }
                }
            }
        }
    }

    private func tryThisBox(_ c: DiagnosisContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Black box with a gold label, so the action stands out on the white card
            Text("TRY THIS")
                .font(.system(size: 12, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(ReviewLook.gold)

            if let intro = c.actionIntro {
                Text(intro)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if c.seoPhrase != nil {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("1. Thumbnail file name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        if let file = c.seoFileName {
                            Text(file)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
                                .textSelection(.enabled)
                        }
                    }
                    seoLine("2. Title,", "near the start")
                    seoLine("3. Description,", "in the first 2 lines")
                    seoLine("4. Tags,", c.searchTerms.count > 1 ? "plus the other search words above" : "plus 2 or 3 close versions")
                    seoLine("5. In the video,", "say it in the first 30 seconds. YouTube reads your captions.")
                }
            }

            if let action = c.actionText {
                Text(action)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HomeLook.ink))
    }

    private func seoLine(_ bold: String, _ rest: String) -> some View {
        (Text(bold).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
         + Text(" " + rest).font(.system(size: 14)).foregroundColor(.white.opacity(0.65)))
            .fixedSize(horizontal: false, vertical: true)
    }

    // Reach -> Click -> Hook -> Watch -> Subscribe, one dot per step
    // Shorts skip Click: people swipe to them, they don't tap a thumbnail
    private func chainStrip(_ checks: [FunnelStep: StepCheck], steps: [FunnelStep]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                chainNode(step, state: checks[step]?.state ?? .unknown)
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(HomeLook.hairline)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
        }
    }

    private func chainNode(_ step: FunnelStep, state: StepState) -> some View {
        VStack(spacing: 6) {
            ZStack {
                switch state {
                case .good:
                    Circle().fill(ReviewLook.good)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                case .bottleneck:
                    Circle().fill(ReviewLook.bad.opacity(0.18)).frame(width: 34, height: 34)
                    Circle().fill(ReviewLook.bad)
                    Text("!").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                case .weak:
                    Circle().stroke(ReviewLook.bad, lineWidth: 2)
                    Text("!").font(.system(size: 13, weight: .heavy)).foregroundColor(ReviewLook.bad)
                case .unknown:
                    Circle().fill(HomeLook.fill)
                    Rectangle().fill(Color(white: 0.7)).frame(width: 8, height: 2)
                }
            }
            .frame(width: 26, height: 26)

            Text(step.name)
                .font(.system(size: 11, weight: state == .bottleneck ? .bold : .medium))
                .foregroundColor(state == .bottleneck ? ReviewLook.badText : (state == .unknown ? Color(white: 0.6) : HomeLook.secondary))
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 56)
    }

    // MARK: - Deep analysis (gold)

    @ViewBuilder
    private var deepAnalysisButton: some View {
        if isFreePreview {
            Button { showPaywall = true } label: { deepAnalysisLabel(locked: true) }
                .buttonStyle(.plain)
        } else {
            NavigationLink {
                VideoDeepAnalysisView(video: video, allVideos: allVideos)
            } label: { deepAnalysisLabel(locked: false) }
                .buttonStyle(.plain)
        }
    }

    private func deepAnalysisLabel(locked: Bool) -> some View {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.965, green: 0.863, blue: 0.557))
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(ReviewLook.goldInk))

                VStack(alignment: .leading, spacing: 2) {
                    Text(locked ? "Unlock deep analysis" : "Deep analysis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(ReviewLook.goldInk)
                    Text("Your hook, where people leave, and how it compares")
                        .font(.system(size: 13))
                        .foregroundColor(ReviewLook.goldInk.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ReviewLook.goldInk)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(ReviewLook.gold)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.89, green: 0.71, blue: 0.30).opacity(0.28), radius: 17, x: 0, y: 12)
    }

    // MARK: - Upgrade card (free preview only)

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GET THIS FOR EVERY VIDEO")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HomeLook.purple)
            Text("Find what's holding back every video you've posted.")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(HomeLook.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Premium reviews all your videos, shows where people leave, and gives you one clear fix for each.")
                .font(.system(size: 15))
                .foregroundColor(HomeLook.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Button { showPaywall = true } label: {
                Text("See Premium")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(HomeLook.ink))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - Views + trend

    private var viewsCard: some View {
        let smooth = smoothed(dailyViews ?? [])
        let trend = viewsTrend(smooth)
        let perDay = recentPerDay

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("VIEWS")
                Spacer()
                if let trend {
                    HStack(spacing: 3) {
                        Image(systemName: trend.icon).font(.system(size: 11, weight: .bold))
                        Text(trend.text).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(trend.color)
                }
            }

            Text(video.views.formatted())
                .font(.system(size: 38, weight: .bold))
                .kerning(-1)
                .foregroundColor(HomeLook.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(perDay > 0 ? "All time · about \(perDay.formatted()) a day lately" : "All time")
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)

            if smooth.count >= 7, smooth.contains(where: { $0 > 0 }) {
                ReviewTrendChart(values: smooth, color: trend?.isDown == true ? ReviewLook.bad : ReviewLook.good)
                    .frame(height: 84)
                    .padding(.top, 8)
                HStack {
                    Text(windowLabel)
                    Spacer()
                    Text("7-day average")
                    Spacer()
                    Text("Today")
                }
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.6))
            } else if dailyViews == nil {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .frame(height: 84)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - Watch time, thumbnail CTR, new subscribers (same style as Views)

    private var watchTimeCard: some View {
        let totalHours = Double(video.views) * Double(video.averageViewDuration) / 3600
        let lately = dailyMinutes.suffix(7)
        let perDayMinutes = lately.isEmpty ? 0 : lately.reduce(0, +) / Double(lately.count)
        return trendCard(
            label: "WATCH TIME",
            value: Self.hoursText(totalHours),
            detail: perDayMinutes > 0 ? "All time · about \(Self.minutesText(perDayMinutes)) a day lately" : "All time",
            series: smoothed(dailyMinutes),
            upIsGood: true,
            emptyText: "No watch time in the last 90 days."
        )
    }

    /// "Sep 1 to Sep 27" (the days YouTube gave us CTR for)
    private var ctrWindowText: String? {
        guard let first = ctrHistory.firstDay, let last = ctrHistory.lastDay else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: first)) to \(f.string(from: last))"
    }

    private var ctrStartText: String? {
        guard let first = ctrHistory.firstDay else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: first)
    }

    private var ctrCard: some View {
        let impressions = ctrHistory.impressions
        let enough = impressions >= YouTubeService.minCTRImpressions
        let ctr = ctrHistory.ctr
        let window = ctrWindowText.map { " (\($0))" } ?? ""

        var value = "Not yet"
        var detail = "YouTube starts sharing CTR 1 to 2 days after you connect. It shows up here on its own."
        if enough {
            value = String(format: "%.1f%%", ctr * 100)
            detail = "Last 28 days\(window) · \(Int(impressions).formatted()) impressions. Same as YouTube Studio's default view."
        } else if impressions > 0 {
            value = "Too early"
            detail = "Only \(Int(impressions).formatted()) people saw the thumbnail in the last 28 days. We need about 100 to judge it fairly."
        }

        return trendCard(
            label: "THUMBNAIL CTR",
            value: value,
            detail: detail,
            series: enough ? ctrHistory.series : [],
            upIsGood: true,
            emptyText: nil,
            leftLabel: ctrStartText,
            extra: enough ? AnyView(CTRGauge(ctr: ctr)) : nil
        )
    }

    private var subscribersCard: some View {
        let gained = stats?.subscribersGained ?? 0
        let per1K = video.views > 0 ? Double(gained) / Double(video.views) * 1000 : 0
        return trendCard(
            label: "NEW SUBSCRIBERS",
            value: gained > 0 ? "+\(gained.formatted())" : "0",
            detail: video.views >= 1_000
                ? "All time · \(String(format: "%.1f", per1K)) for every 1K views"
                : "All time",
            series: smoothed(dailySubs),
            upIsGood: true,
            emptyText: "No new subscribers from this video in the last 90 days."
        )
    }

    /// One metric: big number, one line under it, and a 7-day average line chart.
    private func trendCard(label: String, value: String, detail: String, series: [Double],
                           upIsGood: Bool, emptyText: String?, leftLabel: String? = nil,
                           extra: AnyView? = nil) -> some View {
        let trend = seriesTrend(series, upIsGood: upIsGood)
        let hasChart = series.count >= 7 && series.contains(where: { $0 > 0 })

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel(label)
                Spacer()
                if let trend, hasChart {
                    HStack(spacing: 3) {
                        Image(systemName: trend.icon).font(.system(size: 11, weight: .bold))
                        Text(trend.text).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(trend.color)
                }
            }

            Text(value)
                .font(.system(size: 34, weight: .bold))
                .kerning(-1)
                .foregroundColor(HomeLook.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let extra {
                extra.padding(.top, 10)
            }

            if hasChart {
                ReviewTrendChart(values: series, color: trend?.isBad == true ? ReviewLook.bad : ReviewLook.good)
                    .frame(height: 72)
                    .padding(.top, 8)
                HStack {
                    Text(leftLabel ?? windowLabel)
                    Spacer()
                    Text("7-day average")
                    Spacer()
                    Text("Today")
                }
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.6))
            } else if dailyViews == nil {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .frame(height: 72)
            } else if let emptyText, !series.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13))
                    .foregroundColor(HomeLook.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    /// Compares the first third of the line with the last third
    private func seriesTrend(_ values: [Double], upIsGood: Bool) -> (text: String, icon: String, color: Color, isBad: Bool)? {
        guard values.count >= 14 else { return nil }
        let k = max(values.count / 3, 1)
        let first = values.prefix(k).reduce(0, +) / Double(k)
        let last = values.suffix(k).reduce(0, +) / Double(k)
        guard first > 0 || last > 0 else { return nil }
        let change = first > 0 ? (last - first) / first : 1
        if change >= 0.10 {
            return ("Going up", "arrow.up", upIsGood ? ReviewLook.goodText : ReviewLook.badText, !upIsGood)
        }
        if change <= -0.10 {
            return ("Going down", "arrow.down", upIsGood ? ReviewLook.badText : ReviewLook.goodText, upIsGood)
        }
        return ("Steady", "arrow.right", HomeLook.secondary, false)
    }

    private static func hoursText(_ hours: Double) -> String {
        if hours <= 0 { return "0 hours" }
        if hours < 1 { return "\(Int((hours * 60).rounded())) min" }
        if hours < 100 { return String(format: "%.1f hours", hours) }
        return "\(Int(hours.rounded()).formatted()) hours"
    }

    private static func minutesText(_ minutes: Double) -> String {
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }
        return String(format: "%.1f hours", minutes / 60)
    }

    private var windowLabel: String {
        let days = min(video.ageInDays, 90)
        return days >= 90 ? "90 days ago" : "Posted"
    }

    /// 7-day moving average, so the line shows the trend, not daily noise
    private func smoothed(_ values: [Double]) -> [Double] {
        guard values.count >= 7 else { return values }
        return values.indices.map { i in
            let window = values[max(0, i - 6)...i]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    private var recentPerDay: Int {
        guard let days = dailyViews, !days.isEmpty else { return 0 }
        let last = days.suffix(7)
        return Int((last.reduce(0, +) / Double(last.count)).rounded())
    }

    private func viewsTrend(_ values: [Double]) -> (text: String, icon: String, color: Color, isDown: Bool)? {
        guard values.count >= 14 else { return nil }
        let k = max(values.count / 3, 1)
        let first = values.prefix(k).reduce(0, +) / Double(k)
        let last = values.suffix(k).reduce(0, +) / Double(k)
        guard first > 0 || last > 0 else { return nil }
        let change = first > 0 ? (last - first) / first : 1
        if change >= 0.10  { return ("Still growing", "arrow.up", ReviewLook.goodText, false) }
        if change <= -0.10 { return ("Slowing down", "arrow.down", ReviewLook.badText, true) }
        return ("Steady", "arrow.right", HomeLook.secondary, false)
    }

    // MARK: - Compared to your usual

    private struct Comparison: Identifiable {
        let id = UUID()
        let name: String
        let you: Double
        let usual: Double
        let format: (Double) -> String
    }

    /// The middle value across your other videos
    private func usual(_ value: (Video) -> Double?) -> Double? {
        // Only videos with 100+ views: tiny videos swing too much to be "usual"
        let values = allVideos
            .filter { $0.videoId != video.videoId && $0.analytics != nil && $0.views >= 100 && $0.isSameFormat(as: video) }
            .compactMap(value)
            .filter { $0 > 0 }
            .sorted()
        guard values.count >= 3 else { return nil }
        return values[values.count / 2]
    }

    private var comparisons: [Comparison] {
        guard let s = stats else { return [] }
        var rows: [Comparison] = []

        if let you = insights?.hookRetention, let base = hookBaseline, base.sampleCount >= 3 {
            let second = insights?.hookSecond ?? 30
            rows.append(Comparison(name: "Still watching at \(second / 60):\(String(format: "%02d", second % 60))",
                                   you: you, usual: base.median,
                                   format: { "\(Int(($0 * 100).rounded()))%" }))
        }

        if s.retention > 0, let u = usual({ $0.analytics?.retention }) {
            rows.append(Comparison(name: "Watched", you: s.retention, usual: u,
                                   format: { "\(Int(($0 * 100).rounded()))%" }))
        }
        if video.growthPerView > 0, let u = usual({ $0.growthPerView }) {
            rows.append(Comparison(name: "Subs per 1K views", you: video.growthPerView, usual: u,
                                   format: { String(format: "%.1f", $0) }))
        }
        if !video.isShort, s.hasCTR, let u = usual({ ($0.analytics?.hasCTR ?? false) ? $0.analytics?.ctr : nil }) {
            rows.append(Comparison(name: "Thumbnail CTR", you: s.ctr, usual: u,
                                   format: { String(format: "%.1f%%", $0 * 100) }))
        }
        if video.ageInDays >= 7, video.views > 0, let u = usual({ Double($0.views) }) {
            rows.append(Comparison(name: "Views", you: Double(video.views), usual: u,
                                   format: { Self.shortNumber($0) }))
        }
        return rows
    }

    @ViewBuilder
    private var compareCard: some View {
        let rows = comparisons
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("COMPARED TO YOUR USUAL")
                    .padding(.bottom, 2)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    compareRow(row)
                    if index < rows.count - 1 {
                        Rectangle().fill(HomeLook.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PremiumWhiteCard())
        }
    }

    private func compareRow(_ row: Comparison) -> some View {
        let ratio = row.usual > 0 ? row.you / row.usual : 1
        let better = ratio >= 1.15
        let worse = ratio <= 0.87
        let tag: String = {
            if ratio >= 1.8 { return "About \(Int(ratio.rounded()))x better" }
            if better { return "Better" }
            if worse { return "Below usual" }
            return "About the same"
        }()
        let tagColor = better ? ReviewLook.goodText : (worse ? ReviewLook.badText : HomeLook.secondary)
        let barColor = better ? ReviewLook.good : (worse ? ReviewLook.bad : HomeLook.ink.opacity(0.55))
        let top = max(row.you, row.usual) * 1.1

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HomeLook.ink)
                Spacer()
                Text(tag)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(tagColor)
            }
            compareBar(label: "This video", value: row.format(row.you), fraction: row.you / top, color: barColor, bold: true)
            compareBar(label: "Your usual", value: row.format(row.usual), fraction: row.usual / top, color: ReviewLook.usualBar, bold: false)
        }
        .padding(.vertical, 14)
    }

    private func compareBar(label: String, value: String, fraction: Double, color: Color, bold: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
                .frame(width: 72, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(HomeLook.fill)
                    Capsule().fill(color).frame(width: g.size.width * CGFloat(min(max(fraction, 0.02), 1)))
                }
            }
            .frame(height: 8)
            Text(value)
                .font(.system(size: 13, weight: bold ? .bold : .medium))
                .foregroundColor(bold ? HomeLook.ink : HomeLook.secondary)
                .frame(width: 52, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - What's working

    @ViewBuilder
    private var workingCard: some View {
        let wins = workingWell
        if !wins.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("WHAT'S WORKING")
                ForEach(wins, id: \.self) { win in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(ReviewLook.good)
                        Text(win)
                            .font(.system(size: 15))
                            .foregroundColor(HomeLook.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PremiumWhiteCard())
        }
    }

    private var workingWell: [String] {
        guard let s = stats else { return [] }
        var wins: [String] = []
        if s.retention >= (video.isShort ? 0.90 : 0.40) {
            wins.append("People watch \(Int((s.retention * 100).rounded()))% of it. That's great.")
        }
        if !video.isShort && s.hasCTR && s.ctr >= 0.06 {
            wins.append("Your thumbnail gets clicks. Keep this style.")
        }
        if video.ageInDays >= 30, let trend = viewsTrend(smoothed(dailyViews ?? [])), !trend.isDown, recentPerDay > 0 {
            wins.append("It still gets new views every day.")
        }
        if video.ageInDays >= 7, let ratio = video.viewsVsUsual, ratio >= 1.5 {
            wins.append(String(format: "It got %.1fx your usual views.", ratio))
        }
        if video.growthPerView >= 2.0 {
            wins.append("It turns viewers into subscribers.")
        }
        if wins.isEmpty && insightsLoaded && diagnosis.bottleneck == nil {
            wins.append("Nothing is holding it back. Try this format again.")
        }
        return Array(wins.prefix(2))
    }

    // MARK: - Small pieces

    private var footnote: some View {
        Text(video.isShort
             ? "\"Your usual\" is the middle of your other Shorts."
             : "\"Your usual\" is the middle of your long videos. CTR is from recent days, because that's what YouTube shares.")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.42))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.1)
            .foregroundColor(HomeLook.secondary)
    }

    private static func shortNumber(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 10_000    { return String(format: "%.0fK", value / 1_000) }
        if value >= 1_000     { return String(format: "%.1fK", value / 1_000) }
        return "\(Int(value))"
    }
}

// MARK: - White card with a soft shadow

struct PremiumWhiteCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Shadow sits on the card shape only. On the whole view it also
            // lands behind every bar and line inside the card.
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 12)
            )
    }
}

// MARK: - Thinking spark (loading)
// A purple starburst whose rays grow and shrink while it slowly turns.

struct ThinkingSpark: View {
    var size: CGFloat = 28
    var color: Color = HomeLook.purple

    var body: some View {
        TimelineView(.animation) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius: Double = Double(canvasSize.width) / 2
                let rayCount = 10
                for i in 0..<rayCount {
                    let index = Double(i)
                    let angle: Double = index / Double(rayCount) * 2 * .pi + t * 0.8
                    let wave: Double = 0.5 + 0.5 * sin(t * 3.2 + index * 1.7)
                    let length: Double = radius * (0.55 + 0.45 * wave)
                    let inner: Double = radius * 0.16
                    let dx: Double = cos(angle)
                    let dy: Double = sin(angle)
                    var ray = Path()
                    ray.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
                    ray.addLine(to: CGPoint(x: center.x + dx * length, y: center.y + dy * length))
                    context.stroke(ray, with: .color(color),
                                   style: StrokeStyle(lineWidth: canvasSize.width * 0.12, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Loading")
    }
}

// MARK: - CTR gauge (1% to 20%+, yellow to green, 7% target)

struct CTRGauge: View {
    let ctr: Double   // 0...1

    private static let low = 0.01, high = 0.20, target = 0.07
    private static let yellow = Color(red: 0.96, green: 0.76, blue: 0.20)   // #F5C233
    private static let lime   = Color(red: 0.62, green: 0.80, blue: 0.25)   // #9ECC40
    private static let green  = Color(red: 0.122, green: 0.659, blue: 0.400) // #1FA866

    /// Where a CTR sits on the bar, 0...1
    private static func spot(_ value: Double) -> CGFloat {
        CGFloat((min(max(value, low), high) - low) / (high - low))
    }

    private var isGood: Bool { ctr >= Self.target }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [Self.yellow, Self.lime, Self.green],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 10)

                    // 7% target line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HomeLook.ink)
                        .frame(width: 2, height: 20)
                        .offset(x: w * Self.spot(Self.target) - 1)

                    // This video
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(HomeLook.ink, lineWidth: 3))
                        .offset(x: min(max(w * Self.spot(ctr) - 10, 0), w - 20))
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .topLeading) {
                    Text("1%")
                    Text("7% goal")
                        .fontWeight(.bold)
                        .foregroundColor(HomeLook.ink)
                        .fixedSize()
                        .offset(x: w * Self.spot(Self.target) - 22)
                    Text("20%+")
                        .frame(width: w, alignment: .trailing)
                }
                .font(.system(size: 11))
                .foregroundColor(HomeLook.secondary)
            }
            .frame(height: 14)

            Text(isGood
                 ? "Nice. Aim for 7% or more, and this video is there."
                 : "Aim for 7% or more. Below 7% usually means the title or thumbnail needs work.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isGood ? ReviewLook.goodText : ReviewLook.badText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "Thumbnail CTR %.1f percent. The goal is 7 percent or more.", ctr * 100))
    }
}

// MARK: - Trend line (line + soft fade, no axes)

private struct ReviewTrendChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.0001)
            let inset: CGFloat = 6
            let step = (w - inset * 2) / CGFloat(max(values.count - 1, 1))
            let points = values.enumerated().map { i, v in
                CGPoint(x: inset + CGFloat(i) * step,
                        y: inset + (h - inset * 2) * (1 - CGFloat((v - minV) / range)))
            }

            ZStack {
                Path { p in
                    guard let first = points.first, let last = points.last else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: last.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Kept for other screens that may use them

struct ReviewMetricRow: View {
    let name: String
    let value: String
    let benchmark: String
    let progress: Double
    let isGood: Bool
    let explanation: String
    let isLast: Bool

    private var barColor: Color {
        isGood ? HomeLook.purple : HomeLook.orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(name.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .kerning(0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(benchmark)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isGood ? HomeLook.purpleLight : HomeLook.orange)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemFill)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(max(progress, 0), 1), height: 4)
                }
            }
            .frame(height: 4)
            Text(explanation)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)

        if !isLast {
            Divider().padding(.horizontal, 16)
        }
    }
}

struct ScorecardCell: View {
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(valueColor)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}
