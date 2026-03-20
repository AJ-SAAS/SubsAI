// Models/ChannelIntelligence.swift
import Foundation

// MARK: - Growth Quality Score
struct GrowthQualityScore {
    let subsPerThousandViews: Double
    let valuePerImpression: Double
    let retentionStrength: Double
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
        let enriched = videos.filter { $0.analytics != nil && $0.views > 0 }
        guard !enriched.isEmpty else {
            return GrowthQualityScore(
                subsPerThousandViews: 0,
                valuePerImpression: 0,
                retentionStrength: 0,
                composite: 0,
                grade: .c
            )
        }

        let avgRetention = enriched.compactMap { $0.analytics?.retention }
            .reduce(0, +) / Double(enriched.count)

        let avgCTR = enriched.compactMap { $0.analytics?.ctr }
            .reduce(0, +) / Double(enriched.count)

        let avgDuration = enriched.compactMap {
            Double($0.analytics?.averageViewDuration ?? 0)
        }.reduce(0, +) / Double(enriched.count)

        let estimatedSubRate  = avgRetention * avgCTR * 8.0
        let subsPerK          = estimatedSubRate * 10.0
        let valuePerImpression = avgCTR * avgRetention * (avgDuration / 60.0)

        let ctrScore = min(avgCTR / 0.07, 1.0) * 3.0
        let retScore = min(avgRetention / 0.50, 1.0) * 4.0
        let subScore = min(subsPerK / 1.0, 1.0) * 3.0
        let composite = ctrScore + retScore + subScore

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
            valuePerImpression: valuePerImpression,
            retentionStrength: avgRetention,
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
        let enriched = videos.filter { $0.analytics != nil && $0.views > 100 }
        guard enriched.count >= 3 else { return [] }

        let avgCTR = enriched.compactMap { $0.analytics?.ctr }
            .reduce(0, +) / Double(enriched.count)

        // Pattern 1 — challenge / story format
        let challengeKeywords = ["i tried", "i spent", "i did", "days", "hours",
                                  "challenge", "for a week", "for a month"]
        let challengeVideos = enriched.filter { v in
            challengeKeywords.contains { v.title.lowercased().contains($0) }
        }
        let nonChallengeVideos = enriched.filter { v in
            !challengeKeywords.contains { v.title.lowercased().contains($0) }
        }

        if challengeVideos.count >= 2 && !nonChallengeVideos.isEmpty {
            let challengeCTR = challengeVideos.compactMap { $0.analytics?.ctr }
                .reduce(0, +) / Double(challengeVideos.count)
            let otherCTR = nonChallengeVideos.compactMap { $0.analytics?.ctr }
                .reduce(0, +) / Double(nonChallengeVideos.count)
            if otherCTR > 0 {
                let lift = challengeCTR / otherCTR
                if lift > 1.2 {
                    patterns.append(WinningPattern(
                        title: "Challenge / story format",
                        description: "\(challengeVideos.count) of your videos use personal challenge framing — these consistently outperform your others",
                        liftText: String(format: "+%.1fx CTR", lift),
                        liftIsPositive: true,
                        icon: "bolt.fill"
                    ))
                }
            }
        }

