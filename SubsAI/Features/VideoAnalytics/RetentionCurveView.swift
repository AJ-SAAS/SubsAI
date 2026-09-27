// Features/VideoAnalytics/RetentionCurveView.swift
// Retention tab: the whole video. Real curve vs your real usual, the real moments
// people left, and the moments people went back to rewatch.
import SwiftUI

struct RetentionCurveView: View {
    @ObservedObject var vm: VideoDeepAnalysisViewModel

    private var insights: VideoInsights? { vm.insights }
    private var drops: [(startSecond: Int, endSecond: Int, lost: Double)] { insights?.drops(limit: 3) ?? [] }
    private var rewatches: [(second: Int, rise: Double)] { insights?.rewatchSpots(limit: 2) ?? [] }

    var body: some View {
        if !vm.hasCurve {
            DeepNoDataCard()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                chartCard
                dropsCard
                if !rewatches.isEmpty { rewatchCard }
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        let duration = insights?.durationSeconds ?? 0
        let watched = vm.video.analytics?.retention ?? 0
        let nearEnd = insights?.nearEndRetention

        return VStack(alignment: .leading, spacing: 14) {
            DeepSectionLabel("WHO KEPT WATCHING")

            HStack(spacing: 16) {
                legend(color: HomeLook.purple, dashed: false, text: "This video")
                if vm.profile != nil {
                    legend(color: Color(white: 0.6), dashed: true, text: "Your usual")
                } else if vm.isLoadingUsual {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading your usual...")
                            .font(.system(size: 12))
                            .foregroundColor(HomeLook.secondary)
                    }
                }
                Spacer()
            }

            DeepRetentionChart(
                curve: insights?.retentionCurve ?? [],
                usual: vm.profile?.averageCurve ?? [],
                dropRatios: duration > 0 ? drops.map { Double($0.startSecond) / Double(duration) } : [],
                rewatchRatios: duration > 0 ? rewatches.map { Double($0.second) / Double(duration) } : []
            )
            .frame(height: 190)

            HStack {
                Text("0:00")
                Spacer()
                Text(DeepFormat.time(duration / 2))
                Spacer()
                Text(DeepFormat.time(duration))
            }
            .font(.system(size: 11))
            .foregroundColor(Color(white: 0.6))

            Rectangle().fill(HomeLook.hairline).frame(height: 1)

            HStack(spacing: 0) {
                stat(value: watched > 0 ? DeepFormat.pct(watched) : "-", label: "Watched on average")
                Rectangle().fill(HomeLook.hairline).frame(width: 1, height: 40)
                stat(value: nearEnd.map { DeepFormat.pct($0) } ?? "-", label: "Made it to the end")
                    .padding(.leading, 16)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: 16, y: 1))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
            .frame(width: 16, height: 2)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(HomeLook.ink)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(HomeLook.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Where people left

    private var dropsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeepSectionLabel("WHERE PEOPLE LEFT")

            if drops.isEmpty {
                Text("No big drop. People leave slowly and evenly, which is normal for most videos.")
                    .font(.system(size: 15))
                    .foregroundColor(HomeLook.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(drops.enumerated()), id: \.offset) { index, drop in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(ReviewLook.bad))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(DeepFormat.time(drop.startSecond)) to \(DeepFormat.time(drop.endSecond))")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(HomeLook.ink)
                            Text("About \(DeepFormat.pct(drop.lost)) of viewers left here.")
                                .font(.system(size: 14))
                                .foregroundColor(HomeLook.secondary)
                        }
                    }
                }

                tipBox("Watch these parts again. Ask: is it slow, off topic, or saying something twice? Cut or speed up parts like this next time.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - What people rewatched

    private var rewatchCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeepSectionLabel("WHAT PEOPLE REWATCHED")

            ForEach(Array(rewatches.enumerated()), id: \.offset) { _, spot in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(ReviewLook.good))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DeepFormat.time(spot.second))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(HomeLook.ink)
                        Text("People went back to watch this part again.")
                            .font(.system(size: 14))
                            .foregroundColor(HomeLook.secondary)
                    }
                }
            }

            tipBox("Do more of what happens here. The same kind of moment, example or reveal will keep people watching in your next video.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    private func tipBox(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRY THIS")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.0)
                .foregroundColor(HomeLook.ink)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(HomeLook.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HomeLook.fill))
    }
}

// MARK: - Chart (this video vs your usual, with drop and rewatch markers)

struct DeepRetentionChart: View {
    let curve: [RetentionDataPoint]
    let usual: [RetentionDataPoint]
    let dropRatios: [Double]
    let rewatchRatios: [Double]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let sorted = curve.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }

            ZStack {
                // Grid at 25 / 50 / 75 / 100%
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    Path { p in
                        let y = h * (1 - level)
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(HomeLook.hairline, lineWidth: 1)
                }
                VStack {
                    ForEach(["100%", "75%", "50%", "25%"], id: \.self) { label in
                        HStack {
                            Text(label).font(.system(size: 10)).foregroundColor(Color(white: 0.65))
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .padding(.top, 2)

                // Your usual (dashed grey)
                if usual.count >= 2 {
                    line(usual, w: w, h: h)
                        .stroke(Color(white: 0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                // This video (fill + line)
                area(sorted, w: w, h: h)
                    .fill(LinearGradient(colors: [HomeLook.purple.opacity(0.18), HomeLook.purple.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                line(sorted, w: w, h: h)
                    .stroke(HomeLook.purple, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                // Markers
                ForEach(Array(dropRatios.enumerated()), id: \.offset) { index, ratio in
                    marker(text: "\(index + 1)", color: ReviewLook.bad)
                        .position(x: w * ratio, y: y(at: ratio, in: sorted, h: h))
                }
                ForEach(Array(rewatchRatios.enumerated()), id: \.offset) { _, ratio in
                    Circle()
                        .fill(ReviewLook.good)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: w * ratio, y: y(at: ratio, in: sorted, h: h))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }

    private func line(_ points: [RetentionDataPoint], w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            let sorted = points.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
            guard let first = sorted.first else { return }
            p.move(to: CGPoint(x: w * first.elapsedTimeRatio, y: h * (1 - clamp(first.audienceWatchRatio))))
            for point in sorted.dropFirst() {
                p.addLine(to: CGPoint(x: w * point.elapsedTimeRatio, y: h * (1 - clamp(point.audienceWatchRatio))))
            }
        }
    }

    private func area(_ points: [RetentionDataPoint], w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            guard let first = points.first, let last = points.last else { return }
            p.move(to: CGPoint(x: w * first.elapsedTimeRatio, y: h))
            for point in points {
                p.addLine(to: CGPoint(x: w * point.elapsedTimeRatio, y: h * (1 - clamp(point.audienceWatchRatio))))
            }
            p.addLine(to: CGPoint(x: w * last.elapsedTimeRatio, y: h))
            p.closeSubpath()
        }
    }

    private func y(at ratio: Double, in sorted: [RetentionDataPoint], h: CGFloat) -> CGFloat {
        let closest = sorted.min { abs($0.elapsedTimeRatio - ratio) < abs($1.elapsedTimeRatio - ratio) }
        return h * (1 - clamp(closest?.audienceWatchRatio ?? 0.5))
    }

    private func marker(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}
