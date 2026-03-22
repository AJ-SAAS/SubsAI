// Features/Onboarding/AnalysisLoadingView.swift
import SwiftUI

struct AnalysisLoadingView: View {

    @State private var currentStep = 0
    @State private var progress: Double = 0
    @State private var isDone = false
    @State private var pulsing = false

    private let steps = [
        "Connecting to your channel…",
        "Loading your video library…",
        "Analysing performance data…",
        "Finding your winning patterns…",
        "Calculating your growth score…",
        "Almost ready…"
    ]

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.08))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulsing ? 1.12 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                    Image(systemName: isDone ? "checkmark" : "brain.head.profile")
                        .font(.system(size: 38))
                        .foregroundColor(AppTheme.accent)
                        .animation(.easeInOut(duration: 0.3), value: isDone)
                }
                .padding(.bottom, 36)

                // Headline
                VStack(spacing: 8) {
                    Text(isDone ? "Your channel is ready." : "Analysing your channel")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .animation(.easeInOut, value: isDone)

                    Text(isDone
                         ? "Here's what we found."
                         : "This only takes a moment."
                    )
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom, 40)

                // Progress bar
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.cardBackground)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.accent)
                                .frame(
                                    width: geo.size.width * progress,
                                    height: 6
                                )
                                .animation(.easeInOut(duration: 0.6), value: progress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 48)

                    // Current step label
                    Text(currentStep < steps.count ? steps[currentStep] : steps.last!)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textTertiary)
                        .animation(.easeInOut, value: currentStep)
                }
                .padding(.bottom, 48)

                Spacer()

                // Continue button — only shows when done
                if isDone {
                    Button {
                        onComplete()
                    } label: {
                        Text("See my insights")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            pulsing = true
            runSteps()
        }
    }

    private func runSteps() {
        // Simulate progressive loading steps
        // In real usage this is driven by coachVM.isLoading
        let stepDurations: [Double] = [0.6, 1.0, 1.2, 1.0, 0.8, 0.6]
        var elapsed = 0.0

        for (index, duration) in stepDurations.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + elapsed) {
                withAnimation {
                    currentStep = index
                    progress = Double(index + 1) / Double(steps.count)
                }
            }
            elapsed += duration
        }

        // Mark done after all steps
        DispatchQueue.main.asyncAfter(deadline: .now() + elapsed + 0.3) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isDone = true
                progress = 1.0
            }
        }
    }
}
