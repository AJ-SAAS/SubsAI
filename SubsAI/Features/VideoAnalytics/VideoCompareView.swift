// Features/VideoAnalytics/VideoCompareView.swift
import SwiftUI

// MARK: - Channel pattern engine
private struct ChannelPattern {
    let topPattern: String
    let bottomPattern: String
    let studyVideo: Video
    let studyReason: String
}

private func analyzePatterns(current: Video, all: [Video]) -> ChannelPattern? {
    let videosWithData = all.filter { $0.analytics != nil }
    guard videosWithData.count >= 3 else { return nil }

    let sorted = videosWithData.sorted {
        ($0.analytics?.retention ?? 0) > ($1.analytics?.retention ?? 0)
    }

    let topCount  = max(1, sorted.count / 3)
    let topVideos = Array(sorted.prefix(topCount))
    let botVideos = Array(sorted.suffix(topCount))

    // MARK: Title pattern detection
    func hasQuestion(_ title: String) -> Bool {
        title.contains("?")
    }
    func hasNumber(_ title: String) -> Bool {
        title.range(of: #"\d"#, options: .regularExpression) != nil
    }
    func hasHowTo(_ title: String) -> Bool {
        let lower = title.lowercased()
        return lower.hasPrefix("how") || lower.hasPrefix("why") || lower.hasPrefix("what")
    }
    func hasHowI(_ title: String) -> Bool {
        let lower = title.lowercased()
        return lower.hasPrefix("how i") || lower.hasPrefix("i tried") || lower.hasPrefix("i built") || lower.hasPrefix("i made")
    }
    func isShortTitle(_ title: String) -> Bool {
        title.count < 50
    }

    // Score top vs bottom title patterns
    let topQuestions  = topVideos.filter { hasQuestion($0.title) }.count
    let topNumbers    = topVideos.filter { hasNumber($0.title) }.count
    let topHowTo      = topVideos.filter { hasHowTo($0.title) }.count
    let topHowI       = topVideos.filter { hasHowI($0.title) }.count
    let topShort      = topVideos.filter { isShortTitle($0.title) }.count

    let botQuestions  = botVideos.filter { hasQuestion($0.title) }.count
    let botNumbers    = botVideos.filter { hasNumber($0.title) }.count
    let botHowTo      = botVideos.filter { hasHowTo($0.title) }.count
    let botHowI       = botVideos.filter { hasHowI($0.title) }.count
    let botShort      = botVideos.filter { isShortTitle($0.title) }.count

    // Derive top pattern sentence
    var topPattern = ""
    if topQuestions > botQuestions && topQuestions >= topCount / 2 {
        topPattern = "Your best-retained videos tend to have questions in the title — they create curiosity before the viewer even clicks."
    } else if topNumbers > botNumbers && topNumbers >= topCount / 2 {
        topPattern = "Your best-retained videos tend to have numbers in the title — specific, concrete promises outperform vague ones on your channel."
    } else if topHowTo > botHowTo && topHowTo >= topCount / 2 {
        topPattern = "Your best-retained videos lead with \"How\" or \"Why\" in the title — your audience responds to direct, instructional framing."
    } else if topShort > botShort {
        topPattern = "Your best-retained videos have shorter, more direct titles — under 50 characters tends to outperform on your channel."
    } else {
        let avgTopRetention = topVideos.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(topVideos.count)
        topPattern = "Your top \(topVideos.count) videos average \(Int(avgTopRetention * 100))% retention. Study their opening 30 seconds — that's where the pattern lives."
    }

    // Derive bottom pattern sentence
    var bottomPattern = ""
    if botHowI > topHowI && botHowI >= botCount(botVideos) / 2 {
        bottomPattern = "Your weakest videos tend to start with \"How I\" or \"I tried\" — first-person process titles underperform on your channel compared to outcome-focused ones."
    } else if botNumbers > topNumbers {
        bottomPattern = "Your lower-performing videos use fewer numbers in titles — your audience may respond better to specific, quantified promises."
    } else if !botVideos.isEmpty {
        let avgBotRetention = botVideos.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(botVideos.count)
        bottomPattern = "Your bottom \(botVideos.count) videos average \(Int(avgBotRetention * 100))% retention — significantly below your channel average."
    }

    // MARK: Study video
    let avgRetention = videosWithData.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(videosWithData.count)

    let studyVideo = sorted.first(where: { $0.id != current.id }) ?? sorted[0]
    let studyRetention = Int((studyVideo.analytics?.retention ?? 0) * 100)
    let studyReason = "\(studyRetention)% retention vs your \(Int(avgRetention * 100))% channel average — the biggest gap in your library"

    return ChannelPattern(
        topPattern: topPattern,
        bottomPattern: bottomPattern,
        studyVideo: studyVideo,
        studyReason: studyReason
    )
}

private func botCount(_ videos: [Video]) -> Int {
    max(videos.count, 1)
}

// MARK: - VideoCompareView
struct VideoCompareView: View {
    let currentVideo: Video
    let allVideos: [Video]

    private var videosWithData: [Video] {
        allVideos.filter { $0.analytics != nil }
    }

    private var sortedVideos: [Video] {
        videosWithData
            .sorted { ($0.analytics?.retention ?? 0) > ($1.analytics?.retention ?? 0) }
            .prefix(6)
            .map { $0 }
    }

    private var avgRetention: Double {
        let vals = videosWithData.compactMap { $0.analytics?.retention }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var pattern: ChannelPattern? {
        analyzePatterns(current: currentVideo, all: allVideos)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                if sortedVideos.isEmpty {
                    emptyState
                } else {

                    if let p = pattern {
                        sectionLabel("What your data says")
                            .padding(.bottom, 2)
                        autoInsightSection(p)
                    }

                    sectionLabel("Your videos · sorted by retention")
                        .padding(.bottom, 2)

                    VStack(spacing: 10) {
                        ForEach(sortedVideos) { video in
                            VideoCompareRow(
                                video: video,
                                isCurrentVideo: video.id == currentVideo.id,
                                avgRetention: avgRetention
                            )
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Auto insight section
    @ViewBuilder
    private func autoInsightSection(_ p: ChannelPattern) -> some View {

        InsightBlock(
            title: "What your best videos have in common",
            content: p.topPattern,
            accentColor: .green
        )

        if !p.bottomPattern.isEmpty {
            InsightBlock(
                title: "What your weakest videos have in common",
                content: p.bottomPattern,
                accentColor: .orange
            )
        }

        // Updated Study Card
        VStack(alignment: .leading, spacing: 10) {

            Text("Study this video")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.accent)

            Text("\"\(p.studyVideo.title)\"")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(p.studyReason)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)

            Text("Watch the first 60 seconds of this video back-to-back with your current one. The difference in how they open is almost always where the retention gap comes from.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                CoachReviewView(video: p.studyVideo, allVideos: allVideos)
            } label: {
                Text("Review in Coach →")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 0.5)
        )

        if avgRetention > 0 {
            InsightBlock(
                title: "Your channel average",
                content: "You retain \(Int(avgRetention * 100))% of viewers on average. Any video above this is worth studying and repeating. Any video below it is worth understanding before you make another one like it.",
                accentColor: AppTheme.accent
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash")
                .font(.system(size: 30))
                .foregroundColor(AppTheme.textTertiary)
            Text("Not enough videos to compare yet")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // ✅ UPDATED SECTION LABEL
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundColor(AppTheme.textPrimary)
    }
}

// MARK: - VideoCompareRow
struct VideoCompareRow: View {
    let video: Video
    let isCurrentVideo: Bool
    var avgRetention: Double = 0

    private var retention: Double { video.analytics?.retention ?? 0 }
    private var ctr: Double { video.analytics?.ctr ?? 0 }
    private var retPct: Int { Int(retention * 100) }

    private var scoreColor: Color {
        if retPct >= 45 { return .green }
        if retPct >= 30 { return .yellow }
        return .red
    }

    private var vsAvgText: String? {
        guard avgRetention > 0 else { return nil }
        let diff = retention - avgRetention
        let diffPct = Int(abs(diff) * 100)
        if diffPct < 2 { return "At your average" }
        return diff > 0 ? "+\(diffPct)% above avg" : "\(diffPct)% below avg"
    }

    private var vsAvgColor: Color {
        guard avgRetention > 0 else { return AppTheme.textTertiary }
        return retention >= avgRetention ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if isCurrentVideo {
                        Text("This video")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(6)
                    }
                    Text(video.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(retPct)%")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(scoreColor)
                    Text("retention")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textTertiary)
                    if let vsAvg = vsAvgText {
                        Text(vsAvg)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(vsAvgColor)
                    }
                }
            }

            VStack(spacing: 6) {
                CompareBar(
                    label: "CTR",
                    value: min(ctr / 0.10, 1.0),
                    displayValue: String(format: "%.1f%%", ctr * 100),
                    color: AppTheme.accent
                )
                CompareBar(
                    label: "Retention",
                    value: min(retention / 0.60, 1.0),
                    displayValue: String(format: "%.0f%%", retention * 100),
                    color: scoreColor
                )
            }
        }
        .padding(14)
        .background(
            isCurrentVideo
                ? AppTheme.accent.opacity(0.06)
                : AppTheme.cardBackground
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentVideo
                        ? AppTheme.accent.opacity(0.3)
                        : AppTheme.borderSubtle,
                    lineWidth: isCurrentVideo ? 1 : 0.5
                )
        )
    }
}

// MARK: - CompareBar
struct CompareBar: View {
    let label: String
    let value: Double
    let displayValue: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(max(value, 0), 1),
                            height: 4
                        )
                        .animation(.easeOut(duration: 0.5), value: value)
                }
                .frame(height: 4)
                .padding(.top, 5)
            }
            .frame(height: 14)

            Text(displayValue)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
