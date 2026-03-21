import SwiftUI
import Combine

// MARK: - StatsView
struct StatsView: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    @StateObject var moodStore = MoodStore()

    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var currentHour:   Double = Double(Calendar.current.component(.hour,   from: Date()))
    @State private var currentMinute: Double = Double(Calendar.current.component(.minute, from: Date()))
    @State private var showLifetime = false
    @AppStorage("stats_sky_enabled") private var skyEnabled: Bool = true

    // MARK: - Time helpers

    var timeProgress: Double { (currentHour * 60 + currentMinute) / 1440 }
    var isDaytime: Bool { currentHour >= 6 && currentHour < 20 }

    var skyColors: [Color] {
        switch currentHour {
        case 0..<5:   return [Color(red:0.03,green:0.03,blue:0.12), Color(red:0.08,green:0.06,blue:0.18)]
        case 5..<7:   return [Color(red:0.95,green:0.55,blue:0.25), Color(red:0.30,green:0.18,blue:0.45)]
        case 7..<11:  return [Color(red:0.52,green:0.78,blue:0.98), Color(red:0.85,green:0.93,blue:1.0)]
        case 11..<16: return [Color(red:0.40,green:0.72,blue:0.96), Color(red:0.75,green:0.90,blue:1.0)]
        case 16..<19: return [Color(red:1.0, green:0.60,blue:0.25), Color(red:0.85,green:0.35,blue:0.30)]
        case 19..<21: return [Color(red:0.25,green:0.15,blue:0.40), Color(red:0.85,green:0.40,blue:0.20)]
        default:      return [Color(red:0.05,green:0.05,blue:0.18), Color(red:0.12,green:0.08,blue:0.25)]
        }
    }

    var celestialIcon: String {
        switch currentHour {
        case 5..<7:  return "sunrise.fill"
        case 7..<19: return "sun.max.fill"
        case 19..<21: return "sunset.fill"
        default:     return "moon.stars.fill"
        }
    }

    var celestialColor: Color {
        isDaytime
            ? Color(red:1.0,green:0.88,blue:0.30)
            : Color(red:0.88,green:0.90,blue:1.0)
    }

    func adaptiveWhite(_ opacity: Double = 1.0) -> Color {
        skyEnabled ? .white.opacity(opacity) : .primary.opacity(opacity)
    }
    func adaptiveSecondary() -> Color {
        skyEnabled ? .white.opacity(0.7) : .secondary
    }

    // MARK: - Engine Computed Properties

    var statsSnapshot: StatsSnapshot {
        StatsEngine.snapshot(store: store, streakThreshold: PreferencesStore().streakThreshold.value)
    }

    var moodAnalytics: MoodAnalytics {
        MoodAnalytics(moodStore: moodStore, store: store)
    }

    var timeAnalytics: TimeAnalytics {
        TimeAnalytics(store: store)
    }

    var prediction: PredictionEngine {
        PredictionEngine(
            weekCompletion:         statsSnapshot.weekCompletion,
            previousWeekCompletion: statsSnapshot.previousWeekCompletion,
            monthSoFarCompletion:   statsSnapshot.monthCompletion
        )
    }

    var currentInsight: Insight {
        let ctx = InsightContext(
            streak:            statsSnapshot.currentStreak,
            bestStreak:        statsSnapshot.bestStreak,
            weekCompletion:    statsSnapshot.weekCompletion,
            weekDelta:         statsSnapshot.weekDelta,
            monthCompletion:   statsSnapshot.monthCompletion,
            todayCompletion:   statsSnapshot.todayCompletion,
            moodLevel:         moodStore.todayEntry()?.mood,
            moodTrend:         moodAnalytics.trend,
            consistencyScore:  statsSnapshot.consistencyScore,
            hour:              Int(currentHour)
        )
        return InsightEngine.generate(context: ctx)
    }

    var moodContext: MoodContext? {
        guard let entry = moodStore.todayEntry() else { return nil }
        let sorted       = moodStore.entries.sorted { $0.date < $1.date }
        let previousMood = sorted.dropLast().last?.mood
        return MoodContext(
            level:        entry.mood,
            hour:         Int(currentHour),
            streak:       statsSnapshot.currentStreak,
            trend:        moodAnalytics.trend,
            previousMood: previousMood
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {

                // Background
                if skyEnabled {
                    LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 2), value: currentHour)

                    if scheme == .light {
                        Color.black.opacity(isDaytime ? 0.28 : 0.10)
                            .ignoresSafeArea()
                            .animation(.easeInOut(duration: 2), value: isDaytime)
                    }

                    SkyBodyView(currentHour: currentHour, currentMinute: currentMinute)

                    Circle()
                        .fill(celestialColor.opacity(isDaytime ? 0.35 : 0.18))
                        .frame(width: 180, height: 180)
                        .blur(radius: 60)
                        .offset(x: 80, y: -120)
                        .animation(.easeInOut(duration: 2), value: currentHour)

                    if !isDaytime {
                        StarsBackground().transition(.opacity)
                    }
                } else {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                }

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        headerSection

                        insightCard

                        completionRingsCard

                        MoodLogCard(moodStore: moodStore, moodContext: moodContext)

                        HStack(spacing: 14) {
                            streakCard
                            bestTimeCard
                        }

                        predictionCard

                        Button {
                            showLifetime = true
                        } label: {
                            HStack {
                                Image(systemName: "infinity.circle.fill")
                                    .foregroundStyle(skyEnabled
                                        ? Color(red:0.55,green:0.75,blue:1.0)
                                        : .blue
                                    )
                                Text("View Lifetime Stats")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(skyEnabled ? .white : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(skyEnabled ? .white.opacity(0.5) : .secondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(skyEnabled
                                          ? Color.white.opacity(0.1)
                                          : Color(.secondarySystemGroupedBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                skyEnabled
                                                    ? Color.white.opacity(0.15)
                                                    : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showLifetime) {
                            LifetimeDetailView().environmentObject(store)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: skyEnabled)
            .navigationBarHidden(true)
            .onReceive(timer) { _ in
                currentHour   = Double(Calendar.current.component(.hour,   from: Date()))
                currentMinute = Double(Calendar.current.component(.minute, from: Date()))
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(skyEnabled ? .white.opacity(0.85) : .secondary)
                    .shadow(color: skyEnabled ? .black.opacity(0.4) : .clear, radius: 4, y: 1)
                Text("Your Progress")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(skyEnabled ? .white : .primary)
                    .shadow(color: skyEnabled ? .black.opacity(0.4) : .clear, radius: 6, y: 2)
            }
            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    skyEnabled.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(skyEnabled
                              ? Color.white.opacity(0.18)
                              : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: skyEnabled ? celestialIcon : "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(skyEnabled ? celestialColor : .secondary)
                        .shadow(color: skyEnabled ? celestialColor.opacity(0.6) : .clear, radius: 6)
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 1), value: celestialIcon)
        }
        .padding(.top, 8)
    }

    var greetingText: String {
        switch currentHour {
        case 0..<5:   return "Working late 🌙"
        case 5..<12:  return "Good morning ☀️"
        case 12..<18: return "Good afternoon 🌤"
        default:      return "Good evening 🌆"
        }
    }

    // MARK: - Insight Card

    var insightCard: some View {
        InsightCard(insight: currentInsight, skyEnabled: skyEnabled)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.5), value: currentInsight.title)
    }

    // MARK: - Completion Rings Card

    var completionRingsCard: some View {
        GlassCard(skyEnabled: skyEnabled) {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    // Month (outer)
                    RingView(progress: statsSnapshot.monthCompletion,
                             color: Color(red:0.55,green:0.75,blue:1.0),
                             radius: 70, lineWidth: 8)
                    // Week (middle)
                    RingView(progress: statsSnapshot.weekCompletion,
                             color: Color(red:1.0,green:0.72,blue:0.35),
                             radius: 54, lineWidth: 8)
                    // Today (inner)
                    RingView(progress: statsSnapshot.todayCompletion,
                             color: Color(red:0.45,green:0.90,blue:0.65),
                             radius: 38, lineWidth: 8)

                    VStack(spacing: 1) {
                        Text("\(Int(statsSnapshot.todayCompletion * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(adaptiveWhite())
                        Text("today")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(adaptiveSecondary())
                    }
                }
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 16) {
                    ringLabel(
                        color: Color(red:0.45,green:0.90,blue:0.65),
                        label: "Today",
                        value: statsSnapshot.todayCompletion,
                        count: "\(statsSnapshot.completedEventsToday)/\(statsSnapshot.totalEventsToday)",
                        delta: nil
                    )
                    ringLabel(
                        color: Color(red:1.0,green:0.72,blue:0.35),
                        label: "This Week",
                        value: statsSnapshot.weekCompletion,
                        count: nil,
                        delta: statsSnapshot.weekDelta
                    )
                    ringLabel(
                        color: Color(red:0.55,green:0.75,blue:1.0),
                        label: "This Month",
                        value: statsSnapshot.monthCompletion,
                        count: nil,
                        delta: nil
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    func ringLabel(color: Color, label: String, value: Double, count: String?, delta: Double?) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(adaptiveSecondary())
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(adaptiveWhite())
                    if let count {
                        Text(count)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if let delta, abs(delta) > 0.02 {
                        Text(deltaLabel(delta))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(delta > 0
                                ? Color(red:0.45,green:0.90,blue:0.65)
                                : Color(red:1.0,green:0.55,blue:0.30))
                    }
                }
            }
        }
    }

    private func deltaLabel(_ delta: Double) -> String {
        let pct = Int(abs(delta) * 100)
        return delta > 0 ? "+\(pct)%" : "-\(pct)%"
    }

    // MARK: - Streak Card

    var streakCard: some View {
        GlassCard(skyEnabled: skyEnabled) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: statsSnapshot.isStreakAtRisk
                          ? "exclamationmark.triangle.fill"
                          : "flame.fill")
                        .foregroundStyle(statsSnapshot.isStreakAtRisk
                            ? Color(red:1.0,green:0.65,blue:0.20)
                            : Color(red:1.0,green:0.55,blue:0.20))
                    Text("Streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(adaptiveSecondary())
                    Spacer()
                    if statsSnapshot.isStreakAtRisk {
                        Text("at risk")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red:1.0,green:0.65,blue:0.20))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule()
                                .fill(Color(red:1.0,green:0.65,blue:0.20).opacity(0.18)))
                    }
                }
                Text("\(statsSnapshot.currentStreak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(adaptiveWhite())
                HStack(spacing: 4) {
                    Text(statsSnapshot.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 12))
                        .foregroundStyle(adaptiveSecondary())
                    if statsSnapshot.bestStreak > 1 {
                        Text("· best \(statsSnapshot.bestStreak)")
                            .font(.system(size: 11))
                            .foregroundStyle(adaptiveSecondary().opacity(0.65))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Best Time Card

    var bestTimeCard: some View {
        GlassCard(skyEnabled: skyEnabled) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color(red:0.55,green:0.75,blue:1.0))
                    Text("Wake → Sleep")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(adaptiveSecondary())
                }
                let hours = (store.sleepMinutes - store.wakeMinutes) / 60
                let mins  = (store.sleepMinutes - store.wakeMinutes) % 60
                Text("\(hours)h\(mins > 0 ? " \(mins)m" : "")")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(adaptiveWhite())
                Text("active window")
                    .font(.system(size: 12))
                    .foregroundStyle(adaptiveSecondary())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Prediction Card

    var predictionCard: some View {
        GlassCard(skyEnabled: skyEnabled) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red:0.55,green:0.75,blue:1.0).opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: prediction.trendIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red:0.55,green:0.75,blue:1.0))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(prediction.onTrackMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(adaptiveWhite())

                    Group {
                        if let timeDesc = timeAnalytics.bestHourDescription {
                            Text("Most productive around \(timeDesc)")
                        } else if let corr = moodAnalytics.correlationInsight {
                            Text(corr)
                        } else {
                            Text("Keep your current pace")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(adaptiveSecondary())
                }

                Spacer()
            }
        }
    }
}

