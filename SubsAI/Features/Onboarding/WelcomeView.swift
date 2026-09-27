import SwiftUI

// =============================================================
// MARK: - WELCOME / ONBOARDING (3 screens)
// Screen 1: 2am stats (PersonNight image + stats card that won't move)
// Screen 2: Road to 1M subs (glowing road + confetti)
// Screen 3: growth plan reveal (videos into orb, 3 cards, summary)
// =============================================================

struct WelcomeView: View {
    
    @State private var currentPage = 0
    @State private var animateIn = false
    @State private var pulse = false
    
    /// When each page's animation is done, so the button can nudge once
    private let pageDurations: [Double] = [2.2, 4.4, 7.0]
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(kind: .night, trustLine: "Built for YouTubers who want to grow", trustAvatar: "AppIconImage"),
        OnboardingPage(kind: .road,  trustLine: "Built for YouTubers who want to grow", trustAvatar: "AppIconImage"),
        OnboardingPage(kind: .tips,  trustLine: "Built for YouTubers who want to grow", trustAvatar: "AppIconImage")
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
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
                    
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
                                .contentTransition(.opacity)
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
                        .scaleEffect(pulse ? 1.04 : 1)
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
        // One gentle pulse on the button when the page's animation is done.
        // (No auto-swipe: people read at different speeds.)
        .task(id: currentPage) {
            pulse = false
            let wait = pageDurations[min(currentPage, pageDurations.count - 1)]
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) { pulse = true }
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeInOut(duration: 0.25)) { pulse = false }
        }
    }
    
    private var buttonTitle: String {
        currentPage == pages.count - 1 ? "Connect Channel & Start Growing 🚀" : "Continue"
    }
    
    private func pageContent(_ page: OnboardingPage, index: Int, geo: GeometryProxy) -> some View {
        
        let imageSize = min(geo.size.width * 0.78, 330)
        let corner = imageSize * 0.12
        let isActive = currentPage == index
        
        return VStack(spacing: 28) {
            
            Spacer(minLength: 24)
            
            // Animated title (plays first)
            // Restarts by itself when the page opens (no rebuild needed)
            OnboardingTitle(kind: page.kind, isActive: isActive)
                .padding(.horizontal, 24)
                .frame(width: geo.size.width)
            
            ZStack {
                
                // Soft glow behind the square
                RoundedRectangle(cornerRadius: corner * 1.4, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.35),
                                Color.blue.opacity(0.20),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: imageSize * 0.95
                        )
                    )
                    .frame(width: imageSize * 1.35, height: imageSize * 1.35)
                    // (no .blur: a live blur this big is slow; the gradient is already soft)
                
                // Animated visual (plays right after the title)
                visual(for: page.kind, isActive: isActive, size: imageSize)
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            
            Spacer(minLength: 30)
        }
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
    
    @ViewBuilder
    private func visual(for kind: OnboardingPage.Kind, isActive: Bool, size: CGFloat) -> some View {
        switch kind {
        case .night:
            NightStatsScene(isActive: isActive)
        case .road:
            ZStack {
                Color.white.opacity(0.06)
                RoadmapView(isActive: isActive)
                    .padding(size * 0.06)
            }
        case .tips:
            ZStack {
                Color.white.opacity(0.06)
                TipsRevealView(isActive: isActive)
                    .padding(16)
            }
        }
    }
}

// MARK: - SCENE CLOCK
// Every animation step has a fixed time on a timeline (like a video).
// If the phone is busy for a moment, steps that are already late SNAP into place
// instead of waiting in a queue and then all playing at once (the old "freeze, then rush").
struct SceneClock {
    let start = Date()

    /// Waits until `seconds` after the scene started.
    /// Returns true if we're on time (so animate), false if we're late (so snap).
    func wait(until seconds: Double) async -> Bool {
        let target = start.addingTimeInterval(seconds)
        let delay = target.timeIntervalSinceNow
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        return Date().timeIntervalSince(target) < 0.2
    }
}

/// Animate when on time, snap (no animation) when late
func sceneStep(_ onTime: Bool, _ animation: Animation, _ body: () -> Void) {
    if onTime {
        withAnimation(animation, body)
    } else {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, body)
    }
}

// MARK: - MODEL
struct OnboardingPage {
    enum Kind { case night, road, tips }
    let kind: Kind
    let trustLine: String
    let trustAvatar: String
}

