import SwiftUI

struct AnalysisLoadingView: View {

    @State private var currentStep = 0
    @State private var progress: Double = 0
    @State private var isDone = false
    @State private var pulsing = false

    private let steps = [
        "Connecting to your YouTube channel...",
        "Reading your video library...",
        "Analyzing performance patterns...",
        "Discovering what makes your videos work...",
        "Finding your unique winning formula...",
        "Building your personalized growth strategy..."
    ]

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Smart Coach Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.08))
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulsing ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulsing)

                    Image(systemName: isDone ? "sparkles" : "brain.head.profile")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.accent)
                        .animation(.easeInOut(duration: 0.4), value: isDone)
                }
                .padding(.bottom, 40)

                // Headline
                VStack(spacing: 10) {
                    Text(isDone ? "Your personal YouTube coach is ready" : "Analyzing your channel")
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: isDone)

                    Text(isDone
                         ? "Let's turn your data into real growth."
                         : "We're studying your videos like a top coach would."
                    )
                    .font(.system(size: 15.5))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 48)

                // Progress Area
                VStack(spacing: 14) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.cardBackground)
                                .frame(height: 7)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.accent)
                                .frame(width: geo.size.width * progress, height: 7)
                                .animation(.easeInOut(duration: 0.7), value: progress)
                        }
                    }
                    .frame(height: 7)
                    .padding(.horizontal, 48)

                    Text(currentStep < steps.count ? steps[currentStep] : steps.last!)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut, value: currentStep)
                }
                .padding(.bottom, 60)

                Spacer()

                // Final CTA - Only shows when done
                if isDone {
                    Button {
                        onComplete()
                    } label: {
                        Text("Show me my insights")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
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
        let stepDurations: [Double] = [0.7, 1.1, 1.3, 1.2, 1.0, 0.8]
        var elapsed = 0.0

        for (index, duration) in stepDurations.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + elapsed) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep = index
                    progress = Double(index + 1) / Double(steps.count)
                }
            }
            elapsed += duration
        }

        // Finish
        DispatchQueue.main.asyncAfter(deadline: .now() + elapsed + 0.4) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isDone = true
                progress = 1.0
            }
        }
    }
}