// MARK: - Insight Card View

struct InsightCard: View {
    let insight: Insight
    var skyEnabled: Bool

    @Environment(\.colorScheme) private var scheme

    var accentColor: Color {
        switch insight.type {
        case .positive: return Color(red:0.35,green:0.90,blue:0.65)
        case .warning:  return Color(red:1.0, green:0.65,blue:0.20)
        case .recovery: return Color(red:0.75,green:0.70,blue:0.95)
        case .identity: return Color(red:1.0, green:0.82,blue:0.25)
        case .neutral:  return Color(red:0.55,green:0.75,blue:1.0)
        }
    }

    var iconName: String {
        switch insight.type {
        case .positive: return "arrow.up.right"
        case .warning:  return "exclamationmark.triangle.fill"
        case .recovery: return "arrow.counterclockwise"
        case .identity: return "star.fill"
        case .neutral:  return "lightbulb.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: 44, height: 44)
                    .blur(radius: 6)
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(skyEnabled ? .white : .primary)
                if let subtitle = insight.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(skyEnabled ? .white.opacity(0.65) : .secondary)
                }
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    skyEnabled
                        ? Color.black.opacity(0.38)
                        : (scheme == .dark
                            ? Color(.secondarySystemBackground)
                            : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accentColor.opacity(0.40), lineWidth: 1)
                )
        )
        .shadow(color: accentColor.opacity(skyEnabled ? 0.18 : 0.08), radius: 14, y: 4)
    }
}

