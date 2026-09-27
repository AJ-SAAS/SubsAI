// Features/VideoAnalytics/VideoCompareView.swift
// Compare tab: this video vs your other videos, ranked by how much people watch.
// Title patterns are shown as honest counts, only when the difference is clear.
import SwiftUI

struct VideoCompareView: View {
    let currentVideo: Video
    let allVideos: [Video]

    // Videos with real "% watched" and 100+ views (tiny videos swing too much), best first.
    // This video is always included so it can be ranked.
    // Shorts only rank against Shorts, long videos against long videos.
    private var ranked: [Video] {
        allVideos
            .filter { $0.isSameFormat(as: currentVideo) }
            .filter { ($0.analytics?.retention ?? 0) > 0 && ($0.views >= 100 || $0.videoId == currentVideo.videoId) }
            .sorted { ($0.analytics?.retention ?? 0) > ($1.analytics?.retention ?? 0) }
    }

    private var currentRank: Int? {
        ranked.firstIndex { $0.videoId == currentVideo.videoId }.map { $0 + 1 }
    }

    private var usualWatched: Double? {
        let values = ranked.filter { $0.videoId != currentVideo.videoId }
            .compactMap { $0.analytics?.retention }
            .sorted()
        return values.count >= 3 ? values[values.count / 2] : nil
    }

