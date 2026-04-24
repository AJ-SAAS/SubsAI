import SwiftUI

struct AnalysisLoadingView: View {

    @State private var currentStep = 0
    @State private var progress: Double = 0
    @State private var isDone = false
    @State private var pulsing = false

    private let steps = [
        "Connecting to YouTube",
        "Loading last 30 days",
        "Scanning your videos",
        "Top 20% drive most views",
        "Biggest drop: first 10–20 seconds",
        "70% of clicks = thumbnails",
        "Building your growth plan"
    ]

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ICON
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.08))
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulsing ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulsing)

                    Image(systemName: isDone ? "checkmark.seal.fill" : "waveform.path.ecg")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.bottom, 40)

                // HEADLINE
                VStack(spacing: 10) {
                    Text(isDone ? "Your growth plan is ready" : "Understanding your channel")
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(isDone
                         ? "We turned your data into clear next steps."
                         : "We’re finding what actually drives your views."
                    )
                    .font(.system(size: 15.5))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)

                // CHECKLIST
                VStack(spacing: 12) {

                    ForEach(0..<steps.count, id: \.self) { index in
                        HStack(spacing: 12) {

                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    .frame(width: 22, height: 22)

                                if index < currentStep {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .transition(.scale)
                                }
                            }

                            Text(steps[index])
                                .font(.system(size: 14.5, weight: .medium))
                                .foregroundColor(.white)
                                .opacity(index <= currentStep ? 1 : 0.4)

                            Spacer()
                        }
                        .padding(.horizontal, 32)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.bottom, 40)

                // PROGRESS BAR
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.accent)
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 48)
                }

                Spacer()

                // CTA
                if isDone {
                    Button {
                        onComplete()
                    } label: {
                        Text("See my growth plan")
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

    // MARK: - Animation logic
    private func runSteps() {
        let stepDurations: [Double] = [0.7, 1.0, 1.2, 1.1, 1.0, 0.9]
        var elapsed = 0.0

        for (index, duration) in stepDurations.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + elapsed) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = index
                    progress = Double(index + 1) / Double(steps.count)
                }
            }
            elapsed += duration
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + elapsed + 0.4) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isDone = true
                progress = 1.0
                currentStep = steps.count
            }
        }
    }
}
