// Features/Coach/VideoDiagnosis.swift
// Finds the ONE thing holding a video back, using only real YouTube numbers.
//
// A video is a chain:  Reach -> Click -> Hook -> Watch -> Subscribe
// Every step is compared to the creator's OWN usual (the middle of their other videos).
// If they don't have enough videos yet, we fall back to "typical" YouTube numbers and say so.
//
// Which fix wins: Click, Hook and Watch come first, because when they're weak YouTube
// shows the video to fewer people (they cause low reach). If all three are fine and views
// are still low, the problem really is Reach. Subscribe comes last.
import Foundation

// MARK: - Extra data for one video (loaded when the review page opens)

struct SearchTerm: Identifiable, Hashable {
    var id: String { term }
    let term: String
    let views: Int
}

struct VideoInsights {
    var durationSeconds: Int?
    var retentionCurve: [RetentionDataPoint] = []
    /// Raw YouTube traffic source type -> views (all time)
    var trafficViews: [String: Double] = [:]
    var searchTerms: [SearchTerm] = []
    /// Shorts are judged at 2 seconds, not 30
    var isShort = false

    struct TrafficGroup: Identifiable {
        var id: String { name }
        let name: String
        let share: Double
    }

    // Grouped for people: Home, Suggested, Search, Other
    var trafficGroups: [TrafficGroup] {
        let total = trafficViews.values.reduce(0, +)
        guard total > 0 else { return [] }
        var groups: [String: Double] = ["Home": 0, "Suggested": 0, "Search": 0, "Other": 0]
        for (type, views) in trafficViews {
            switch type {
            case "SUBSCRIBER", "NOTIFICATION":         groups["Home", default: 0] += views
            case "RELATED_VIDEO", "END_SCREEN":        groups["Suggested", default: 0] += views
            case "YT_SEARCH":                          groups["Search", default: 0] += views
            default:                                   groups["Other", default: 0] += views
            }
        }
        return ["Home", "Suggested", "Search", "Other"]
            .map { TrafficGroup(name: $0, share: (groups[$0] ?? 0) / total) }
            .filter { $0.share > 0 }
    }

    var searchShare: Double? {
        let total = trafficViews.values.reduce(0, +)
        guard total > 0 else { return nil }
        return (trafficViews["YT_SEARCH"] ?? 0) / total
    }

    /// The moment we judge the hook at: 0:30 for normal videos, earlier for short ones
    var hookSecond: Int {
        if isShort { return 2 }
        guard let d = durationSeconds else { return 30 }
        if d >= 120 { return 30 }
        if d >= 60  { return 15 }
        return 3
    }

    var hookRetention: Double? {
        retention(atSecond: hookSecond)
    }

    /// Share of starting viewers still watching at this second (0...1)
    func retention(atSecond second: Int) -> Double? {
        guard let d = durationSeconds, d > 0, retentionCurve.count >= 2 else { return nil }
        let target = Double(second) / Double(d)
        let points = retentionCurve.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
        guard let after = points.firstIndex(where: { $0.elapsedTimeRatio >= target }) else {
            return points.last.map { min($0.audienceWatchRatio, 1) }
        }
        if after == 0 { return min(points[0].audienceWatchRatio, 1) }
        let a = points[after - 1], b = points[after]
        let span = b.elapsedTimeRatio - a.elapsedTimeRatio
        let t = span > 0 ? (target - a.elapsedTimeRatio) / span : 0
        return min(a.audienceWatchRatio + (b.audienceWatchRatio - a.audienceWatchRatio) * t, 1)
    }

    /// The part of the video where the most people left (ignores the start and the end,
    /// where everyone drops). Only returned if at least 5% of viewers left there.
    var biggestDrop: (startSecond: Int, endSecond: Int, lost: Double)? {
        drops(limit: 1).first
    }