    var body: some View {
        if ranked.count < 3 {
            VStack(alignment: .leading, spacing: 8) {
                Text(currentVideo.isShort ? "Not enough Shorts to compare yet" : "Not enough videos to compare yet")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(HomeLook.ink)
                Text("Once you have 3 or more videos with data, you'll see how this one ranks.")
                    .font(.system(size: 15))
                    .foregroundColor(HomeLook.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(PremiumWhiteCard())
        } else {
            VStack(alignment: .leading, spacing: 16) {
                rankCard
                listCard
                if let pattern = titlePattern { patternCard(pattern) }
                if let study = studyVideo { studyCard(study) }
            }
        }
    }

    // MARK: - How it ranks

    private var rankCard: some View {
        let mine = currentVideo.analytics?.retention ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            DeepSectionLabel("HOW IT RANKS")
            if let rank = currentRank {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("#\(rank)")
                        .font(.system(size: 44, weight: .bold))
                        .kerning(-1)
                        .foregroundColor(HomeLook.ink)
                    Text("of \(ranked.count) \(currentVideo.isShort ? "Shorts" : "videos")")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(HomeLook.secondary)
                }
                Text(currentVideo.isShort
                     ? "Ranked against your other Shorts, by how much people watch."
                     : "Ranked against your other long videos, by how much people watch.")
                    .font(.system(size: 14))
                    .foregroundColor(HomeLook.secondary)
            }
            if let usual = usualWatched, mine > 0 {
                let better = mine >= usual
                Text(LocalizedStringKey("This video: **\(DeepFormat.pct(mine))** watched. Your usual: **\(DeepFormat.pct(usual))**."))
                    .font(.system(size: 15))
                    .foregroundColor(better ? ReviewLook.goodText : ReviewLook.badText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - Top videos list (plus this one)

    private var listRows: [(rank: Int, video: Video)] {
        var rows: [(rank: Int, video: Video)] = ranked.prefix(5).enumerated().map { (rank: $0.offset + 1, video: $0.element) }
        if let rank = currentRank, rank > 5 {
            rows.append((rank: rank, video: currentVideo))
        }
        return rows
    }

    private var listCard: some View {
        let top = ranked.first?.analytics?.retention ?? 1
        let usual = usualWatched

        return VStack(alignment: .leading, spacing: 4) {
            DeepSectionLabel(currentVideo.isShort ? "YOUR SHORTS BY % WATCHED" : "YOUR VIDEOS BY % WATCHED")
                .padding(.bottom, 8)

            ForEach(Array(listRows.enumerated()), id: \.offset) { index, row in
                if index == 5 {
                    Text("...")
                        .font(.system(size: 13))
                        .foregroundColor(HomeLook.secondary)
                        .padding(.leading, 4)
                }
                compareRow(rank: row.rank, video: row.video, top: top, usual: usual)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    private func compareRow(rank: Int, video: Video, top: Double, usual: Double?) -> some View {
        let value = video.analytics?.retention ?? 0
        let isCurrent = video.videoId == currentVideo.videoId
        let color: Color = usual.map { value >= $0 ? ReviewLook.good : ReviewLook.bad } ?? HomeLook.purple

        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(HomeLook.secondary)
                .frame(width: 20)

            VideoThumbnailMini(video: video)
                .frame(width: 56, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if isCurrent {
                        Text("THIS VIDEO")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(HomeLook.purple))
                    }
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HomeLook.ink)
                        .lineLimit(1)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(HomeLook.fill)
                        Capsule().fill(color)
                            .frame(width: g.size.width * CGFloat(top > 0 ? min(value / top, 1) : 0))
                    }
                }
                .frame(height: 6)
            }

            Text(DeepFormat.pct(value))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(HomeLook.ink)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isCurrent ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrent ? HomeLook.purple.opacity(0.07) : Color.clear)
        )
    }

    // MARK: - Title patterns (honest counts)

    private struct TitlePattern {
        let text: String
    }

    /// Compares your top third vs bottom third by % watched.
    /// Only shows a pattern if it's clearly stronger in your best videos.
    private var titlePattern: TitlePattern? {
        guard ranked.count >= 9 else { return nil }
        let n = ranked.count / 3
        let top = Array(ranked.prefix(n))
        let bottom = Array(ranked.suffix(n))

        let features: [(name: String, test: (String) -> Bool)] = [
            ("a number in the title", { $0.range(of: #"\d"#, options: .regularExpression) != nil }),
            ("a question in the title", { $0.contains("?") }),
            ("a title that starts with \"How\"", { $0.lowercased().hasPrefix("how") }),
            ("a short title (under 50 letters)", { $0.count < 50 })
        ]

        var best: (name: String, topCount: Int, bottomCount: Int, gap: Int)?
        for feature in features {
            let t = top.filter { feature.test($0.title) }.count
            let b = bottom.filter { feature.test($0.title) }.count
            let gap = t - b
            // Clear difference: at least half of the top, and 30%+ more than the bottom
            if t * 2 >= n, Double(gap) / Double(n) >= 0.3, gap > (best?.gap ?? 0) {
                best = (feature.name, t, b, gap)
            }
        }
        guard let found = best else { return nil }
        return TitlePattern(text: "\(found.topCount) of your top \(n) videos have \(found.name). Only \(found.bottomCount) of your bottom \(n) do.")
    }

    private func patternCard(_ pattern: TitlePattern) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DeepSectionLabel("WHAT YOUR BEST VIDEOS HAVE IN COMMON")
            Text(pattern.text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HomeLook.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("It's a pattern, not a rule. Try it on your next video and see if it holds.")
                .font(.system(size: 14))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(PremiumWhiteCard())
    }

    // MARK: - Study this one

    private var studyVideo: Video? {
        ranked.first { $0.videoId != currentVideo.videoId }
    }

    private func studyCard(_ video: Video) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DeepSectionLabel("STUDY THIS ONE")
            HStack(spacing: 12) {
                VideoThumbnailMini(video: video)
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HomeLook.ink)
                        .lineLimit(2)
                    Text("People watch \(DeepFormat.pct(video.analytics?.retention ?? 0)) of it. Your best.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReviewLook.goodText)
                }
            }
            Text("Watch it back to back with this one. Look at how fast it gets to the point, and how it keeps you curious.")
                .font(.system(size: 14))
                .foregroundColor(HomeLook.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                CoachReviewView(video: video, allVideos: allVideos)
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

// MARK: - Kept for other screens that may use them

struct VideoCompareRow: View {
    let video: Video
    let isCurrentVideo: Bool
    var avgRetention: Double = 0

    private var retention: Double { video.analytics?.retention ?? 0 }

    var body: some View {
        HStack {
            Text(video.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
            Spacer()
            Text("\(Int(retention * 100))%")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(retention >= avgRetention ? ReviewLook.good : ReviewLook.bad)
        }
        .padding(14)
        .background(isCurrentVideo ? AppTheme.accent.opacity(0.06) : AppTheme.cardBackground)
        .cornerRadius(14)
    }
}

struct CompareBar: View {
    let label: String
    let value: Double
    let displayValue: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textTertiary)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 4)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(max(value, 0), 1), height: 4)
                }
                .frame(height: 4)
                .padding(.top, 5)
            }
            .frame(height: 14)
            Text(displayValue)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