// MARK: - COLORS
enum OB {
    static let purple   = Color(red: 0.55, green: 0.30, blue: 1.00)
    static let pink     = Color(red: 1.00, green: 0.45, blue: 0.80)
    static let gold     = Color(red: 0.96, green: 0.72, blue: 0.24)
    static let softRed  = Color(red: 1.00, green: 0.54, blue: 0.54)
    static let green    = Color(red: 0.49, green: 0.95, blue: 0.60)
    static let orange   = Color(red: 1.00, green: 0.54, blue: 0.36)
    static let lilac    = Color(red: 0.84, green: 0.79, blue: 1.00)
    static let muted    = Color(red: 0.65, green: 0.62, blue: 0.74)
    static let cardFill = Color(red: 0.12, green: 0.08, blue: 0.25)
    static let rowFill  = Color(red: 0.09, green: 0.07, blue: 0.15)
    static let rowLine  = Color(red: 0.17, green: 0.13, blue: 0.25)
    static let barDim   = Color(red: 0.23, green: 0.16, blue: 0.44)
}

// =============================================================
// MARK: - ANIMATED TITLE
// Fades and slides up. Screen 2 comes in line by line, last line gold.
// =============================================================

struct OnboardingTitle: View {
    
    let kind: OnboardingPage.Kind
    let isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [Bool] = [false, false, false]
    
    private var lines: [Text] {
        switch kind {
        case .night:
            return [
                Text("Stop checking your"),
                Text("stats at ") + Text("2am").foregroundColor(OB.softRed)
            ]
        case .road:
            return [
                Text("Get more views."),
                Text("Get more subs."),
                Text("Monetize faster.").foregroundColor(OB.gold)
            ]
        case .tips:
            return [
                Text("Get your growth plan"),
                Text("in ") + Text("60 seconds").foregroundColor(OB.gold)
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                line
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(shown[i] ? 1 : 0)
                    .offset(y: shown[i] ? 0 : 12)
                    .scaleEffect(kind == .road && i == lines.count - 1 && !shown[i] ? 0.92 : 1)
            }
        }
        .font(.system(size: 30, weight: .bold))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .task(id: isActive) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { shown = [false, false, false] }
            
            guard isActive else { return }
            
            if reduceMotion {
                shown = [true, true, true]
                return
            }
            
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            for i in 0..<lines.count {
                let isRoad = kind == .road
                let delay = isRoad ? Double(i) * 0.25 : 0
                let damping = (isRoad && i == lines.count - 1) ? 0.6 : 0.85
                withAnimation(.spring(response: 0.45, dampingFraction: damping).delay(delay)) {
                    shown[i] = true
                }
            }
        }
    }
}

// =============================================================
// MARK: - SCREEN 1: 2AM STATS
// Clock jumps, refresh spins, views tick up, subs stay stuck.
// =============================================================

struct NightStatsScene: View {
    
    var isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeIndex = 0
    @State private var views = 270_771
    @State private var rotation: Double = 0
    @State private var shakes: CGFloat = 0
    @State private var showToast = false
    
    private let times = ["2:14 AM", "2:31 AM", "2:47 AM", "3:02 AM", "3:18 AM", "3:35 AM"]
    
    private let cardFill  = Color(red: 0.086, green: 0.078, blue: 0.141)
    private let textMain  = Color(red: 0.85, green: 0.84, blue: 0.90)
    private let textMuted = Color(red: 0.56, green: 0.54, blue: 0.65)
    private let textClock = Color(red: 0.72, green: 0.71, blue: 0.80)
    
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
    
