import SwiftUI

// =============================================================
// MARK: - FIRST LOOK (after connecting a channel)
// Shows ONCE, right after someone connects their channel.
//
// What a struggling creator wants to hear here:
//   1. "You really looked at MY channel"   -> their picture, name, real numbers
//   2. "It's not hopeless"                 -> their own best video as proof
//   3. "I know what to do next"            -> "Your first fix is ready"
//
// It loads the real channel while it plays, so the paywall that
// follows already knows their name and sub count.
// Signed-in users who have already seen it skip it on every later launch.
// Uses HomeLook (DashboardView), ThinkingSpark (CoachReviewView),
// SceneClock + Haptics (WelcomeView).
// =============================================================

struct AnalysisLoadingView: View {

    var onComplete: () -> Void

    private static let seenKey = "subsai.hasSeenGrowthPlanIntro"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var skip: Bool
    @State private var channel: Channel?
    @State private var best: YouTubeService.BestVideo?
    @State private var shownSteps = 0         // how many checklist rows are on screen
    @State private var doneSteps = 0          // how many checklist rows are ticked
    @State private var isDone = false

    /// Call on sign out, disconnect, or leaving demo mode, so the next
    /// channel connected sees this screen again.
    static func resetIntro() {
        UserDefaults.standard.removeObject(forKey: seenKey)
    }

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _skip = State(initialValue: UserDefaults.standard.bool(forKey: Self.seenKey))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            HomeLook.ink.ignoresSafeArea()

            // Soft purple light from the top, like the app's header
            RadialGradient(
                colors: [HomeLook.purple.opacity(0.55), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()

            if !skip {
                content
            }
        }
        .preferredColorScheme(.dark)
        .task { await run() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            avatarBlock
                .padding(.bottom, 26)

            Text(isDone ? "Good news. Your channel can grow." : "Getting to know your channel")
                .font(.system(size: 27, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .id(isDone)
                .transition(.opacity)

            if let line = channelLine {
                Text(line)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .transition(.opacity)
            }

            checklist
                .padding(.horizontal, 24)
                .padding(.top, 28)

            if isDone {
                Text(reassurance)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 22)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: 20)

            Button(action: finish) {
                Text("Show me my first fix")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [HomeLook.purpleLight, HomeLook.purple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(isDone ? 1 : 0)
            .disabled(!isDone)
        }
    }

    // MARK: - Their picture, with the purple spark working behind it

    private var avatarBlock: some View {
        ZStack {
            if !isDone && !reduceMotion {
                ThinkingSpark(size: 150, color: HomeLook.purpleLight.opacity(0.55))
                    .transition(.opacity)
            }
            Circle()
                .stroke(isDone ? HomeLook.purpleLight : Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 98, height: 98)

            avatar
                .frame(width: 86, height: 86)
                .clipShape(Circle())

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(HomeLook.purple))
                    .overlay(Circle().stroke(HomeLook.ink, lineWidth: 3))
                    .offset(x: 34, y: 34)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 150, height: 150)
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = channel?.profilePicURL, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                iconFallback
            }
        } else {
            iconFallback
        }
    }

    private var iconFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Checklist (real numbers, ticked one by one)

    private struct Step: Identifiable {
        let id: Int
        let text: String
    }