    /// Up to `limit` separate parts where the most people left, biggest first.
    func drops(limit: Int) -> [(startSecond: Int, endSecond: Int, lost: Double)] {
        guard let d = durationSeconds, d > 0 else { return [] }
        let points = retentionCurve.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
        guard points.count >= 20 else { return [] }
        let k = max(2, points.count / 20)   // about 5% of the video

        var windows: [(index: Int, lost: Double)] = []
        for i in 0..<(points.count - k) {
            let a = points[i], b = points[i + k]
            guard a.elapsedTimeRatio >= 0.10, b.elapsedTimeRatio <= 0.90 else { continue }
            windows.append((i, a.audienceWatchRatio - b.audienceWatchRatio))
        }

        var picked: [(startSecond: Int, endSecond: Int, lost: Double)] = []
        var used: [Int] = []
        for w in windows.sorted(by: { $0.lost > $1.lost }) {
            guard picked.count < limit, w.lost >= 0.05 else { break }
            if used.contains(where: { abs($0 - w.index) < k }) { continue }   // no overlaps
            used.append(w.index)
            let a = points[w.index], b = points[w.index + k]
            picked.append((Int(a.elapsedTimeRatio * Double(d)), Int(b.elapsedTimeRatio * Double(d)), w.lost))
        }
        return picked
    }

    /// Moments where the line goes UP: people went back and watched again.
    func rewatchSpots(limit: Int) -> [(second: Int, rise: Double)] {
        guard let d = durationSeconds, d > 0 else { return [] }
        let points = retentionCurve.sorted { $0.elapsedTimeRatio < $1.elapsedTimeRatio }
        guard points.count >= 20 else { return [] }
        var spots: [(index: Int, rise: Double)] = []
        for i in 1..<points.count {
            let r = points[i].elapsedTimeRatio
            guard r >= 0.05, r <= 0.95 else { continue }
            let rise = points[i].audienceWatchRatio - points[i - 1].audienceWatchRatio
            if rise >= 0.015 { spots.append((i, rise)) }
        }
        var picked: [(second: Int, rise: Double)] = []
        var used: [Int] = []
        for s in spots.sorted(by: { $0.rise > $1.rise }) {
            guard picked.count < limit else { break }
            if used.contains(where: { abs($0 - s.index) < 3 }) { continue }
            used.append(s.index)
            picked.append((Int(points[s.index].elapsedTimeRatio * Double(d)), s.rise))
        }
        return picked.sorted { $0.second < $1.second }
    }

    /// Share of starting viewers still watching near the end (at 95%)
    var nearEndRetention: Double? {
        guard let d = durationSeconds else { return nil }
        return retention(atSecond: Int(Double(d) * 0.95))
    }
}

/// How well the channel's recent videos hold people at the hook moment
struct HookBaseline {
    let median: Double
    let sampleCount: Int
    let bestTitle: String?
    let bestValue: Double?
}

// MARK: - The chain

enum FunnelStep: String, CaseIterable, Identifiable {
    case reach, click, hook, watch, subscribe
    var id: String { rawValue }

    var name: String {
        switch self {
        case .reach:     return "Reach"
        case .click:     return "Click"
        case .hook:      return "Hook"
        case .watch:     return "Watch"
        case .subscribe: return "Subscribe"
        }
    }
}

enum StepState {
    case good          // matches or beats your usual
    case bottleneck    // the one we tell them to fix
    case weak          // below usual, but not the first thing to fix
    case unknown       // not enough data yet
}

struct StepCheck {
    let step: FunnelStep
    var state: StepState
    let you: Double?
    let usual: Double?
    let usualIsTypical: Bool   // true = small channel, compared to typical YouTube numbers

    var ratio: Double? {
        guard let you, let usual, usual > 0 else { return nil }
        return you / usual
    }
}

// MARK: - What the page shows

struct DiagnosisContent {
    enum Kind { case fix, healthy, tooEarly, loading }