    var body: some View {
        ZStack {
            Image("PersonNight")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Stats card on the blanket
            VStack {
                Spacer()
                statsCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            
            // "0 new subs today" in the empty space on the right
            VStack {
                HStack {
                    Spacer()
                    if showToast {
                        toast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                Spacer()
            }
            .padding(.top, 118)
            .padding(.trailing, 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A creator in bed at 2am, refreshing their stats. Views go up, but subs stay at 742.")
        .task(id: isActive) {
            reset()
            guard isActive else { return }
            
            if reduceMotion {
                timeIndex = 2
                views = 270_775
                showToast = true
                return
            }
            
            let clock = SceneClock()
            
            // First refresh starts right away
            withAnimation(.easeInOut(duration: 0.6)) { rotation += 360 }
            
            // "0 new subs today" at 0.3s, then it stays
            var onTime = await clock.wait(until: 0.3)
            if Task.isCancelled { return }
            sceneStep(onTime, .spring(response: 0.35, dampingFraction: 0.8)) { showToast = true }
            
            // Views tick up, subs stay stuck
            onTime = await clock.wait(until: 0.55)
            if Task.isCancelled { return }
            sceneStep(onTime, .easeOut(duration: 0.25)) { views += Int.random(in: 1...3) }
            if onTime { withAnimation(.linear(duration: 0.35)) { shakes += 1 } }
            
            // Then keep refreshing every 1.95s: clock moves on, views go up, subs never move
            var step = 1
            while !Task.isCancelled {
                let base = 0.55 + Double(step) * 1.95
                onTime = await clock.wait(until: base - 0.55)
                if Task.isCancelled { return }
                sceneStep(onTime, .easeInOut(duration: 0.25)) { timeIndex = min(step, times.count - 1) }
                if onTime { withAnimation(.easeInOut(duration: 0.6)) { rotation += 360 } }
                
                onTime = await clock.wait(until: base)
                if Task.isCancelled { return }
                sceneStep(onTime, .easeOut(duration: 0.25)) { views += Int.random(in: 1...3) }
                if onTime { withAnimation(.linear(duration: 0.35)) { shakes += 1 } }
                step += 1
            }
        }
    }
    
    private func reset() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            timeIndex = 0
            views = 270_771
            showToast = false
        }
    }
    
    private func format(_ n: Int) -> String {
        NightStatsScene.formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12))
                    .foregroundColor(textMuted)
                
                Text(times[timeIndex])
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textClock)
                    .id(timeIndex)
                    .transition(.opacity)
                
                Spacer()
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textMuted)
                    .rotationEffect(.degrees(rotation))
            }
            
            HStack(spacing: 10) {
                statCell(title: "Views") {
                    Text(format(views))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textMain)
                        .id(views)
                        .transition(.opacity)
                }
                
                statCell(title: "Subscribers") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("742")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textMain)
                        Text("no change")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.43, green: 0.42, blue: 0.52))
                    }
                    .modifier(ShakeEffect(animatableData: shakes))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
    }
    
    private func statCell<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(textMuted)
            content()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 24, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
    }
    
    private var toast: some View {
        Text("0 new subs today")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(textMain)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 9, y: 6)
    }
}

// Small side-to-side shake (used on the stuck sub count)
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = 3 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// =============================================================
// MARK: - SCREEN 3: 3 TIPS REVEAL
// Videos fly into the orb, it bursts, 3 tip cards deal in,
// then a summary with confetti.
// =============================================================

struct TipsRevealView: View {
    
    var isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var tilesGone = Array(repeating: false, count: 6)
    @State private var ring: CGFloat = 0
    @State private var orbGone = false
    @State private var flash = 0            // 0 hidden, 1 bright, 2 faded out
    @State private var checkingOn = true
    @State private var tipIndex: Int? = nil
    @State private var visualsOn: Set<Int> = []
    @State private var tagsOn: Set<Int> = []
    @State private var showSummary = false
    @State private var rowsOn = [false, false, false]
    @State private var badgeOn = false
    @State private var confettiOn = false
    
    // Tile centers as 0...1 of the stage
    private let tileCenters: [CGPoint] = [
        CGPoint(x: 34.0 / 272, y: 27.0 / 272),
        CGPoint(x: 238.0 / 272, y: 23.0 / 272),
        CGPoint(x: 28.0 / 272, y: 135.0 / 272),
        CGPoint(x: 244.0 / 272, y: 131.0 / 272),
        CGPoint(x: 46.0 / 272, y: 243.0 / 272),
        CGPoint(x: 226.0 / 272, y: 245.0 / 272)
    ]
    
    private let tileColors: [[Color]] = [
        [Color(red: 0.36, green: 0.23, blue: 0.84), Color(red: 1.00, green: 0.45, blue: 0.80)],
        [Color(red: 0.12, green: 0.48, blue: 0.55), Color(red: 0.36, green: 0.88, blue: 0.90)],
        [Color(red: 0.55, green: 0.18, blue: 0.35), Color(red: 0.96, green: 0.72, blue: 0.24)],
        [Color(red: 0.18, green: 0.49, blue: 0.31), Color(red: 0.49, green: 0.95, blue: 0.60)],
        [Color(red: 0.48, green: 0.29, blue: 0.12), Color(red: 0.96, green: 0.72, blue: 0.24)],
        [Color(red: 0.23, green: 0.16, blue: 0.48), Color(red: 0.55, green: 0.30, blue: 1.00)]
    ]
    