    /// While a row is working it says what it's doing. When it ticks, it shows what we found.
    private var steps: [Step] {
        var list: [Step] = []

        let videos = channel?.videoCount ?? 0
        if doneSteps < 1 {
            list.append(Step(id: 0, text: "Finding your videos…"))
        } else {
            list.append(Step(id: 0, text: videos > 0 ? "Found your \(videos.formatted()) videos" : "Found your channel"))
        }

        let views = channel?.totalViews ?? 0
        if doneSteps < 2 {
            list.append(Step(id: 1, text: "Adding up your views…"))
        } else {
            list.append(Step(id: 1, text: views > 0 ? "\(Self.short(views)) views so far" : "Read your views and watch time"))
        }

        if doneSteps < 3 {
            list.append(Step(id: 2, text: "Finding your best video…"))
        } else if let best, best.views > 0 {
            let title = best.title.isEmpty ? "" : "\"\(best.title)\" · "
            list.append(Step(id: 2, text: "Best video: \(title)\(Self.short(best.views)) views"))
        } else {
            list.append(Step(id: 2, text: "Checked your best videos"))
        }

        list.append(Step(id: 3, text: doneSteps < 4 ? "Picking your first fix…" : "Your first fix is ready"))
        return list
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Findings show up one at a time: appear, work for a moment, then tick
            ForEach(steps.filter { $0.id < shownSteps }) { step in
                HStack(spacing: 12) {
                    stepIcon(step.id)
                    Text(step.text)
                        .font(.system(size: 15, weight: step.id < doneSteps ? .semibold : .regular))
                        .foregroundColor(step.id < doneSteps ? .white : .white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .opacity(shownSteps > 0 ? 1 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func stepIcon(_ index: Int) -> some View {
        if index < doneSteps {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(HomeLook.purple))
                .transition(.scale.combined(with: .opacity))
        } else if index == doneSteps && !reduceMotion {
            ThinkingSpark(size: 22, color: HomeLook.purpleLight)
        } else {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }

    // MARK: - Words

    /// Proof from their own channel that growth is possible
    private var reassurance: String {
        if let best, best.views >= 100 {
            return "Your best video got \(Self.short(best.views)) views. That proves people want what you make. Now let's do it again, one fix at a time."
        }
        return "Every big channel started small. We'll show you the one thing to fix first, then the next."
    }

    /// "TechGrowth Daily · 742 subs". Leaves out anything that isn't real.
    private var channelLine: String? {
        guard let channel else { return nil }
        let name = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != "Unknown Channel" else { return nil }

        let subsKnown = channel.subscribersHidden == false
            || (channel.subscribersHidden == nil && channel.subscribers > 0)
        guard subsKnown else { return name }
        return "\(name) · \(channel.subscribers.formatted()) subs"
    }

    private static func short(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000    { return String(format: "%.0fK", Double(n) / 1_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return n.formatted()
    }

    // MARK: - Logic

    private func run() async {
        // Already seen: skip straight through, but warm up the channel for the paywall
        if skip {
            Task { _ = await YouTubeService.shared.fetchChannel(timeout: 8) }
            onComplete()
            return
        }

        Haptics.warmUp()

        // Load both at once. Each row ticks when its data is in AND it has had its moment
        // on screen, so it never flashes by, and never waits more than 8 seconds.
        let channelTask = Task { await YouTubeService.shared.fetchChannel(timeout: 8) }
        let bestTask = Task { await YouTubeService.shared.fetchBestVideo() }
        let clock = SceneClock()

        // About 8 seconds in all. Each finding: shows up, works ~1.4s, then ticks.
        // Row 1: videos
        await show(1, at: 0.6, clock: clock)
        let loaded = await channelTask.value
        withAnimation(.easeOut(duration: 0.3)) { channel = loaded }
        await tick(to: 1, at: 2.0, clock: clock)

        // Row 2: views
        await show(2, at: 2.4, clock: clock)
        await tick(to: 2, at: 3.8, clock: clock)

        // Row 3: best video (gives up after 8s so nobody is stuck here)
        await show(3, at: 4.2, clock: clock)
        let found = await Self.firstOf(bestTask, orNilAfter: 8)
        await tick(to: 3, at: 5.8, clock: clock, then: { best = found })

        // Row 4: first fix
        await show(4, at: 6.2, clock: clock)
        await tick(to: 4, at: 7.6, clock: clock)

        _ = await clock.wait(until: 8.2)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isDone = true }
        Haptics.success()
    }

    /// Puts the next finding on screen (still working)
    private func show(_ count: Int, at seconds: Double, clock: SceneClock) async {
        let onTime = await clock.wait(until: seconds)
        guard !Task.isCancelled else { return }
        sceneStep(onTime, .spring(response: 0.45, dampingFraction: 0.85)) {
            shownSteps = count
        }
    }

    /// The task's result, or nil if it takes longer than `seconds`
    private static func firstOf(_ task: Task<YouTubeService.BestVideo?, Never>,
                                orNilAfter seconds: Double) async -> YouTubeService.BestVideo? {
        await withTaskGroup(of: YouTubeService.BestVideo?.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Ticks rows up to `count`, no earlier than `seconds` after the screen opened
    private func tick(to count: Int, at seconds: Double, clock: SceneClock, then update: () -> Void = {}) async {
        let onTime = await clock.wait(until: seconds)
        guard !Task.isCancelled else { return }
        sceneStep(onTime, .spring(response: 0.35, dampingFraction: 0.75)) {
            update()
            doneSteps = count
        }
        if onTime { Haptics.tap() }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        onComplete()
    }
}
