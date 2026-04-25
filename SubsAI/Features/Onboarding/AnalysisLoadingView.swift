import SwiftUI

struct AnalysisLoadingView: View {

    @State private var currentStep = 0
    @State private var progress: Double = 0
    @State private var isDone = false
    @State private var pulsing = false
    @State private var visibleInsights: Set<Int> = []
    @State private var progressLabel = "Getting started…"

    // MARK: - Data

    private let steps = [
        "Connecting to YouTube",
        "Loading your videos",
        "Scanning analytics",
        "Finding patterns",
        "Building your plan"
    ]

    private let insights: [(emoji: String, title: String, sub: String)] = [
        ("👁️", "Thumbnails drive 70% of clicks",  "Your title gets read after the thumbnail hooks them."),
        ("⏱️", "First 30 seconds is everything",   "Viewers decide to stay or leave in under 30 seconds."),
        ("📈", "Top 20% drive most views",         "Growth comes from repeating what already works.")
    ]

    // Timing: each step fires at this delay (seconds)
    private let stepTimings:    [Double] = [0.6, 1.3, 2.0, 2.8, 3.5]
    private let insightTimings: [Double] = [1.1, 2.3, 3.3]
    private let completionTime: Double   = 4.5

    var onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {

            // ── Same purple gradient as Dashboard + Intelligence ───────────
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

            VStack(spacing: 0) {
                RadialGradient(
                    colors: [AppTheme.accent.opacity(0.30), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 380
                )
                .frame(height: 360)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }

            // ── Main content ──────────────────────────────────────────────
            VStack(spacing: 0) {

                // ── ICON — layered pulse rings, sits high ─────────────────
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(AppTheme.accent.opacity(0.07))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulsing ? 1.14 : 0.94)
                        .animation(
                            .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                            value: pulsing
                        )

                    // Mid ring
                    Circle()
                        .fill(AppTheme.accent.opacity(0.13))
                        .frame(width: 106, height: 106)
                        .scaleEffect(pulsing ? 1.09 : 0.96)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2),
                            value: pulsing
                        )

                    // Core
                    Circle()
                        .fill(AppTheme.accent.opacity(0.25))
                        .frame(width: 78, height: 78)
                        .overlay(
                            Circle().stroke(AppTheme.accent.opacity(0.55), lineWidth: 1)
                        )

                    Image(systemName: isDone ? "checkmark.seal.fill" : "chart.bar.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                        .animation(.easeInOut(duration: 0.3), value: isDone)
                }
                .padding(.bottom, 18)

                // ── HEADLINE ─────────────────────────────────────────────
                Text(isDone ? "Your growth plan is ready" : "Understanding your channel")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.4), value: isDone)
                    .padding(.bottom, 8)

                Text(isDone
                     ? "We found what's working — and what to fix."
                     : "Analysing your channel data."
                )
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.4), value: isDone)
                .padding(.bottom, 24)

                // ── PROGRESS BAR ──────────────────────────────────────────
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 99)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.357, green: 0.129, blue: 0.647),
                                            AppTheme.accent.opacity(0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text(progressLabel)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

                // ── TWO-COLUMN LAYOUT ─────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {

                    // LEFT — steps
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What we're doing")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .padding(.bottom, 12)

                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                stepCircle(index: index)
                                Text(step)
                                    .font(.system(
                                        size: 14,
                                        weight: index == currentStep ? .semibold : .medium,
                                        design: .rounded
                                    ))
                                    .foregroundColor(
                                        index < currentStep  ? .white.opacity(0.4) :
                                        index == currentStep ? .white :
                                        .white.opacity(0.3)
                                    )
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 14)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // RIGHT — insights
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Did you know?")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .padding(.bottom, 2)

                        ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                            insightCard(insight, visible: visibleInsights.contains(index))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)

                // ── CTA — slides up flush below columns, no dead space ────
                if isDone {
                    Button {
                        onComplete()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Give me access now!")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("🚀")
                                .font(.system(size: 18))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.357, green: 0.129, blue: 0.647),
                                    AppTheme.accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: AppTheme.accent.opacity(0.45), radius: 14, x: 0, y: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.top, 52)
            .padding(.bottom, 44)
        }
        .onAppear {
            pulsing = true
            runSteps()
        }
    }

    // MARK: - Step circle

    @ViewBuilder
    private func stepCircle(index: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    index < currentStep
                        ? AppTheme.accent
                        : index == currentStep
                            ? AppTheme.accent.opacity(0.15)
                            : Color.white.opacity(0.06)
                )
                .frame(width: 18, height: 18)
                .overlay(
                    Circle().stroke(
                        index < currentStep
                            ? AppTheme.accent
                            : index == currentStep
                                ? AppTheme.accent.opacity(0.7)
                                : Color.white.opacity(0.15),
                        lineWidth: 0.5
                    )
                )

            if index < currentStep {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        index == currentStep
                            ? AppTheme.accent
                            : .white.opacity(0.3)
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .frame(width: 18, height: 18)
        .padding(.top, 1)
    }

    private func insightCard(_ insight: (emoji: String, title: String, sub: String), visible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(insight.emoji)
                .font(.system(size: 20))
            Text(insight.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.sub)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.14))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 0.5)
        )
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 5)
        .animation(.easeOut(duration: 0.4), value: visible)
    }

    // MARK: - Animation logic

    private func runSteps() {
        let stepLabels = [
            "Connecting…",
            "Loading videos…",
            "Scanning analytics…",
            "Finding patterns…",
            "Building your plan…"
        ]

        for (index, timing) in stepTimings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + timing) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = index
                    progress = Double(index + 1) / Double(steps.count + 1)
                    progressLabel = stepLabels[index]
                }
            }
        }

        for (index, timing) in insightTimings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + timing) {
                withAnimation {
                    _ = visibleInsights.insert(index)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + completionTime) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isDone = true
                progress = 1.0
                currentStep = steps.count
                progressLabel = "Done!"
            }
        }
    }
}

// Note: Color(hex:) extension already defined elsewhere in this project.