    let kind: Kind
    let label: String          // "YOUR NEXT FIX"
    let tag: String?           // "REACH"
    let title: String          // "Help more people find it."
    let evidence: [String]     // markdown, **bold** allowed
    let showTraffic: Bool
    let searchTerms: [SearchTerm]
    let actionIntro: String?   // "Use "davinci resolve split clip" in these 5 places:"
    let actionText: String?    // plain action when there's no list
    let seoPhrase: String?     // show the 5 SEO places when set
    let seoFileName: String?
    let example: String?       // "Your best clicked video is ..." (markdown)
    let pattern: String?       // "This happens on 6 of your last 10 videos too."
    let extraNote: String?     // engagement note, never the main fix
    let whyText: String        // under the chain
}

struct VideoDiagnosis {
    let checks: [FunnelStep: StepCheck]
    let bottleneck: FunnelStep?
    let content: DiagnosisContent
    /// The steps shown in the chain. Shorts skip "Click" (people swipe, they don't click).
    var steps: [FunnelStep] = FunnelStep.allCases

    // Thresholds are RELATIVE to the creator's usual (0.8 = 20% below usual)
    private static let limits: [FunnelStep: Double] = [
        .click: 0.80, .hook: 0.90, .watch: 0.85, .reach: 0.60, .subscribe: 0.70
    ]
    // Used only when a channel has too few videos to have a "usual"
    private static let typical: [FunnelStep: Double] = [
        .click: 0.045, .hook: 0.70, .watch: 0.40, .subscribe: 1.5
    ]
    // Shorts: judged at 2 seconds, people often watch 80%+ (loops), fewer subs per view
    private static let typicalShort: [FunnelStep: Double] = [
        .hook: 0.75, .watch: 0.80, .subscribe: 0.5
    ]
    private static let fixOrder: [FunnelStep] = [.click, .hook, .watch, .reach, .subscribe]
    private static let shortFixOrder: [FunnelStep] = [.hook, .watch, .reach, .subscribe]

    // MARK: Build

    static func make(video: Video,
                     allVideos: [Video],
                     insights: VideoInsights?,
                     hookBaseline: HookBaseline?) -> VideoDiagnosis {

        let isShort = video.isShort
        let steps: [FunnelStep] = isShort ? [.reach, .hook, .watch, .subscribe] : FunnelStep.allCases
        let typicalValues = isShort ? Self.typicalShort : Self.typical
        var insights = insights
        insights?.isShort = isShort

        guard let stats = video.analytics else {
            return VideoDiagnosis(checks: [:], bottleneck: nil, content: .loadingContent)
        }
        if video.ageInDays < 2 {
            return VideoDiagnosis(checks: [:], bottleneck: nil, content: .tooEarlyContent)
        }

        // "Your usual" = only the SAME kind (Shorts with Shorts, long with long),
        // and only videos with 100+ views (tiny videos swing too much)
        let others = allVideos.filter {
            $0.videoId != video.videoId && $0.analytics != nil && $0.views >= 100 && $0.isSameFormat(as: video)
        }

        func median(_ values: [Double]) -> Double? {
            let v = values.filter { $0 > 0 }.sorted()
            return v.count >= 5 ? v[v.count / 2] : nil
        }

        var checks: [FunnelStep: StepCheck] = [:]

        // Click (CTR). Not for Shorts.
        if !isShort {
            let usualCTR = median(others.compactMap { ($0.analytics?.hasCTR ?? false) ? $0.analytics?.ctr : nil })
            checks[.click] = StepCheck(step: .click, state: .unknown,
                                       you: stats.hasCTR ? stats.ctr : nil,
                                       usual: usualCTR ?? typicalValues[.click],
                                       usualIsTypical: usualCTR == nil)
        }

        // Hook (still watching at 0:30)
        let hookUsual = (hookBaseline?.sampleCount ?? 0) >= 3 ? hookBaseline?.median : nil
        checks[.hook] = StepCheck(step: .hook, state: .unknown,
                                  you: insights?.hookRetention,
                                  usual: hookUsual ?? typicalValues[.hook],
                                  usualIsTypical: hookUsual == nil)

        // Watch (% of the video watched)
        let usualWatch = median(others.map { $0.analytics?.retention ?? 0 })
        checks[.watch] = StepCheck(step: .watch, state: .unknown,
                                   you: stats.retention > 0 ? stats.retention : nil,
                                   usual: usualWatch ?? typicalValues[.watch],
                                   usualIsTypical: usualWatch == nil)

        // Reach (views vs usual). Only fair once the video is about a month old,
        // and only against other videos that are at least that old.
        // Shorts get most of their views in the first week, so 7 days is enough for them.
        let matureAge = isShort ? 7 : 28
        let matureOthers = others.filter { $0.ageInDays >= matureAge }
        let usualViews = median(matureOthers.map { Double($0.views) })
        checks[.reach] = StepCheck(step: .reach, state: .unknown,
                                   you: video.ageInDays >= matureAge ? Double(video.views) : nil,
                                   usual: usualViews,
                                   usualIsTypical: false)

        // Subscribe (subs per 1K views). Needs enough views to mean anything.
        let usualGPV = median(others.filter { $0.views >= 200 }.map { $0.growthPerView })
        checks[.subscribe] = StepCheck(step: .subscribe, state: .unknown,
                                       you: video.views >= 200 ? video.growthPerView : nil,
                                       usual: usualGPV ?? typicalValues[.subscribe],
                                       usualIsTypical: usualGPV == nil)

        // Decide each step's state
        for step in steps {
            guard var check = checks[step], let ratio = check.ratio else { continue }
            check.state = ratio < (limits[step] ?? 0.8) ? .weak : .good
            checks[step] = check
        }

        // The fix = first weak step in fix order
        let bottleneck = (isShort ? shortFixOrder : fixOrder).first { checks[$0]?.state == .weak }
        if let b = bottleneck { checks[b]?.state = .bottleneck }

        let content = buildContent(video: video, stats: stats, others: others, checks: checks,
                                   bottleneck: bottleneck, insights: insights, hookBaseline: hookBaseline,
                                   steps: steps)
        return VideoDiagnosis(checks: checks, bottleneck: bottleneck, content: content, steps: steps)
    }

