// Models/RetentionDataPoint.swift
import Foundation

struct RetentionDataPoint: Identifiable, Codable {
    let id: UUID
    let elapsedTimeRatio: Double  // 0.0 – 1.0 (position in video)
    let audienceWatchRatio: Double // 0.0 – 1.0 (% still watching)

    init(elapsedTimeRatio: Double, audienceWatchRatio: Double) {
        self.id = UUID()
        self.elapsedTimeRatio = elapsedTimeRatio
        self.audienceWatchRatio = audienceWatchRatio
    }
}

struct VideoDeepAnalysis {
    let video: Video
    let retentionCurve: [RetentionDataPoint]
    let channelAvgCurve: [RetentionDataPoint]

    // Hook segments — derived from first ~15% of retention curve
    var hookSegments: [HookSegment] {
        let hookPoints = retentionCurve.filter { $0.elapsedTimeRatio <= 0.15 }
        guard hookPoints.count >= 2 else { return [] }

        var segments: [HookSegment] = []
        for i in 0..<min(hookPoints.count - 1, 5) {
            let start = hookPoints[i]
            let end = hookPoints[i + 1]
            let label = hookSegmentLabel(index: i)
            segments.append(HookSegment(
                label: label,
                retentionStart: start.audienceWatchRatio,
                retentionEnd: end.audienceWatchRatio
            ))
        }
        return segments
    }

    // Drop-off moments — points where retention drops more than 5% from prior point
    var dropOffPoints: [DropOffPoint] {
        var drops: [DropOffPoint] = []
        for i in 1..<retentionCurve.count {
            let prev = retentionCurve[i - 1]
            let curr = retentionCurve[i]
            let drop = prev.audienceWatchRatio - curr.audienceWatchRatio
            if drop > 0.05 {
                drops.append(DropOffPoint(
                    elapsedTimeRatio: curr.elapsedTimeRatio,
                    dropMagnitude: drop
                ))
            }
        }
        return drops.sorted { $0.dropMagnitude > $1.dropMagnitude }.prefix(3).map { $0 }
    }

    // Biggest single drop in the hook window (0–15%)
    var hookWeakPoint: HookSegment? {
        hookSegments.min(by: { $0.retentionEnd < $1.retentionEnd })
    }

    private func hookSegmentLabel(index: Int) -> String {
        let labels = ["0–3s", "3–6s", "6–9s", "9–12s", "12–15s"]
        return index < labels.count ? labels[index] : "\(index * 3)–\((index + 1) * 3)s"
    }
}

struct HookSegment: Identifiable {
    let id = UUID()
    let label: String
    let retentionStart: Double
    let retentionEnd: Double

    var retention: Double { retentionEnd }

    var status: SegmentStatus {
        if retentionEnd >= 0.80 { return .strong }
        if retentionEnd >= 0.65 { return .warning }
        return .weak
    }
}

struct DropOffPoint: Identifiable {
    let id = UUID()
    let elapsedTimeRatio: Double
    let dropMagnitude: Double

    var severity: DropSeverity {
        if dropMagnitude >= 0.12 { return .critical }
        if dropMagnitude >= 0.07 { return .warning }
        return .minor
    }
}

enum SegmentStatus {
    case strong, warning, weak

    var color: String {
        switch self {
        case .strong:  return "green"
        case .warning: return "yellow"
        case .weak:    return "red"
        }
    }
}

enum DropSeverity {
    case critical, warning, minor
}