// MARK: - Ring View

struct RingView: View {
    let progress: CGFloat
    let color: Color
    let radius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

            if progress > 0.02 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth + 2, height: lineWidth + 2)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-90 + Double(progress) * 360))
                    .shadow(color: color.opacity(0.8), radius: 4)
                    .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
            }
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var skyEnabled: Bool = true
    @Environment(\.colorScheme) private var scheme

    init(skyEnabled: Bool = true, @ViewBuilder content: () -> Content) {
        self.skyEnabled = skyEnabled
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        skyEnabled
                            ? Color.black.opacity(0.38)
                            : (scheme == .dark
                                ? Color(.secondarySystemBackground)
                                : Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                skyEnabled
                                    ? Color.white.opacity(0.18)
                                    : Color.primary.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(skyEnabled ? 0.25 : 0.10), radius: 12, y: 4)
    }
}

// MARK: - Stars Background

struct StarsBackground: View {
    let stars: [(CGFloat, CGFloat, CGFloat)] = (0..<60).map { _ in
        (CGFloat.random(in: 0...1),
         CGFloat.random(in: 0...0.6),
         CGFloat.random(in: 0.5...1.5))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: stars[i].2, height: stars[i].2)
                    .position(
                        x: stars[i].0 * geo.size.width,
                        y: stars[i].1 * geo.size.height
                    )
                    .opacity(Double.random(in: 0.3...0.9))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sky Body View

struct SkyBodyView: View {
    let currentHour: Double
    let currentMinute: Double