    // MARK: Words

    private static func buildContent(video: Video,
                                     stats: VideoAnalytics,
                                     others: [Video],
                                     checks: [FunnelStep: StepCheck],
                                     bottleneck: FunnelStep?,
                                     insights: VideoInsights?,
                                     hookBaseline: HookBaseline?,
                                     steps: [FunnelStep]) -> DiagnosisContent {

        let why = whyText(checks: checks, bottleneck: bottleneck, steps: steps)
        let pattern = bottleneck.flatMap { patternLine(step: $0, others: others, checks: checks) }
        let note = engagementNote(video: video, others: others, bottleneck: bottleneck)

        guard let step = bottleneck, let check = checks[step] else {
            // Nothing broken
            let known = checks.values.filter { $0.ratio != nil }
            let weakest = known.min { ($0.ratio ?? 9) < ($1.ratio ?? 9) }
            var evidence = ["Every step we can measure matches or beats your usual."]
            if let w = weakest, (w.ratio ?? 9) < 1.1 {
                evidence.append("Most room to grow: **\(w.step.name.lowercased())**.")
            }
            return DiagnosisContent(
                kind: .healthy, label: "LOOKING GOOD", tag: nil,
                title: "This video is working.",
                evidence: evidence, showTraffic: false, searchTerms: [],
                actionIntro: nil,
                actionText: video.isShort
                    ? "Make another Short like this one. Same kind of topic, same kind of first second."
                    : "Make another video like this one. Same kind of topic, same style of thumbnail.",
                seoPhrase: nil, seoFileName: nil, example: nil, pattern: nil,
                extraNote: note, whyText: why)
        }

        let usualWord = check.usualIsTypical ? "Most channels get" : "Your usual is"

        switch step {
        case .click:
            var evidence: [String] = []
            if let impressions = stats.impressions, impressions > 0 {
                evidence.append("**\(Int(impressions).formatted()) people** saw it in recent days.")
            }
            evidence.append("Only **\(pct1(check.you))** clicked. \(usualWord) **\(pct1(check.usual))**.")
            let best = others
                .filter { $0.analytics?.hasCTR ?? false }
                .max { ($0.analytics?.ctr ?? 0) < ($1.analytics?.ctr ?? 0) }
            let example = best.map {
                "Your best clicked video is **\"\($0.title)\"** at **\(pct1($0.analytics?.ctr))**. Look at what its thumbnail does differently."
            }
            return DiagnosisContent(
                kind: .fix, label: "YOUR NEXT FIX", tag: "CLICK",
                title: "Make more people click.",
                evidence: evidence, showTraffic: false, searchTerms: [],
                actionIntro: nil,
                actionText: "Show one clear result in the thumbnail, with 3 words or less. Make the title promise that same result.",
                seoPhrase: nil, seoFileName: nil, example: example, pattern: pattern,
                extraNote: note, whyText: why)

        case .hook:
            let moment = time(insights?.hookSecond ?? 30)
            var example: String?
            if let title = hookBaseline?.bestTitle, let value = hookBaseline?.bestValue {
                example = "Your best start lately: **\"\(title)\"** kept **\(pct0(value))** at \(moment)."
            }
            if video.isShort {
                return DiagnosisContent(
                    kind: .fix, label: "YOUR NEXT FIX", tag: "HOOK",
                    title: "Grab them in the first second.",
                    evidence: ["**\(pct0(check.you))** stayed past \(moment). The rest swiped away. \(usualWord) **\(pct0(check.usual))**."],
                    showTraffic: false, searchTerms: [],
                    actionIntro: nil,
                    actionText: "Start with the most surprising part. No hello, no intro. Put a few big words on screen so people know what they will get.",
                    seoPhrase: nil, seoFileName: nil, example: example, pattern: pattern,
                    extraNote: note, whyText: why)
            }
            return DiagnosisContent(
                kind: .fix, label: "YOUR NEXT FIX", tag: "HOOK",
                title: "Hook people faster.",
                evidence: ["**\(pct0(check.you))** are still watching at \(moment). \(usualWord) **\(pct0(check.usual))**."],
                showTraffic: false, searchTerms: [],
                actionIntro: nil,
                actionText: "Cut the intro. Show the best moment or the end result in the first 5 seconds, then explain how.",
                seoPhrase: nil, seoFileName: nil, example: example, pattern: pattern,
                extraNote: note, whyText: why)

        case .watch:
            var evidence = ["People watch **\(pct0(check.you))** of it. \(usualWord) **\(pct0(check.usual))**."]
            if video.isShort {
                // On Shorts, over 100% means people watched it again.
                return DiagnosisContent(
                    kind: .fix, label: "YOUR NEXT FIX", tag: "WATCH",
                    title: "Make it loop.",
                    evidence: evidence, showTraffic: false, searchTerms: [],
                    actionIntro: nil,
                    actionText: "Cut every pause. Make it shorter if you can. End in a way that flows right back into the start, so people watch it twice.",
                    seoPhrase: nil, seoFileName: nil, example: nil, pattern: pattern,
                    extraNote: note, whyText: why)
            }
            var title = "Keep people watching longer."
            var action = "Tease what's coming next every few minutes, and cut any slow parts."
            if let drop = insights?.biggestDrop {
                title = "Fix the slow part at \(time(drop.startSecond))."
                evidence.append("The biggest drop is from **\(time(drop.startSecond)) to \(time(drop.endSecond))**. About **\(pct0(drop.lost))** of viewers left there.")
                action = "Watch that part again. Cut it, speed it up, or get to the point faster. Do the same in your next video."
            }
            return DiagnosisContent(
                kind: .fix, label: "YOUR NEXT FIX", tag: "WATCH",
                title: title, evidence: evidence, showTraffic: false, searchTerms: [],
                actionIntro: nil, actionText: action,
                seoPhrase: nil, seoFileName: nil, example: nil, pattern: pattern,
                extraNote: note, whyText: why)

        case .reach:
            var evidence = ["**\(Int(check.you ?? 0).formatted()) views.** Your usual is **\(Int(check.usual ?? 0).formatted())**."]
            let afterReachGood = [FunnelStep.click, .hook, .watch].allSatisfy { checks[$0]?.state != .weak }
            if afterReachGood {
                evidence.append("People who find it click and stay. Not enough people find it.")
            }
            let searchShare = insights?.searchShare
            let terms = Array((insights?.searchTerms ?? []).prefix(3))

            // Shorts get found in the Shorts feed, not by thumbnails. More Shorts = more chances.
            if video.isShort {
                return DiagnosisContent(
                    kind: .fix, label: "YOUR NEXT FIX", tag: "REACH",
                    title: "Get shown to more people.",
                    evidence: evidence, showTraffic: true, searchTerms: terms,
                    actionIntro: nil,
                    actionText: "The Shorts feed tests each Short on a few people first. If they stay, it shows it to more. Post more often, make the first second stronger, and put 1 or 2 search words in the title.",
                    seoPhrase: nil, seoFileName: nil, example: nil, pattern: pattern,
                    extraNote: note, whyText: why)
            }

            // Most views already come from search: few people search for this topic.
            if let share = searchShare, share >= 0.4 {
                evidence.append("**\(pct0(share))** of views already come from search, so not many people look for this topic.")
                return DiagnosisContent(
                    kind: .fix, label: "YOUR NEXT FIX", tag: "REACH",
                    title: "Try topics more people search for.",
                    evidence: evidence, showTraffic: true, searchTerms: terms,
                    actionIntro: nil,
                    actionText: "Next time, pick a topic close to your best videos, or one people search for a lot.",
                    seoPhrase: nil, seoFileName: nil, example: nil, pattern: pattern,
                    extraNote: note, whyText: why)
            }

            if let share = searchShare, share < 0.15 {
                evidence.append("Only **\(pct0(share))** of views came from search.")
            }
            let phrase = terms.first?.term
            return DiagnosisContent(
                kind: .fix, label: "YOUR NEXT FIX", tag: "REACH",
                title: "Help more people find it.",
                evidence: evidence, showTraffic: true, searchTerms: terms,
                actionIntro: phrase.map { "Use \"\($0)\" in these 5 places:" } ?? "Pick the words someone would search for. Use them in these 5 places:",
                actionText: nil,
                seoPhrase: phrase ?? "",
                seoFileName: fileName(from: phrase ?? video.title),
                example: nil, pattern: pattern, extraNote: note, whyText: why)

        case .subscribe:
            let subs = stats.subscribersGained
            let subAction = video.isShort
                ? "Pin a comment that says what your channel is about. Now and then, say it at the end: \"I post this every week, subscribe for more.\""
                : "Ask people to subscribe right after your best moment, not at the start. Tell them what your next video is about and why they'll want it."
            return DiagnosisContent(
                kind: .fix, label: "YOUR NEXT FIX", tag: "SUBSCRIBE",
                title: "Turn more viewers into subscribers.",
                evidence: ["**\(subs.formatted()) new subs** from \(video.views.formatted()) views. That's **\(String(format: "%.1f", check.you ?? 0))** per 1K views. \(usualWord) **\(String(format: "%.1f", check.usual ?? 0))**."],
                showTraffic: false, searchTerms: [],
                actionIntro: nil,
                actionText: subAction,
                seoPhrase: nil, seoFileName: nil, example: nil, pattern: pattern,
                extraNote: note, whyText: why)
        }
    }