        // Pattern 2 — numbers in titles
        let numberVideos = enriched.filter { v in
            v.title.range(of: #"\d+"#, options: .regularExpression) != nil
        }
        let noNumberVideos = enriched.filter { v in
            v.title.range(of: #"\d+"#, options: .regularExpression) == nil
        }

        if numberVideos.count >= 2 && !noNumberVideos.isEmpty {
            let numCTR   = numberVideos.compactMap { $0.analytics?.ctr }
                .reduce(0, +) / Double(numberVideos.count)
            let noNumCTR = noNumberVideos.compactMap { $0.analytics?.ctr }
                .reduce(0, +) / Double(noNumberVideos.count)
            if noNumCTR > 0 {
                let lift = numCTR / noNumCTR
                if lift > 1.15 {
                    patterns.append(WinningPattern(
                        title: "Numbers in titles",
                        description: "Titles with specific numbers get \(String(format: "%.0f", (lift - 1) * 100))% more clicks on your channel",
                        liftText: String(format: "+%.0f%% CTR", (lift - 1) * 100),
                        liftIsPositive: true,
                        icon: "number"
                    ))
                }
            }
        }

        // Pattern 3 — video length
        let shortVideos = enriched.filter { v in
            guard let a = v.analytics, a.retention > 0 else { return false }
            return Double(a.averageViewDuration) / a.retention < 600
        }
        let longVideos = enriched.filter { v in
            guard let a = v.analytics, a.retention > 0 else { return false }
            return Double(a.averageViewDuration) / a.retention >= 600
        }

        if shortVideos.count >= 2 && longVideos.count >= 2 {
            let shortRet = shortVideos.compactMap { $0.analytics?.retention }
                .reduce(0, +) / Double(shortVideos.count)
            let longRet  = longVideos.compactMap { $0.analytics?.retention }
                .reduce(0, +) / Double(longVideos.count)

            if shortRet > longRet * 1.1 {
                patterns.append(WinningPattern(
                    title: "Shorter videos retain more",
                    description: "Videos under 10 min average \(String(format: "%.0f", shortRet * 100))% retention vs \(String(format: "%.0f", longRet * 100))% for longer ones",
                    liftText: String(format: "+%.0f%% retention", (shortRet - longRet) * 100),
                    liftIsPositive: true,
                    icon: "clock.fill"
                ))
            } else if longRet > shortRet * 1.1 {
                patterns.append(WinningPattern(
                    title: "Longer videos perform better",
                    description: "Your audience prefers depth — videos over 10 min average \(String(format: "%.0f", longRet * 100))% retention",
                    liftText: String(format: "+%.0f%% retention", (longRet - shortRet) * 100),
                    liftIsPositive: true,
                    icon: "clock.fill"
                ))
            }
        }

        // Pattern 4 — best posting day
        let calendar = Calendar.current
        let dayGroups = Dictionary(grouping: enriched) { v in
            calendar.component(.weekday, from: v.publishedAt)
        }
        var bestDay: (name: String, ctr: Double)?
        for (day, dayVideos) in dayGroups where dayVideos.count >= 2 {
            let dayCTR = dayVideos.compactMap { $0.analytics?.ctr }
                .reduce(0, +) / Double(dayVideos.count)
            if dayCTR > avgCTR * 1.2 {
                let dayName = calendar.weekdaySymbols[day - 1]
                if bestDay == nil || dayCTR > bestDay!.ctr {
                    bestDay = (dayName, dayCTR)
                }
            }
        }
        if let best = bestDay {
            patterns.append(WinningPattern(
                title: "\(best.name) is your best posting day",
                description: "Videos posted on \(best.name) consistently outperform your weekly average CTR",
                liftText: String(format: "%.1f%% CTR", best.ctr * 100),
                liftIsPositive: true,
                icon: "calendar"
            ))
        }

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
            return "This format consistently works. Study the hook, format, and title — then repeat it."
        case .oneOff:
            return "This outperformed your average but doesn't fit a clear repeatable pattern. Don't over-index on it."
        case .avoid:
            return "This format underperforms across CTR, retention, and views. Don't repeat it without major changes."
        }
    }

