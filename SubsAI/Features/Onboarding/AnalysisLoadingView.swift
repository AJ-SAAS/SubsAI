import SwiftUI

// =============================================================
// MARK: - ANALYSIS LOADING
// Shows ONCE, right after someone connects their channel.
// It loads the real channel while it plays, so the paywall that
// follows already knows their name and sub count.
//
// Signed-in users who have already seen it skip it on every
// later launch (it calls onComplete right away).
// =============================================================

struct AnalysisLoadingView: View {

    var onComplete: () -> Void

    private static let seenKey = "subsai.hasSeenGrowthPlanIntro"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var skip: Bool
    @State private var channel: Channel?
    @State private var stepIndex = 0
    @State private var progress: Double = 0
    @State private var isDone = false
    @State private var pulsing = false

    private let steps = [
        "Loading your videos",
        "Finding what works",
        "Building your plan"
    ]

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
            // Same purple gradient as Dashboard + Intelligence
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.65),
                    AppTheme.accent.opacity(0.30),
                    AppTheme.accent.opacity(0.08),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !skip {
                content
            }
        }
        .task { await run() }
    }

    private var content: some View {
        VStack(spacing: 0) {

            Spacer()

            // Icon: their channel picture once it loads
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulsing ? 1.12 : 0.95)

                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 114, height: 114)
                    .scaleEffect(pulsing ? 1.07 : 0.97)

                avatar
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.6), lineWidth: 1.5))

                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                        .offset(x: 32, y: 32)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .padding(.bottom, 26)

            // Headline
            Text(isDone ? "Your growth plan is ready" : "Building your growth plan")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 28)
                .id(isDone)
                .transition(.opacity)

            // Their channel, so they know it's really theirs
            if let line = channelLine {
                Text(line)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .transition(.opacity)
            }

            // Progress + one short status line
            VStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.357, green: 0.129, blue: 0.647), AppTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 8) {
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.75)
                    }
                    Text(isDone ? "All done" : steps[stepIndex])
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .id(stepIndex)
                        .transition(.opacity)
                }
                .foregroundColor(.white.opacity(0.7))
                .frame(height: 20)
            }
            .padding(.horizontal, 48)
            .padding(.top, 32)

            Spacer()

            // Button (only when done)
            Button(action: finish) {
                Text("See My Plan")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.357, green: 0.129, blue: 0.647), AppTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: AppTheme.accent.opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
            .opacity(isDone ? 1 : 0)
            .disabled(!isDone)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var avatar: some View {
        if let urlString = channel?.profilePicURL, let url = URL(string: urlString), !urlString.isEmpty {
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
            AppTheme.accent.opacity(0.3)
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
    }

    /// "TechGrowth Daily · 742 subs". Leaves out anything that isn't real.
    private var channelLine: String? {
        guard let channel else { return nil }
        let name = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != "Unknown Channel" else { return nil }

        let subsKnown = channel.subscribersHidden == false
            || (channel.subscribersHidden == nil && channel.subscribers > 0)
        guard subsKnown else { return name }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let subs = formatter.string(from: NSNumber(value: channel.subscribers)) ?? "\(channel.subscribers)"
        return "\(name) · \(subs) subs"
    }

    // MARK: - Logic

    private func run() async {
        // Already seen: skip straight through, but warm up the channel for the paywall
        if skip {
            Task { _ = await YouTubeService.shared.fetchChannel(timeout: 8) }
            onComplete()
            return
        }

        if !reduceMotion { pulsing = true }

        let started = Date()

        // Start loading the real channel right away
        let loader = Task { await YouTubeService.shared.fetchChannel(timeout: 8) }

        // Step 1
        withAnimation(.easeInOut(duration: 0.6)) { progress = 0.25 }
        try? await Task.sleep(nanoseconds: 1_100_000_000)

        // Step 2
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex = 1 }
        withAnimation(.easeInOut(duration: 0.6)) { progress = 0.55 }

        // Show the channel as soon as it lands
        let loaded = await loader.value
        withAnimation(.easeOut(duration: 0.3)) { channel = loaded }

        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 2.2 {
            try? await Task.sleep(nanoseconds: UInt64((2.2 - elapsed) * 1_000_000_000))
        }

        // Step 3
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex = 2 }
        withAnimation(.easeInOut(duration: 0.6)) { progress = 0.85 }
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Done
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            progress = 1
            isDone = true
            pulsing = false
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        onComplete()
    }
}