    private let summaryRows: [(icon: String, text: String)] = [
        ("💡", "Your next video idea"),
        ("👥", "Make more how-tos"),
        ("📉", "Keep it under 8 min")
    ]
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            
            ZStack {
                // Videos flying into the orb
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: tileColors[i], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 34)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                        .scaleEffect(tilesGone[i] ? 0.15 : 1)
                        .rotationEffect(.degrees(tilesGone[i] ? (i.isMultiple(of: 2) ? -20 : 20) : 0))
                        .opacity(tilesGone[i] ? 0 : 1)
                        .position(tilesGone[i] ? center : CGPoint(x: tileCenters[i].x * w, y: tileCenters[i].y * h))
                }
                
                // Orb with filling ring
                orb
                    .scaleEffect(orbGone ? 1.5 : 1)
                    .opacity(orbGone ? 0 : 1)
                    .position(center)
                
                // Flash when it bursts
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, OB.pink.opacity(0.6), OB.purple.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(flash == 0 ? 0.4 : (flash == 1 ? 1 : 3.2))
                    .opacity(flash == 1 ? 0.95 : 0)
                    .position(center)
                
                Text("Checking your videos...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OB.lilac.opacity(0.85))
                    .opacity(checkingOn ? 1 : 0)
                    .position(x: w / 2, y: h * 0.8)
                
                // Tip cards, dealt one at a time
                ZStack {
                    if let k = tipIndex {
                        TipCard(index: k, visualOn: visualsOn.contains(k), tagOn: tagsOn.contains(k))
                            .frame(maxWidth: 262)
                            .id(k)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(width: w, height: h)
                
                // Summary
                ZStack {
                    if showSummary {
                        summary
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .frame(width: w, height: h)
                
                // Confetti on the summary
                ConfettiBurst(isOn: confettiOn, big: true, spread: 3.2)
                    .position(center)
                    .allowsHitTesting(false)
                
                // "Done in under 60s"
                Text("Done in under 60s ✓")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(OB.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(OB.green.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(OB.green.opacity(0.45), lineWidth: 1))
                    .opacity(badgeOn ? 1 : 0)
                    .offset(y: badgeOn ? 0 : -8)
                    .position(x: w / 2, y: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example: SubsAI checks your videos and builds your growth plan. Your next video idea, make more how-tos, and keep it under 8 minutes.")
        .task(id: isActive) {
            reset()
            guard isActive else { return }
            
            if reduceMotion {
                showFinal()
                return
            }
            
            let clock = SceneClock()
            
            // Let the title land first
            var onTime = await clock.wait(until: 0.35)
            if Task.isCancelled { return }
            
            // 1. Pull the videos into the orb
            for i in 0..<6 {
                sceneStep(onTime, .easeIn(duration: 0.42).delay(Double(i) * 0.1)) {
                    tilesGone[i] = true
                }
            }
            sceneStep(onTime, .linear(duration: 0.95)) { ring = 1 }
            
            // 2. Burst
            onTime = await clock.wait(until: 1.35)
            if Task.isCancelled { return }
            sceneStep(onTime, .easeOut(duration: 0.12)) {
                flash = 1
                checkingOn = false
            }
            sceneStep(onTime, .easeOut(duration: 0.3)) { orbGone = true }
            onTime = await clock.wait(until: 1.47)
            sceneStep(onTime, .easeOut(duration: 0.45)) { flash = 2 }
            
            // 3. Deal the 3 tips (1.5s each)
            for k in 0..<3 {
                let base = 1.62 + Double(k) * 1.5
                onTime = await clock.wait(until: base)
                if Task.isCancelled { return }
                sceneStep(onTime, .spring(response: 0.4, dampingFraction: 0.85)) { tipIndex = k }
                if onTime { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                
                onTime = await clock.wait(until: base + 0.3)
                sceneStep(onTime, .spring(response: 0.5, dampingFraction: 0.7)) { _ = visualsOn.insert(k) }
                
                onTime = await clock.wait(until: base + 0.75)
                sceneStep(onTime, .spring(response: 0.35, dampingFraction: 0.6)) { _ = tagsOn.insert(k) }
            }
            
            // 4. Summary + confetti (stays on screen)
            onTime = await clock.wait(until: 6.12)
            if Task.isCancelled { return }
            sceneStep(onTime, .spring(response: 0.45, dampingFraction: 0.8)) {
                tipIndex = nil
                showSummary = true
            }
            confettiOn = onTime
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            for i in 0..<3 {
                sceneStep(onTime, .spring(response: 0.4, dampingFraction: 0.8).delay(0.15 + 0.12 * Double(i))) {
                    rowsOn[i] = true
                }
            }
            sceneStep(onTime, .easeOut(duration: 0.3).delay(0.5)) { badgeOn = true }
        }
    }
    
    // MARK: Orb
    
    private var orb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 112, height: 112)
            
            Circle()
                .trim(from: 0, to: ring)
                .stroke(
                    LinearGradient(colors: [OB.purple, OB.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 112, height: 112)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.24, green: 0.39, blue: 0.87),
                            Color(red: 0.42, green: 0.25, blue: 0.83),
                            Color(red: 0.23, green: 0.09, blue: 0.50)
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: 50
                    )
                )
                .frame(width: 84, height: 84)
                .shadow(color: OB.purple.opacity(0.8), radius: 20)
            
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: Summary
    
    private var summary: some View {
        VStack(spacing: 9) {
            Text("Your growth plan\nis ready 🎉")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 2)
            
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 10) {
                    Text(summaryRows[i].icon)
                        .font(.system(size: 18))
                    Text(summaryRows[i].text)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OB.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(OB.rowFill))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OB.rowLine, lineWidth: 1))
                .opacity(rowsOn[i] ? 1 : 0)
                .offset(x: rowsOn[i] ? 0 : 14)
            }
        }
        .frame(maxWidth: 262)
        .padding(.top, 14)
    }
    
    // MARK: Reset / final state
    
    private func reset() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            tilesGone = Array(repeating: false, count: 6)
            ring = 0
            orbGone = false
            flash = 0
            checkingOn = true
            tipIndex = nil
            visualsOn = []
            tagsOn = []
            showSummary = false
            rowsOn = [false, false, false]
            badgeOn = false
            confettiOn = false
        }
    }
    
    private func showFinal() {
        tilesGone = Array(repeating: true, count: 6)
        orbGone = true
        checkingOn = false
        showSummary = true
        rowsOn = [true, true, true]
        badgeOn = true
    }
}

