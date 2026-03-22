// Features/Onboarding/WelcomeView.swift
import SwiftUI

struct WelcomeView: View {

    @State private var currentPage = 0
    @State private var animateIn = false

    private let pages: [WelcomePage] = [
        WelcomePage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: Color(red: 0.4, green: 0.6, blue: 1.0),
            headline: "Know exactly what's working",
            body: "See which videos are growing your channel and which ones are holding you back — with data from your actual channel, not generic benchmarks."
        ),
        WelcomePage(
            icon: "figure.mind.and.body",
            iconColor: Color(red: 0.5, green: 0.85, blue: 0.6),
            headline: "A coach, not just a dashboard",
            body: "SubsAI tells you what to fix before your next upload — specific, actionable, based on your own patterns."
        ),
        WelcomePage(
            icon: "clock.badge.checkmark",
            iconColor: Color(red: 1.0, green: 0.7, blue: 0.3),
            headline: "Built for creators who are serious",
            body: "Stop guessing why some videos pop and others don't. Your data has the answer. SubsAI surfaces it."
        )
    ]

    var onContinue: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip button
                HStack {
                    Spacer()
                    Button {
                        onContinue()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index == currentPage ? AppTheme.accent : AppTheme.borderSubtle)
                            .frame(width: index == currentPage ? 20 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // CTA
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onContinue()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.accent)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
    }

    private func pageView(_ page: WelcomePage) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: page.icon)
                    .font(.system(size: 40))
                    .foregroundColor(page.iconColor)
            }

            VStack(spacing: 12) {
                Text(page.headline)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(page.body)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct WelcomePage {
    let icon: String
    let iconColor: Color
    let headline: String
    let body: String
}