    private static func whyText(checks: [FunnelStep: StepCheck], bottleneck: FunnelStep?, steps: [FunnelStep]) -> String {
        let good = steps.filter { checks[$0]?.state == .good }.map(\.name)
        let unknown = steps.contains { checks[$0]?.state == .unknown || checks[$0] == nil }
        let usesTypical = checks.values.contains { $0.usualIsTypical && $0.ratio != nil }
        var text: String
        if let b = bottleneck {
            let alsoWeak = steps.filter { checks[$0]?.state == .weak }.map(\.name)
            if !alsoWeak.isEmpty {
                text = "\(b.name) is the first step below your usual. Fixing it first also helps \(list(alsoWeak))."
            } else if !good.isEmpty {
                text = "\(list(good)) \(good.count == 1 ? "looks" : "look") fine. \(b.name) is the one holding it back."
            } else {
                text = "\(b.name) is the one holding it back."
            }
        } else {
            text = "No step is clearly below your usual."
        }
        if unknown { text += " Grey means there isn't enough data yet." }
        if usesTypical { text += " You don't have many videos yet, so some steps use typical YouTube numbers." }
        return text
    }

    /// "This happens on 6 of your last 10 videos too." Only for steps we can check on other videos.
    private static func patternLine(step: FunnelStep, others: [Video], checks: [FunnelStep: StepCheck]) -> String? {
        guard let usual = checks[step]?.usual, let limit = limits[step] else { return nil }
        let recent = others.sorted { $0.publishedAt > $1.publishedAt }.prefix(10)
        let values: [Double] = recent.compactMap { v in
            switch step {
            case .click:     return (v.analytics?.hasCTR ?? false) ? v.analytics?.ctr : nil
            case .watch:     return v.analytics?.retention
            case .reach:     return v.ageInDays >= (v.isShort ? 7 : 28) ? Double(v.views) : nil
            case .subscribe: return v.views >= 200 ? v.growthPerView : nil
            case .hook:      return nil
            }
        }
        guard values.count >= 5 else { return nil }
        let same = values.filter { $0 / usual < limit }.count
        if same * 2 >= values.count {
            return "This happens on \(same) of your last \(values.count) videos too. Fixing it helps your whole channel."
        }
        return "Your other videos mostly don't have this problem. It's just this one."
    }