    static func compute(
        for video: Video,
        channelAvgCTR: Double,
        channelAvgRetention: Double
    ) -> ReplicationScore {
        guard let analytics = video.analytics else { return .oneOff }

        let ctrRatio       = channelAvgCTR > 0
            ? analytics.ctr / channelAvgCTR : 1.0
        let retentionRatio = channelAvgRetention > 0
            ? analytics.retention / channelAvgRetention : 1.0
        let viewsRatio     = analytics.expectedViews > 0
            ? Double(video.views) / Double(analytics.expectedViews) : 1.0

        let score = (ctrRatio * 0.4) + (retentionRatio * 0.4) + (viewsRatio * 0.2)

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
        let enriched = videos.filter { $0.analytics != nil }
        guard enriched.count >= 3 else { return [] }

        let avgRetention = enriched.compactMap { $0.analytics?.retention }
            .reduce(0, +) / Double(enriched.count)
        let avgCTR = enriched.compactMap { $0.analytics?.ctr }
            .reduce(0, +) / Double(enriched.count)
        let avgDuration = enriched.compactMap {
            Double($0.analytics?.averageViewDuration ?? 0)
        }.reduce(0, +) / Double(enriched.count)

        // Weak hooks
        if avgDuration < 45 {
            weaknesses.append(StructuralWeakness(
                severity: .critical,
                title: "Hooks are losing viewers fast",
                detail: "Average watch duration is \(Int(avgDuration))s — most viewers leave before your content starts. Open with the payoff, not the setup."
            ))
        }

        // Low CTR
        if avgCTR < 0.04 {
            weaknesses.append(StructuralWeakness(
                severity: .critical,
                title: "Thumbnails and titles aren't converting",
                detail: "Channel average CTR is \(String(format: "%.1f", avgCTR * 100))% — well below the 4–7% benchmark. This is your single biggest growth lever right now."
            ))
        } else if avgCTR < 0.06 {
            weaknesses.append(StructuralWeakness(
                severity: .warning,
                title: "CTR has room to improve",
                detail: "Average \(String(format: "%.1f", avgCTR * 100))% CTR. One thumbnail iteration could meaningfully increase your reach."
            ))
        }

        // Low retention
        if avgRetention < 0.30 {
            weaknesses.append(StructuralWeakness(
                severity: .critical,
                title: "Mid-video drop-off is a consistent pattern",
                detail: "Average retention of \(String(format: "%.0f", avgRetention * 100))% suggests a structural pacing issue. Add a re-hook every 3–4 minutes."
            ))
        } else if avgRetention < 0.40 {
            weaknesses.append(StructuralWeakness(
                severity: .warning,
                title: "Retention drops before your best content",
                detail: "At \(String(format: "%.0f", avgRetention * 100))% average retention, viewers are leaving before the payoff. Front-load more value in the first half."
            ))
        }

        // Inconsistent results
        let ctrValues = enriched.compactMap { $0.analytics?.ctr }
        if ctrValues.count >= 4 {
            let mean     = ctrValues.reduce(0, +) / Double(ctrValues.count)
            let variance = ctrValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(ctrValues.count)
            let stdDev   = sqrt(variance)
            let cv       = mean > 0 ? stdDev / mean : 0
            if cv > 0.6 {
                weaknesses.append(StructuralWeakness(
                    severity: .warning,
                    title: "Inconsistent results across videos",
                    detail: "Your CTR varies wildly between videos. You haven't found a repeatable formula yet — focus on what your top 3 videos have in common."
                ))
            }
        }

        return Array(weaknesses.prefix(3))
    }
}

// MARK: - Full Intelligence Report
struct ChannelIntelligenceReport {
    let growthQualityScore: GrowthQualityScore
    let winningPatterns: [WinningPattern]
    let structuralWeaknesses: [StructuralWeakness]
    let channelAvgCTR: Double
    let channelAvgRetention: Double

    static func generate(from videos: [Video]) -> ChannelIntelligenceReport {
        let enriched = videos.filter { $0.analytics != nil }
        let avgCTR = enriched.compactMap { $0.analytics?.ctr }
            .reduce(0, +) / Double(max(enriched.count, 1))
        let avgRetention = enriched.compactMap { $0.analytics?.retention }
            .reduce(0, +) / Double(max(enriched.count, 1))

        return ChannelIntelligenceReport(
            growthQualityScore:   GrowthQualityScore.compute(from: videos),
            winningPatterns:      WinningPattern.detect(from: videos),
            structuralWeaknesses: StructuralWeakness.detect(from: videos),
            channelAvgCTR:        avgCTR,
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