// MARK: - Tip card

struct TipCard: View {
    
    let index: Int
    let visualOn: Bool
    let tagOn: Bool
    
    private var icon: String { ["💡", "👥", "📉"][index] }
    private var kicker: String { ["YOUR NEXT VIDEO", "WHAT GETS YOU SUBS", "WHY PEOPLE LEAVE"][index] }
    private var title: String { ["Mix your 2 best videos.", "Make more how-tos.", "Keep it under 8 min."][index] }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 16))
                Text(kicker)
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(0.7)
                    .foregroundColor(OB.lilac)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("EXAMPLE")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.4)
                    .foregroundColor(OB.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            visual
                .frame(height: 92)
            
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Color.white : Color.white.opacity(0.25))
                        .frame(width: i == index ? 18 : 6, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(OB.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(OB.purple, lineWidth: 2))
        .shadow(color: OB.purple.opacity(0.55), radius: 22)
    }
    
    @ViewBuilder
    private var visual: some View {
        switch index {
        case 0: mergeVisual
        case 1: barsVisual
        default: linesVisual
        }
    }
    
    // Tip 1: two best videos merge into one
    private var mergeVisual: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                thumb("Your #1 video", colors: [Color(red: 0.36, green: 0.23, blue: 0.84), OB.pink])
                    .offset(x: visualOn ? 0 : -(w / 2 - 42), y: -8)
                    .scaleEffect(visualOn ? 0.6 : 1)
                    .opacity(visualOn ? 0 : 1)
                
                thumb("Your #2 video", colors: [Color(red: 0.12, green: 0.48, blue: 0.55), Color(red: 0.36, green: 0.88, blue: 0.90)])
                    .offset(x: visualOn ? 0 : (w / 2 - 42), y: -8)
                    .scaleEffect(visualOn ? 0.6 : 1)
                    .opacity(visualOn ? 0 : 1)
                
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [OB.purple, OB.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 124, height: 72)
                    .overlay(Image(systemName: "play.fill").font(.system(size: 22)).foregroundColor(.white))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.white, lineWidth: 2))
                    .shadow(color: OB.pink.opacity(0.75), radius: 12)
                    .scaleEffect(visualOn ? 1 : 0.5)
                    .opacity(visualOn ? 1 : 0)
                    .offset(y: -10)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.25), value: visualOn)
                
                goldTag("Your next hit")
                    .offset(y: 36)
            }
            .frame(width: w, height: g.size.height)
        }
    }
    
    private func thumb(_ text: String, colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 84, height: 50)
            .overlay(
                Text(text)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(4)
            )
    }
    
    // Tip 2: how-tos vs vlogs
    private var barsVisual: some View {
        HStack(alignment: .bottom, spacing: 44) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(OB.barDim)
                    .frame(width: 46, height: 14)
                    .scaleEffect(x: 1, y: visualOn ? 1 : 0.001, anchor: .bottom)
                Text("Vlogs")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OB.muted)
            }
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.83, blue: 0.42), OB.gold], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 70)
                    .shadow(color: OB.gold.opacity(0.7), radius: 8)
                    .scaleEffect(x: 1, y: visualOn ? 1 : 0.001, anchor: .bottom)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: visualOn)
                Text("How-tos")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(OB.gold)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: .top) {
            goldTag("5x subs")
                .offset(x: 50, y: -4)
        }
    }
    
    // Tip 3: shorter videos keep viewers
    private var linesVisual: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 2, y: h - 6))
                    p.addLine(to: CGPoint(x: w - 2, y: h - 6))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                
                RetentionLine(kind: .over)
                    .trim(from: 0, to: visualOn ? 1 : 0)
                    .stroke(OB.orange, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .animation(.easeInOut(duration: 0.5), value: visualOn)
                
                RetentionLine(kind: .under)
                    .trim(from: 0, to: visualOn ? 1 : 0)
                    .stroke(Color(red: 0.73, green: 0.64, blue: 1.0), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .animation(.easeInOut(duration: 0.5).delay(0.1), value: visualOn)
                
                Text("Under 8 min")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(red: 0.73, green: 0.64, blue: 1.0))
                    .frame(width: w, alignment: .trailing)
                    .position(x: w / 2, y: h * 52 / 92 - 4)
                
                Text("Over 8 min")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OB.orange)
                    .frame(width: w, alignment: .trailing)
                    .position(x: w / 2, y: h * 76 / 92 - 4)
                
                goldTag("2x viewers")
                    .position(x: w * 0.55, y: 12)
            }
        }
    }
    
    private func goldTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8).fill(OB.gold))
            .shadow(color: OB.gold.opacity(0.6), radius: 6)
            .fixedSize()
            .scaleEffect(tagOn ? 1 : 0.5)
            .opacity(tagOn ? 1 : 0)
    }
}

