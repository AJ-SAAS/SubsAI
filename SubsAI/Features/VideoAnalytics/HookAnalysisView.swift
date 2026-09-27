// Features/VideoAnalytics/HookAnalysisView.swift
// Hook tab: how many people are still watching in the first minute, at real seconds,
// compared to your usual. Real data only.
import SwiftUI

struct HookAnalysisView: View {
    @ObservedObject var vm: VideoDeepAnalysisViewModel
    let allVideos: [Video]

    var body: some View {
        if !vm.hasCurve || vm.checkpoints.isEmpty {
            DeepNoDataCard()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                firstMinuteCard
                whatHappenedCard
                if let best = bestStart { bestStartCard(best) }
            }
        }
    }

    // MARK: - Data

    private var insights: VideoInsights? { vm.insights }

    /// The main moment: 0:02 for Shorts (that's when people swipe), 0:30 for long videos
    private var mainSecond: Int {
        let points = vm.checkpoints
        if vm.video.isShort, points.contains(2) { return 2 }
        return points.contains(30) ? 30 : (points.last { $0 <= 60 } ?? points.first ?? 30)
    }

    private func you(at second: Int) -> Double? { insights?.retention(atSecond: second) }
    private func usual(at second: Int) -> Double? { vm.profile?.atSecond[second] }

    // MARK: - Card 1: the first minute

    private var firstMinuteCard: some View {
        let main = you(at: mainSecond) ?? 0
        let mainUsual = usual(at: mainSecond)

        return VStack(alignment: .leading, spacing: 14) {
            DeepSectionLabel("THE FIRST MINUTE")

            HStack(alignment: .firstTextBaseline) {
                Text(DeepFormat.pct(main))
                    .font(.system(size: 44, weight: .bold))
                    .kerning(-1)
                    .foregroundColor(HomeLook.ink)
                Text("still watching at \(DeepFormat.time(mainSecond))")
                    .font(.system(size: 15))
                    .foregroundColor(HomeLook.secondary)
            }

            if let u = mainUsual {
                compareTag(you: main, usual: u)
            }

            VStack(spacing: 12) {
                ForEach(vm.checkpoints, id: \.self) { second in
                    checkpointRow(second)
                }
            }
            .padding(.top, 4)

            if vm.profile != nil {
                HStack(spacing: 6) {
                    Rectangle().fill(HomeLook.ink).frame(width: 2, height: 12)
                    Text("= your usual, from your last \(vm.profile?.sampleCount ?? 0) videos")
                        .font(.system(size: 12))
                        .foregroundColor(HomeLook.secondary)
                }
            } else if vm.isLoadingUsual {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading your usual...")
                        .font(.system(size: 12))
                        .foregroundColor(HomeLook.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    private func compareTag(you: Double, usual: Double) -> some View {
        let ratio = usual > 0 ? you / usual : 1
        let better = ratio >= 1.03, worse = ratio <= 0.95
        let text = better ? "Better than your usual \(DeepFormat.pct(usual))"
            : (worse ? "Below your usual \(DeepFormat.pct(usual))" : "About your usual \(DeepFormat.pct(usual))")
        let color = better ? ReviewLook.goodText : (worse ? ReviewLook.badText : HomeLook.secondary)
        return HStack(spacing: 5) {
            Image(systemName: better ? "arrow.up" : (worse ? "arrow.down" : "equal"))
                .font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(color)
    }

    private func checkpointRow(_ second: Int) -> some View {
        let value = you(at: second) ?? 0
        let u = usual(at: second)
        let color: Color = {
            guard let u else { return HomeLook.purple }
            return value >= u * 0.97 ? ReviewLook.good : ReviewLook.bad
        }()

        return HStack(spacing: 10) {
            Text(DeepFormat.time(second))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HomeLook.secondary)
                .frame(width: 38, alignment: .leading)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(HomeLook.fill)
                    Capsule().fill(color).frame(width: g.size.width * CGFloat(min(max(value, 0), 1)))
                    if let u {
                        Rectangle()
                            .fill(HomeLook.ink)
                            .frame(width: 2, height: 16)
                            .offset(x: g.size.width * CGFloat(min(max(u, 0), 1)) - 1)
                    }
                }
            }
            .frame(height: 10)

            Text(DeepFormat.pct(value))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(HomeLook.ink)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Card 2: what happened

    private var whatHappenedCard: some View {
        // Biggest loss between two checkpoints (starting from 0:00 = 100%)
        let seconds = [0] + vm.checkpoints
        var worst: (from: Int, to: Int, lost: Double)?
        for i in 1..<seconds.count {
            let before = seconds[i - 1] == 0 ? 1.0 : (you(at: seconds[i - 1]) ?? 1)
            let after = you(at: seconds[i]) ?? before
            let lost = before - after
            if lost > (worst?.lost ?? 0) { worst = (seconds[i - 1], seconds[i], lost) }
        }

        let main = you(at: mainSecond) ?? 0
        let mainUsual = usual(at: mainSecond)
        let isWorking = mainUsual.map { main >= $0 * 0.97 } ?? (main >= 0.7)

        return VStack(alignment: .leading, spacing: 12) {
            DeepSectionLabel("WHAT HAPPENED")

            if let w = worst, w.lost >= 0.02 {
                Text(LocalizedStringKey("The most people left between **\(DeepFormat.time(w.from)) and \(DeepFormat.time(w.to))**. About **\(DeepFormat.pct(w.lost))** of viewers left there."))
                    .font(.system(size: 15))
                    .foregroundColor(HomeLook.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("TRY THIS")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.0)
                    .foregroundColor(HomeLook.ink)
                Text(isWorking
                     ? "Your start is working. Keep opening your videos the same way."
                     : "Cut the setup. Show the best moment or the end result in the first 5 seconds, then explain how.")
                    .font(.system(size: 15))
                    .foregroundColor(HomeLook.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HomeLook.fill))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - Card 3: your best start lately

    private var bestStart: (video: Video, value: Double)? {
        guard let profile = vm.profile else { return nil }
        let candidates = profile.videos.compactMap { item -> (Video, Double)? in
            guard let v = item.insights.retention(atSecond: mainSecond) else { return nil }
            return (item.video, v)
        }
        guard let best = candidates.max(by: { $0.1 < $1.1 }),
              best.1 > (you(at: mainSecond) ?? 0) else { return nil }
        return (best.0, best.1)
    }

    private func bestStartCard(_ best: (video: Video, value: Double)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DeepSectionLabel("YOUR BEST START LATELY")
            HStack(spacing: 12) {
                VideoThumbnailMini(video: best.video)
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(best.video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HomeLook.ink)
                        .lineLimit(2)
                    Text("Kept \(DeepFormat.pct(best.value)) at \(DeepFormat.time(mainSecond))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReviewLook.goodText)
                }
            }
            Text(vm.video.isShort
                 ? "Watch its first 2 seconds, then this one. The difference is usually what you see on screen right away."
                 : "Watch its first 30 seconds, then this one. The difference is usually how fast it gets to the point.")
                .font(.system(size: 14))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let match = allVideos.first { $0.videoId == best.video.videoId } ?? best.video
            NavigationLink {
                CoachReviewView(video: match, allVideos: allVideos)
            } label: {
                HStack(spacing: 6) {
                    Text("See its review")
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(Capsule().fill(HomeLook.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }
}

// MARK: - InsightBlock (kept: other screens may use it)

struct InsightBlock: View {
    let title: String
    let content: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accentColor)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
        .overlay(
            Rectangle().fill(accentColor).frame(width: 2),
            alignment: .leading
        )
    }
}
