// Models/ChannelIntelligence.swift
// Channel-wide patterns. Real numbers only:
//  - Subs per 1K views = total subs / total views (not an estimate from CTR)
//  - CTR is only used for videos where YouTube gave us a real CTR (hasCTR)
//  - Tiny videos (under 100 views) are left out of averages, so luck can't skew them
import Foundation

private extension Array where Element == Video {
    /// Videos with analytics and at least `minViews` views
    func withData(minViews: Int = 100) -> [Video] {
        filter { $0.analytics != nil && $0.views >= minViews }
    }
    /// Only videos with a real CTR from YouTube
    var withCTR: [Video] { filter { $0.analytics?.hasCTR ?? false } }
}

/// Impressions-weighted CTR when we have impressions, plain average otherwise
private func averageCTR(_ videos: [Video]) -> Double? {
    let known = videos.withCTR
    guard !known.isEmpty else { return nil }
    let weighted = known.compactMap { v -> (Double, Double)? in
        guard let a = v.analytics, let imp = a.impressions, imp > 0 else { return nil }
        return (a.ctr * imp, imp)
    }
    if weighted.count == known.count {
        let totalImp = weighted.map(\.1).reduce(0, +)
        if totalImp > 0 { return weighted.map(\.0).reduce(0, +) / totalImp }
    }
    return known.compactMap { $0.analytics?.ctr }.reduce(0, +) / Double(known.count)
}

// MARK: - Growth Quality Score
struct GrowthQualityScore {
    /// Real: all new subs / all views x 1000
    let subsPerThousandViews: Double
    /// Average watch time per view, in minutes (views-weighted)
    let valuePerImpression: Double
    /// Average % of a video people watch (views-weighted)
    let retentionStrength: Double
    /// Channel CTR, nil until YouTube's reach reports arrive
    let channelCTR: Double?
    let composite: Double
    let grade: Grade

    enum Grade: String {
        case aPlus = "A+"
        case a     = "A"
        case bPlus = "B+"
        case b     = "B"
        case cPlus = "C+"
        case c     = "C"
    }

    static func compute(from videos: [Video]) -> GrowthQualityScore {
        let enriched = videos.withData()
        let totalViews = enriched.map { Double($0.views) }.reduce(0, +)
        guard !enriched.isEmpty, totalViews > 0 else {
            return GrowthQualityScore(subsPerThousandViews: 0, valuePerImpression: 0,
                                      retentionStrength: 0, channelCTR: nil, composite: 0, grade: .c)
        }

        let totalSubs = enriched.map { Double($0.analytics?.subscribersGained ?? 0) }.reduce(0, +)
        let subsPerK = totalSubs / totalViews * 1000

        let retention = enriched.map { ($0.analytics?.retention ?? 0) * Double($0.views) }.reduce(0, +) / totalViews
        let watchMinutes = enriched.map { Double($0.analytics?.averageViewDuration ?? 0) * Double($0.views) }
            .reduce(0, +) / totalViews / 60

        let ctr = averageCTR(enriched)

        // Score out of 10. CTR only counts when we really have it.
        let retScore = min(retention / 0.50, 1.0) * 4.0
        let subScore = min(subsPerK / 1.0, 1.0) * 3.0
        let composite: Double
        if let ctr {
            composite = retScore + subScore + min(ctr / 0.07, 1.0) * 3.0
        } else {
            composite = (retScore + subScore) / 7.0 * 10.0
        }

        let grade: Grade
        switch composite {
        case 8.5...: grade = .aPlus
        case 7.5...: grade = .a
        case 6.5...: grade = .bPlus
        case 5.0...: grade = .b
        case 3.5...: grade = .cPlus
        default:     grade = .c
        }

        return GrowthQualityScore(
            subsPerThousandViews: subsPerK,
            valuePerImpression: watchMinutes,
            retentionStrength: retention,
            channelCTR: ctr,
            composite: composite,
            grade: grade
        )
    }
}