// Retention curves drawn in a 230 x 92 box, scaled to fit
struct RetentionLine: Shape {
    enum Kind { case over, under }
    let kind: Kind
    
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 230
        let sy = rect.height / 92
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        
        var p = Path()
        switch kind {
        case .over:
            p.move(to: pt(6, 12))
            p.addCurve(to: pt(94, 70), control1: pt(40, 16), control2: pt(52, 64))
            p.addCurve(to: pt(226, 82), control1: pt(136, 76), control2: pt(176, 80))
        case .under:
            p.move(to: pt(6, 12))
            p.addCurve(to: pt(156, 28), control1: pt(62, 14), control2: pt(112, 22))
            p.addCurve(to: pt(226, 36), control1: pt(200, 34), control2: pt(206, 34))
        }
        return p
    }
}

// =============================================================
// MARK: - SCREEN 2: ROAD TO 1M SUBS
// =============================================================

struct RoadmapView: View {
    
    var isActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var litCount = 1   // the "0 subs" dot starts lit
    
    // Positions are 0...1 inside a square. Road winds from bottom to top.
    private let milestones: [(label: String, point: CGPoint)] = [
        ("0",    CGPoint(x: 0.16, y: 0.88)),
        ("1K",   CGPoint(x: 0.80, y: 0.70)),
        ("10K",  CGPoint(x: 0.20, y: 0.50)),
        ("100K", CGPoint(x: 0.80, y: 0.31)),
        ("1M",   CGPoint(x: 0.30, y: 0.12))
    ]
    
    private var points: [CGPoint] { milestones.map { $0.point } }
    private var stops: [CGFloat] { RoadShape.stopFractions(points: points) }
    
