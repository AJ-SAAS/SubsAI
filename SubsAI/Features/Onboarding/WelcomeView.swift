import SwiftUI

struct WelcomeView: View {
    
    @State private var currentPage = 0
    @State private var animateIn = false
    
    private let pages: [OnboardingPage] = [
        
        OnboardingPage(
            headline: "Welcome to SubsAI",
            body: "The AI coach built for YouTubers who are ready to grow faster.",
            quote: "I doubled my views with SubsAI",
            illustration: "Person5",
            trustLine: "Built for monetized YouTube creators",
            trustAvatar: "AppIconImage",
            isFinal: false
        ),
        
        OnboardingPage(
            headline: "You're posting. Now let's grow.",
            body: "You've done the hard part. SubsAI shows you exactly what to do next.",
            quote: "Best YouTube coach I’ve used",
            illustration: "chart.bar.xaxis",
            trustLine: "\"Best YouTube coach I’ve used\"",
            trustAvatar: "Person1",
            isFinal: false
        ),
        
        OnboardingPage(
            headline: "Find the pattern in your top videos",
            body: "Your best videos already know the formula. We just show you what it is.",
            quote: "I wish I had this sooner.",
            illustration: "waveform.path.ecg",
            trustLine: "\"I wish I had this sooner.\"",
            trustAvatar: "Person2",
            isFinal: false
        ),
        
        OnboardingPage(
            headline: "Turn good videos into great ones",
            body: "Small tweaks to titles, hooks and structure — big jumps in views and revenue.",
            quote: "It just works.",
            illustration: "trophy.fill",
            trustLine: "\"It just works.\"",
            trustAvatar: "Person3",
            isFinal: false
        ),
        
        OnboardingPage(
            headline: "Get your first insight in 60 seconds",
            body: "Connect your channel. See instantly where your growth is hiding.",
            quote: "I finally understand what’s driving my views.",
            illustration: "bolt.fill",
            trustLine: "\"I finally understand what’s driving my views.\"",
            trustAvatar: "Person4",
            isFinal: true
        )
    ]
    
    var onContinue: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            
            ZStack {
                
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(.displayP3, red: 0.1, green: 0.0, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Progress
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: index == currentPage ? 28 : 8, height: 6)
                        }
                    }
                    .padding(.top, 16)
                    
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            pageContent(page, index: index, geo: geo)
                                .tag(index)
                                .id(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    VStack(spacing: 18) {
                        
                        Button {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                onContinue()
                            }
                        } label: {
                            Text(buttonTitle)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color(red: 0.45, green: 0.2, blue: 0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
                        
                        HStack(spacing: 10) {
                            
                            Image(pages[currentPage].trustAvatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(Circle())
                            
                            Text(pages[currentPage].trustLine)
                                .font(.system(size: 14, weight: .bold))
                                .italic()
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 40)
                        .modifier(Shimmer())
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                animateIn = true
            }
        }
    }
    
    private var buttonTitle: String {
        currentPage == pages.count - 1 ? "Start Growing 🚀" : "Continue"
    }
    
    private func pageContent(_ page: OnboardingPage, index: Int, geo: GeometryProxy) -> some View {
        
        let imageSize = min(geo.size.width * 0.52, 260)   // Reduced size
        
        return VStack(spacing: 18) {
            
            Spacer(minLength: 24)
            
            VStack(spacing: 12) {
                
                Text(page.headline)
                    .modifier(OnboardingHeadlineStyle())
                    .padding(.horizontal, 24)
                
                Text(page.body)
                    .modifier(OnboardingBodyStyle())
                    .padding(.horizontal, 24)
            }
            .frame(width: geo.size.width)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 10)
            
            if page.illustration == "Person5" {
                
                VStack(spacing: 12) {
                    
                    ZStack {
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.purple.opacity(0.35),
                                        Color.blue.opacity(0.20),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: imageSize * 0.9
                                )
                            )
                            .frame(width: imageSize * 1.4, height: imageSize * 1.4)
                            .blur(radius: 20)
                        
                        Image("Person5")
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageSize, height: imageSize)
                            .clipShape(Circle())
                    }
                    
                    VStack(spacing: 6) {
                        
                        Text("\"\(page.quote)\"")
                            .font(.system(size: 16, weight: .bold))
                            .italic()
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                
            } else {
                
                // Light purple illustrations (less "in your face")
                Image(systemName: page.illustration)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
                    .foregroundColor(AppTheme.accent.opacity(0.75))   // Light purple
            }
            
            Spacer(minLength: 30)
        }
        .opacity(currentPage == index ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

// MARK: - MODEL
struct OnboardingPage {
    let headline: String
    let body: String
    let quote: String
    let illustration: String
    let trustLine: String
    let trustAvatar: String
    let isFinal: Bool
}

// MARK: - TYPOGRAPHY
struct OnboardingHeadlineStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 30, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .truncationMode(.tail)
    }
}

struct OnboardingBodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17))
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.9)
            .truncationMode(.tail)
    }
}

// MARK: - SHIMMER
struct Shimmer: ViewModifier {
    
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.25), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 250)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