    /// Likes, comments and shares are a side note, never the main fix.
    private static func engagementNote(video: Video, others: [Video], bottleneck: FunnelStep?) -> String? {
        guard let mine = video.engagementPer1K else { return nil }
        let values = others.compactMap { $0.engagementPer1K }.filter { $0 > 0 }.sorted()
        guard values.count >= 5 else { return nil }
        let usual = values[values.count / 2]
        guard usual > 0, mine / usual < 0.5 else { return nil }
        return "Also: fewer likes and comments than usual. End with one simple question people can answer in the comments."
    }

    // MARK: Formatting

    private static func pct0(_ value: Double?) -> String { "\(Int(((value ?? 0) * 100).rounded()))%" }
    private static func pct1(_ value: Double?) -> String { String(format: "%.1f%%", (value ?? 0) * 100) }
    private static func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    /// "davinci resolve split clip" -> "davinci-resolve-split-clip.jpg"
    static func fileName(from text: String) -> String {
        let main = text.components(separatedBy: CharacterSet(charactersIn: "|:(")).first ?? text
        let words = main.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(8)
        return words.isEmpty ? "your-search-words.jpg" : words.joined(separator: "-") + ".jpg"
    }
}

private extension DiagnosisContent {
    static let loadingContent = DiagnosisContent(
        kind: .loading, label: "YOUR NEXT FIX", tag: nil,
        title: "Still getting this video's numbers.",
        evidence: ["Check back in a minute."], showTraffic: false, searchTerms: [],
        actionIntro: nil, actionText: nil, seoPhrase: nil, seoFileName: nil,
        example: nil, pattern: nil, extraNote: nil, whyText: "")

    static let tooEarlyContent = DiagnosisContent(
        kind: .tooEarly, label: "TOO EARLY", tag: nil,
        title: "Give it 2 days.",
        evidence: ["YouTube is still testing this video with small groups of people. The numbers will mean more soon."],
        showTraffic: false, searchTerms: [],
        actionIntro: nil, actionText: nil, seoPhrase: nil, seoFileName: nil,
        example: nil, pattern: nil, extraNote: nil, whyText: "")
}
