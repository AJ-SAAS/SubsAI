// Features/VideoAnalytics/RetentionCurveView.swift
import SwiftUI

struct RetentionCurveView: View {
    let analysis: VideoDeepAnalysis

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Curve chart
                sectionLabel("Viewer retention · full video")

                RetentionChartView(
                    curve: analysis.retentionCurve,
                    channelAvg: analysis.channelAvgCurve,
                    dropOffs: analysis.dropOffPoints
                )
                .frame(height: 220)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)

                // Drop-off pills
                dropOffPills

                // MARK: - Drop-off diagnosis
                sectionLabel("Drop-off diagnosis")

                ForEach(Array(analysis.dropOffPoints.enumerated()), id: \.element.id) { index, drop in
                    InsightBlock(
                        title: dropOffTitle(drop, index: index),
                        content: dropOffBody(drop, index: index),
                        accentColor: dropOffColor(drop)
                    )
                }

                // MARK: - Pattern insight
                sectionLabel("Pattern vs your other videos")

                InsightBlock(
                    title: "What works for you",
                    content: "Your 3 best-retaining videos all share one thing: a conflict introduced before minute 1. \"Here's what almost went wrong\" keeps people watching more than any other pattern in your library.",
                    accentColor: .green
                )

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Drop-off pills
    private var dropOffPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(analysis.dropOffPoints) { drop in
                    Text(dropPillLabel(drop))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(dropOffColor(drop).opacity(0.12))
                        .foregroundColor(dropOffColor(drop))
                        .cornerRadius(20)
                }

                Text("Strong 0–2 min")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .foregroundColor(.green)
                    .cornerRadius(20)
            }
        }
    }

    // MARK: - Helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .kerning(0.8)
    }

    private func dropPillLabel(_ drop: DropOffPoint) -> String {
        let pct = Int(drop.elapsedTimeRatio * 100)
        switch drop.severity {
        case .critical: return "Big drop at \(pct)%"
        case .warning:  return "Drop at \(pct)%"
        case .minor:    return "Slow at \(pct)%"
        }
    }

    private func dropOffTitle(_ drop: DropOffPoint, index: Int) -> String {
        let pct = Int(drop.elapsedTimeRatio * 100)
        let causes = ["topic switch", "no re-hook", "pacing dip"]
        let cause = index < causes.count ? causes[index] : "drop-off"
        return "Drop at \(pct)% — \(cause)"
    }

    private func dropOffBody(_ drop: DropOffPoint, index: Int) -> String {
        let bodies = [
            "You likely shifted topics or introduced new information without a bridge. Viewers came for the opening promise — make sure you deliver on it before pivoting.",
            "Long-form videos need a re-hook every 3–4 minutes. A single line — \"but here's where it gets interesting\" — can hold 80% of viewers who would have left.",
            "The pacing slowed here. Cut to the next key point faster, or add a visual change to reset attention."
        ]
        return index < bodies.count ? bodies[index] : "Viewers dropped here — review what was happening at this point in the video."
    }

    private func dropOffColor(_ drop: DropOffPoint) -> Color {
        switch drop.severity {
        case .critical: return .red
        case .warning:  return .orange
        case .minor:    return .yellow
        }
    }
}

// MARK: - Retention Chart (pure SwiftUI, no external libs)
struct RetentionChartView: View {
    let curve: [RetentionDataPoint]
    let channelAvg: [RetentionDataPoint]
    let dropOffs: [DropOffPoint]

    var body: some View {
        VStack(spacing: 8) {
            // Legend
            HStack(spacing: 16) {
                legendItem(color: .purple, label: "This video")
                legendItem(color: .gray.opacity(0.5), label: "Your avg")
                Spacer()
            }
            .font(.caption)

            // Chart
            GeometryReader { geo in
                ZStack {
                    // Grid lines
                    ForEach([0.25, 0.50, 0.75, 1.0], id: \.self) { level in
                        let y = geo.size.height * (1 - level)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    }

                    // Channel avg line (dashed)
                    curvePath(points: channelAvg, in: geo)
                        .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Fill under this video's curve
                    curveAreaPath(points: curve, in: geo)
                        .fill(Color.purple.opacity(0.08))

                    // This video's curve
                    curvePath(points: curve, in: geo)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    // Drop-off markers
                    ForEach(dropOffs) { drop in
                        let x = geo.size.width * drop.elapsedTimeRatio
                        let y = yPosition(for: drop.elapsedTimeRatio, in: geo)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }

            // X axis labels
            HStack {
                Text("0%").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("50%").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("100%").font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundColor(.secondary)
        }
    }

    private func curvePath(points: [RetentionDataPoint], in geo: GeometryProxy) -> Path {
        Path { path in
            guard !points.isEmpty else { return }
            let sorted = points.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
            let first = sorted[0]
            path.move(to: CGPoint(
                x: geo.size.width * first.elapsedTimeRatio,
                y: geo.size.height * (1 - first.audienceWatchRatio)
            ))
            for point in sorted.dropFirst() {
                path.addLine(to: CGPoint(
                    x: geo.size.width * point.elapsedTimeRatio,
                    y: geo.size.height * (1 - point.audienceWatchRatio)
                ))
            }
        }
    }

    private func curveAreaPath(points: [RetentionDataPoint], in geo: GeometryProxy) -> Path {
        Path { path in
            guard !points.isEmpty else { return }
            let sorted = points.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
            path.move(to: CGPoint(x: 0, y: geo.size.height))
            for point in sorted {
                path.addLine(to: CGPoint(
                    x: geo.size.width * point.elapsedTimeRatio,
                    y: geo.size.height * (1 - point.audienceWatchRatio)
                ))
            }
            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
            path.closeSubpath()
        }
    }

    private func yPosition(for ratio: Double, in geo: GeometryProxy) -> CGFloat {
        let sorted = curve.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
        let closest = sorted.min(by: { abs($0.elapsedTimeRatio - ratio) < abs($1.elapsedTimeRatio - ratio) })
        let retention = closest?.audienceWatchRatio ?? 0.5
        return geo.size.height * (1 - retention)
    }
}