    var dayProgress: Double { (currentHour * 60 + currentMinute) / 1440 }

    var sunProgress: Double {
        let start = 6.0 / 24.0
        let end   = 20.0 / 24.0
        return max(0, min(1, (dayProgress - start) / (end - start)))
    }

    var moonProgress: Double {
        let p = dayProgress
        if p >= 20.0/24.0 { return (p - 20.0/24.0) / (4.0/24.0) }
        else               { return (p + 4.0/24.0)  / (4.0/24.0 + 6.0/24.0) }
    }

    var showSun: Bool { currentHour >= 6 && currentHour < 20 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            if showSun {
                let x    = w * (-0.05 + sunProgress * 1.10)
                let arcY = h * (0.55 - sin(sunProgress * .pi) * 0.38)
                ZStack {
                    Circle()
                        .fill(Color(red:1.0,green:0.92,blue:0.50).opacity(0.18))
                        .frame(width: 80, height: 80)
                        .blur(radius: 25)
                        .position(x: x, y: arcY)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red:1.0,green:0.95,blue:0.50),
                                         Color(red:1.0,green:0.75,blue:0.20)],
                                startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Color(red:1.0,green:0.85,blue:0.30).opacity(0.8), radius: 12)
                        .position(x: x, y: arcY)
                }
                .animation(.linear(duration: 0.5), value: sunProgress)

            } else {
                let mp   = max(0, min(1, moonProgress))
                let x    = w * (-0.05 + mp * 1.10)
                let arcY = h * (0.55 - sin(mp * .pi) * 0.38)
                ZStack {
                    Circle()
                        .fill(Color(red:0.75,green:0.80,blue:1.0).opacity(0.25))
                        .frame(width: 100, height: 100)
                        .blur(radius: 35)
                        .position(x: x, y: arcY)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red:0.95,green:0.95,blue:1.0),
                                         Color(red:0.75,green:0.82,blue:1.0)],
                                startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Color(red:0.80,green:0.85,blue:1.0).opacity(0.7), radius: 10)
                        .position(x: x, y: arcY)
                }
                .animation(.linear(duration: 0.5), value: moonProgress)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