    private let glowStart = Color(red: 0.55, green: 0.30, blue: 1.00)
    private let glowEnd   = Color(red: 1.00, green: 0.45, blue: 0.80)
    private let gold      = Color(red: 0.96, green: 0.72, blue: 0.24)
    private let pillFill  = Color(red: 0.08, green: 0.04, blue: 0.16)
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                // The road (dim)
                RoadShape(points: points)
                    .stroke(Color.white.opacity(0.10),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                
                // Dashed center line
                RoadShape(points: points)
                    .stroke(Color.white.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 8]))
                
                // Glow under the lit road (a wide faint stroke is much cheaper than a moving shadow)
                RoadShape(points: points)
                    .trim(from: 0, to: progress)
                    .stroke(glowStart.opacity(0.35),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                
                // The lit part of the road
                RoadShape(points: points)
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [glowStart, glowEnd], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                    )
                
                // The moving light, with a soft halo
                RoadHead(progress: progress, points: points, radius: 20)
                    .fill(glowEnd.opacity(0.35))
                RoadHead(progress: progress, points: points, radius: 13)
                    .fill(Color.white.opacity(0.5))
                RoadHead(progress: progress, points: points)
                    .fill(Color.white)
                
                // Milestone dots and labels
                ForEach(milestones.indices, id: \.self) { i in
                    milestone(i, in: size)
                }
                
                // Confetti on top of everything
                ForEach(1..<milestones.count, id: \.self) { i in
                    let p = milestones[i].point
                    ConfettiBurst(
                        isOn: i < litCount && !reduceMotion,
                        big: i == 1 || i == milestones.count - 1
                    )
                    .position(x: p.x * size.width, y: p.y * size.height)
                    .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A road from 0 subs to 1 million subs. At 1,000 subs you can monetize.")
        .task(id: isActive) {
            if isActive {
                await play()
            } else {
                progress = 0
                litCount = 1
            }
        }
    }
    
    private func milestone(_ i: Int, in size: CGSize) -> some View {
        let p = milestones[i].point
        let x = p.x * size.width
        let y = p.y * size.height
        let lit = i < litCount
        let labelOnLeft = p.x > 0.5
        let labelWidth: CGFloat = 190
        
        return ZStack {
            Circle()
                .fill(lit ? Color.white : Color(white: 0.15))
                .overlay(Circle().stroke(Color.white.opacity(lit ? 0 : 0.35), lineWidth: 2))
                .frame(width: 18, height: 18)
                .scaleEffect(lit ? 1.15 : 1)
                .shadow(color: lit ? glowStart : .clear, radius: 10)
                .position(x: x, y: y)
            
            HStack(spacing: 6) {
                // The big one: 1K subs = monetize
                if i == 1 && lit {
                    Text("Monetize 💰")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(gold))
                        .transition(.scale.combined(with: .opacity))
                }
                
                HStack(spacing: 3) {
                    Text(milestones[i].label)
                        .font(.system(size: 14, weight: .bold))
                    Text("subs")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.8)
                }
                .foregroundColor(lit ? .white : .white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(pillFill.opacity(0.92)))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .frame(width: labelWidth, alignment: labelOnLeft ? .trailing : .leading)
            .position(x: labelOnLeft ? x - 14 - labelWidth / 2 : x + 14 + labelWidth / 2, y: y)
        }
    }
    
    private func play() async {
        progress = 0
        litCount = 1
        
        if reduceMotion {
            progress = 1
            litCount = milestones.count
            return
        }
        
        let clock = SceneClock()
        
        // Start as the first title line lands. Each stop: 0.6s drive, then light up.
        // A longer pause at 1K so "Monetize" sinks in.
        var at = 0.2
        for i in 1..<milestones.count {
            var onTime = await clock.wait(until: at)
            if Task.isCancelled { return }
            sceneStep(onTime, .easeInOut(duration: 0.6)) {
                progress = stops[i]
            }
            
            onTime = await clock.wait(until: at + 0.6)
            if Task.isCancelled { return }
            sceneStep(onTime, .spring(response: 0.35, dampingFraction: 0.6)) {
                litCount = i + 1
            }
            if onTime {
                let big = (i == 1 || i == milestones.count - 1)
                UIImpactFeedbackGenerator(style: big ? .medium : .light).impactOccurred()
            }
            at += 0.6 + ((i == 1) ? 0.5 : 0.15)
        }
    }
}

// MARK: - Confetti burst (used on screens 2 and 3)

struct ConfettiBurst: View {
    
    var isOn: Bool
    var big: Bool
    
    @State private var particles: [Particle]
    @State private var flying = false
    @State private var faded = true
    