// MARK: - Winning Pattern
struct WinningPattern: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let liftText: String
    let liftIsPositive: Bool
    let icon: String

    static func detect(from videos: [Video]) -> [WinningPattern] {
        var patterns: [WinningPattern] = []
        let enriched = videos.withData()
        guard enriched.count >= 3 else { return [] }

        // Title patterns need real CTR
        let ctrVideos = enriched.withCTR

        func avgCTR(_ list: [Video]) -> Double {
            list.compactMap { $0.analytics?.ctr }.reduce(0, +) / Double(max(list.count, 1))
        }

        // Pattern 1: challenge / story format
        let challengeKeywords = ["i tried", "i spent", "i did", "days", "hours",
                                 "challenge", "for a week", "for a month"]
        let isChallenge: (Video) -> Bool = { v in challengeKeywords.contains { v.title.lowercased().contains($0) } }
        let challengeVideos = ctrVideos.filter(isChallenge)
        let otherVideos = ctrVideos.filter { !isChallenge($0) }
        if challengeVideos.count >= 2, otherVideos.count >= 2 {
            let lift = avgCTR(challengeVideos) / max(avgCTR(otherVideos), 0.0001)
            if lift > 1.2 {
                patterns.append(WinningPattern(
                    title: "Challenge and story titles",
                    description: "\(challengeVideos.count) of your videos use \"I tried\" or challenge titles. They get more clicks than your others.",
                    liftText: String(format: "+%.1fx CTR", lift),
                    liftIsPositive: true,
                    icon: "bolt.fill"
                ))
            }
        }

        // Pattern 2: numbers in titles
        let hasNumber: (Video) -> Bool = { $0.title.range(of: #"\d+"#, options: .regularExpression) != nil }
        let numberVideos = ctrVideos.filter(hasNumber)
        let noNumberVideos = ctrVideos.filter { !hasNumber($0) }
        if numberVideos.count >= 2, noNumberVideos.count >= 2 {
            let lift = avgCTR(numberVideos) / max(avgCTR(noNumberVideos), 0.0001)
            if lift > 1.15 {
                patterns.append(WinningPattern(
                    title: "Numbers in titles",
                    description: "Titles with a number get \(String(format: "%.0f", (lift - 1) * 100))% more clicks on your channel.",
                    liftText: String(format: "+%.0f%% CTR", (lift - 1) * 100),
                    liftIsPositive: true,
                    icon: "number"
                ))
            }
        }

        // Pattern 3: video length (real % watched, no CTR needed)
        func length(_ v: Video) -> Double? {
            guard let a = v.analytics, a.retention > 0 else { return nil }
            return Double(a.averageViewDuration) / a.retention
        }
        let shortVideos = enriched.filter { (length($0) ?? 0) > 0 && (length($0) ?? 0) < 600 }
        let longVideos = enriched.filter { (length($0) ?? 0) >= 600 }
        if shortVideos.count >= 2 && longVideos.count >= 2 {
            let shortRet = shortVideos.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(shortVideos.count)
            let longRet = longVideos.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(longVideos.count)
            if shortRet > longRet * 1.1 {
                patterns.append(WinningPattern(
                    title: "Shorter videos keep people watching",
                    description: "Videos under 10 min: people watch \(String(format: "%.0f", shortRet * 100))%. Longer ones: \(String(format: "%.0f", longRet * 100))%.",
                    liftText: String(format: "+%.0f%% watched", (shortRet - longRet) * 100),
                    liftIsPositive: true,
                    icon: "clock.fill"
                ))
            } else if longRet > shortRet * 1.1 {
                patterns.append(WinningPattern(
                    title: "Longer videos do better",
                    description: "Your viewers like depth. Videos over 10 min: people watch \(String(format: "%.0f", longRet * 100))%.",
                    liftText: String(format: "+%.0f%% watched", (longRet - shortRet) * 100),
                    liftIsPositive: true,
                    icon: "clock.fill"
                ))
            }
        }

        // Best posting day is NOT a pattern here. It has its own card ("When should you post?"),
        // worked out in one place (CoachViewModel.analyzePostingTimes) so the app never
        // shows two different "best days".

        return patterns
    }
}

// MARK: - Replication Score
enum ReplicationScore: String {
    case replicate = "Replicate"
    case oneOff    = "One-off"
    case avoid     = "Avoid"

    var icon: String {
        switch self {
        case .replicate: return "arrow.triangle.2.circlepath"
        case .oneOff:    return "exclamationmark.circle"
        case .avoid:     return "xmark.circle"
        }
    }

    var explanation: String {
        switch self {
        case .replicate:
            return "This format works. Study the hook, format and title, then do it again."
        case .oneOff:
            return "This beat your average, but doesn't fit a clear pattern. Don't copy it too closely."
        case .avoid:
            return "This format did worse on clicks, watch time and views. Change it a lot before trying again."
        }
    }

    static func compute(
        for video: Video,
        channelAvgCTR: Double,
        channelAvgRetention: Double
    ) -> ReplicationScore {
        guard let analytics = video.analytics else { return .oneOff }
        // Tiny videos can't prove anything either way
        guard video.views >= 100 else { return .oneOff }

        // CTR only counts when both this video and the channel have real CTR
        let ctrRatio = (analytics.hasCTR && channelAvgCTR > 0) ? analytics.ctr / channelAvgCTR : 1.0
        let retentionRatio = channelAvgRetention > 0 ? analytics.retention / channelAvgRetention : 1.0
        // expectedViews = the channel's usual (median) views
        let viewsRatio = analytics.expectedViews > 0
            ? min(Double(video.views) / Double(analytics.expectedViews), 3.0) : 1.0

        let score = (ctrRatio * 0.3) + (retentionRatio * 0.3) + (viewsRatio * 0.4)

        if score >= 1.25      { return .replicate }
        else if score >= 0.75 { return .oneOff }
        else                  { return .avoid }
    }
}

// MARK: - Structural Weakness
struct StructuralWeakness: Identifiable {
    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String

    enum Severity {
        case critical, warning, info
    }

    static func detect(from videos: [Video]) -> [StructuralWeakness] {
        var weaknesses: [StructuralWeakness] = []
        let enriched = videos.withData()
        guard enriched.count >= 3 else { return [] }

        let avgRetention = enriched.compactMap { $0.analytics?.retention }.reduce(0, +) / Double(enriched.count)
        let avgDuration = enriched.map { Double($0.analytics?.averageViewDuration ?? 0) }.reduce(0, +) / Double(enriched.count)

        if avgDuration < 45 {
            weaknesses.append(StructuralWeakness(
                severity: .critical,
                title: "People leave fast",
                detail: "People watch \(Int(avgDuration)) seconds on average. Open with the best part, not the setup."
            ))
        }

        // CTR checks only with real CTR on 3+ videos
        if enriched.withCTR.count >= 3, let avgCTR = averageCTR(enriched) {
            if avgCTR < 0.03 {
                weaknesses.append(StructuralWeakness(
                    severity: .critical,
                    title: "Few people click your thumbnails",
                    detail: "Your CTR is \(String(format: "%.1f", avgCTR * 100))%. Clearer thumbnails and titles are your biggest growth lever right now."
                ))
            } else if avgCTR < 0.045 {
                weaknesses.append(StructuralWeakness(
                    severity: .warning,
                    title: "CTR has room to grow",
                    detail: "Your CTR is \(String(format: "%.1f", avgCTR * 100))%. One better thumbnail style could bring a lot more views."
                ))
            }

            let ctrValues = enriched.withCTR.compactMap { $0.analytics?.ctr }
            if ctrValues.count >= 4 {
                let mean = ctrValues.reduce(0, +) / Double(ctrValues.count)
                let variance = ctrValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(ctrValues.count)
                if mean > 0, sqrt(variance) / mean > 0.6 {
                    weaknesses.append(StructuralWeakness(
                        severity: .warning,
                        title: "Your results jump around a lot",
                        detail: "Clicks change a lot from video to video. Look at what your top 3 videos have in common and repeat it."
                    ))
                }
            }
        }

        if avgRetention < 0.30 {
            weaknesses.append(StructuralWeakness(
                severity: .critical,
                title: "People leave partway through",
                detail: "People watch \(String(format: "%.0f", avgRetention * 100))% of your videos on average. Tease what's coming next every few minutes."
            ))
        } else if avgRetention < 0.40 {
            weaknesses.append(StructuralWeakness(
                severity: .warning,
                title: "People leave before the best part",
                detail: "People watch \(String(format: "%.0f", avgRetention * 100))% on average. Put more value in the first half."
            ))
        }

        return Array(weaknesses.prefix(3))
    }
}

// MARK: - Full Intelligence Report
struct ChannelIntelligenceReport {
    let growthQualityScore: GrowthQualityScore
    let winningPatterns: [WinningPattern]
    let structuralWeaknesses: [StructuralWeakness]
    /// 0 when YouTube hasn't sent CTR yet
    let channelAvgCTR: Double
    let channelAvgRetention: Double

    static func generate(from videos: [Video]) -> ChannelIntelligenceReport {
        let enriched = videos.withData()
        let avgRetention = enriched.compactMap { $0.analytics?.retention }
            .reduce(0, +) / Double(max(enriched.count, 1))

        return ChannelIntelligenceReport(
            growthQualityScore:   GrowthQualityScore.compute(from: videos),
            winningPatterns:      WinningPattern.detect(from: videos),
            structuralWeaknesses: StructuralWeakness.detect(from: videos),
            channelAvgCTR:        averageCTR(enriched) ?? 0,
            channelAvgRetention:  avgRetention
        )
    }

    func replicationScore(for video: Video) -> ReplicationScore {
        ReplicationScore.compute(
            for: video,
            channelAvgCTR: channelAvgCTR,
            channelAvgRetention: channelAvgRetention
        )
    }
}