    init(isOn: Bool, big: Bool, spread: CGFloat = 1) {
        self.isOn = isOn
        self.big = big
        _particles = State(initialValue: ConfettiBurst.make(count: big ? 18 : 12, big: big, spread: spread))
    }
    
    var body: some View {
        ZStack {
            // Quick ring pulse
            Circle()
                .stroke(Color.white.opacity(flying ? 0 : 0.8), lineWidth: 2)
                .frame(width: flying ? (big ? 66 : 50) : 16, height: flying ? (big ? 66 : 50) : 16)
                .opacity(faded && !flying ? 0 : 1)
            
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 1)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.7)
                    .rotationEffect(.degrees(flying ? p.spin : 0))
                    .offset(x: flying ? p.dx : 0, y: flying ? p.dy : 0)
                    .opacity(faded ? 0 : 1)
            }
        }
        .frame(width: 1, height: 1)
        .task(id: isOn) {
            if isOn {
                await fire()
            } else {
                flying = false
                faded = true
            }
        }
    }
    
    private func fire() async {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            flying = false
            faded = false
        }
        try? await Task.sleep(nanoseconds: 16_000_000)
        
        withAnimation(.easeOut(duration: 0.7)) { flying = true }
        withAnimation(.easeIn(duration: 0.45).delay(0.4)) { faded = true }
    }
    
    struct Particle: Identifiable {
        let id = UUID()
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let spin: Double
        let color: Color
    }
    
    static func make(count: Int, big: Bool, spread: CGFloat) -> [Particle] {
        let colors: [Color] = [
            Color(red: 0.96, green: 0.72, blue: 0.24),  // gold
            Color(red: 1.00, green: 0.45, blue: 0.80),  // pink
            Color(red: 0.55, green: 0.30, blue: 1.00),  // purple
            .white,
            Color(red: 0.36, green: 0.88, blue: 0.90),  // cyan
            Color(red: 0.49, green: 0.95, blue: 0.60)   // green
        ]
        return (0..<count).map { i in
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double.random(in: -0.25...0.25)
            let distance = (big ? CGFloat.random(in: 26...40) : CGFloat.random(in: 18...28)) * spread
            return Particle(
                dx: CGFloat(cos(angle)) * distance,
                dy: CGFloat(sin(angle)) * distance + 12,   // slight drop, like gravity
                size: CGFloat.random(in: 3...4.5),
                spin: Double.random(in: 90...360),
                color: colors.randomElement() ?? .white
            )
        }
    }
}

// MARK: - Road shape

struct RoadShape: Shape {
    let points: [CGPoint]   // 0...1 values
    
    func path(in rect: CGRect) -> Path {
        RoadShape.road(in: rect.size, points: points)
    }
    
    static func road(in size: CGSize, points: [CGPoint]) -> Path {
        var path = Path()
        let pts = points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard let first = pts.first else { return path }
        path.move(to: first)
        for i in 1..<pts.count {
            let s = segment(pts[i - 1], pts[i])
            path.addCurve(to: s.end, control1: s.c1, control2: s.c2)
        }
        return path
    }
    
    static func segment(_ a: CGPoint, _ b: CGPoint) -> (start: CGPoint, end: CGPoint, c1: CGPoint, c2: CGPoint) {
        let midY = (a.y + b.y) / 2
        return (a, b, CGPoint(x: a.x, y: midY), CGPoint(x: b.x, y: midY))
    }
    
    static func stopFractions(points: [CGPoint]) -> [CGFloat] {
        var totals: [CGFloat] = [0]
        var total: CGFloat = 0
        for i in 1..<points.count {
            let s = segment(points[i - 1], points[i])
            var prev = s.start
            var length: CGFloat = 0
            for step in 1...40 {
                let t = CGFloat(step) / 40
                let p = bezierPoint(s.start, s.c1, s.c2, s.end, t)
                length += hypot(p.x - prev.x, p.y - prev.y)
                prev = p
            }
            total += length
            totals.append(total)
        }
        return totals.map { total > 0 ? $0 / total : 0 }
    }
    
    static func bezierPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Moving light on the road

struct RoadHead: Shape {
    var progress: CGFloat
    let points: [CGPoint]
    var radius: CGFloat = 9
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        guard progress > 0.001 else { return Path() }
        let road = RoadShape.road(in: rect.size, points: points)
        guard let p = road.trimmedPath(from: 0, to: min(progress, 1)).currentPoint else { return Path() }
        return Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - SHIMMER (trust line)

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
