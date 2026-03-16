import SwiftUI
import Combine

// MARK: - Mood Model
enum Mood: String, CaseIterable {
    case amazing = "🤩"
    case good    = "😊"
    case okay    = "😐"
    case low     = "😔"
    case rough   = "😞"

    var label: String {
        switch self {
        case .amazing: return "Amazing"
        case .good:    return "Good"
        case .okay:    return "Okay"
        case .low:     return "Low"
        case .rough:   return "Rough"
        }
    }

    var color: Color {
        switch self {
        case .amazing: return Color(red: 1.0, green: 0.80, blue: 0.20)
        case .good:    return Color(red: 0.35, green: 0.80, blue: 0.55)
        case .okay:    return Color(red: 0.55, green: 0.65, blue: 0.90)
        case .low:     return Color(red: 0.90, green: 0.60, blue: 0.30)
        case .rough:   return Color(red: 0.80, green: 0.35, blue: 0.40)
        }
    }
}

// MARK: - StatsView
struct StatsView: View {

    @EnvironmentObject var store: TimelineStore
    @EnvironmentObject var calendar: CalendarState
    @Environment(\.colorScheme) private var scheme

    @StateObject var moodStore = MoodStore()
    @State private var selectedMood: Mood? = nil
    @State private var moodNote: String = ""
    @State private var showMoodNote = false
    @State private var moodSaved = false

    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var currentHour: Double = Double(Calendar.current.component(.hour, from: Date()))
    @State private var currentMinute: Double = Double(Calendar.current.component(.minute, from: Date()))
    @State private var showLifetime = false
    @AppStorage("stats_sky_enabled") private var skyEnabled: Bool = true
    
    // Thời gian tính bằng phút trong ngày 0...1440
    var timeProgress: Double {
        (currentHour * 60 + currentMinute) / 1440
    }

    // Phase: 0=đêm khuya, 0.25=bình minh, 0.5=trưa, 0.75=hoàng hôn, 1=đêm
    var isDaytime: Bool { currentHour >= 6 && currentHour < 20 }

    var skyColors: [Color] {
        switch currentHour {
        case 0..<5:   // khuya
            return [Color(red:0.03,green:0.03,blue:0.12), Color(red:0.08,green:0.06,blue:0.18)]
        case 5..<7:   // bình minh
            return [Color(red:0.95,green:0.55,blue:0.25), Color(red:0.30,green:0.18,blue:0.45)]
        case 7..<11:  // sáng
            return [Color(red:0.52,green:0.78,blue:0.98), Color(red:0.85,green:0.93,blue:1.0)]
        case 11..<16: // trưa
            return [Color(red:0.40,green:0.72,blue:0.96), Color(red:0.75,green:0.90,blue:1.0)]
        case 16..<19: // chiều tà
            return [Color(red:1.0, green:0.60,blue:0.25), Color(red:0.85,green:0.35,blue:0.30)]
        case 19..<21: // hoàng hôn
            return [Color(red:0.25,green:0.15,blue:0.40), Color(red:0.85,green:0.40,blue:0.20)]
        default:      // tối
            return [Color(red:0.05,green:0.05,blue:0.18), Color(red:0.12,green:0.08,blue:0.25)]
        }
    }

    var celestialIcon: String {
        switch currentHour {
        case 5..<7:   return "sunrise.fill"
        case 7..<19:  return "sun.max.fill"
        case 19..<21: return "sunset.fill"
        default:      return "moon.stars.fill"
        }
    }

    func adaptiveWhite(_ opacity: Double = 1.0) -> Color {
        skyEnabled ? .white.opacity(opacity) : .primary.opacity(opacity)
    }

    func adaptiveSecondary() -> Color {
        skyEnabled ? .white.opacity(0.7) : .secondary
    }

    
    var celestialColor: Color {
        isDaytime ? Color(red:1.0,green:0.88,blue:0.30) : Color(red:0.88,green:0.90,blue:1.0)
    }

    // MARK: - Stats computation
    var todayEvents: [EventItem] {
        store.events(for: Date()).filter { !$0.isSystemEvent }
    }

    var todayCompletion: Double {
        let all = todayEvents
        guard !all.isEmpty else { return 0 }
        let done = all.filter { store.isCompleted(templateID: $0.id, date: Date()) }.count
        return Double(done) / Double(all.count)
    }

    var weekCompletion: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today) else { return 0 }
        var total = 0; var done = 0
        for d in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: d, to: weekStart) else { continue }
            let evs = store.events(for: date).filter { !$0.isSystemEvent }
            total += evs.count
            done  += evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
        }
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    var monthCompletion: Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let monthStart = cal.date(byAdding: .day, value: -29, to: today) else { return 0 }
        var total = 0; var done = 0
        for d in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: d, to: monthStart) else { continue }
            let evs = store.events(for: date).filter { !$0.isSystemEvent }
            total += evs.count
            done  += evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
        }
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: Date())
        while true {
            let evs = store.events(for: date).filter { !$0.isSystemEvent && $0.kind == .habit }
            
            // Bỏ qua ngày tương lai
            if date > cal.startOfDay(for: Date()) {
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
                continue
            }
            
            // Không có habit → dừng
            guard !evs.isEmpty else { break }
            
            // Ít nhất 50% habit hoàn thành mới tính
            let done = evs.filter { store.isCompleted(templateID: $0.id, date: date) }.count
            let ratio = Double(done) / Double(evs.count)
            let threshold = PreferencesStore().streakThreshold.value
            if ratio < threshold { break }
            
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ZStack {

                // MARK: - Background
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
                        StarsBackground()
                            .transition(.opacity)
                    }
                } else {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                }

                // MARK: - Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        headerSection

                        completionRingsCard

                        MoodLogCard(moodStore: moodStore)

                        HStack(spacing: 14) {
                            streakCard
                            bestTimeCard
                        }

                        Button {
                            showLifetime = true
                        } label: {
                            HStack {
                                Image(systemName: "infinity.circle.fill")
                                    .foregroundStyle(skyEnabled
                                        ? Color(red: 0.55, green: 0.75, blue: 1.0)
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
                            LifetimeDetailView()
                                .environmentObject(store)
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
    // TÌM var headerSection, ĐỔI THÀNH:
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

            // Sky toggle button
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
                            : Color.primary.opacity(0.08)
                        )
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
        case 18..<24: return "Good evening 🌆"
        default:      return "Good evening 🌆"
        }
    }

    // MARK: - Completion Rings Card
    var completionRingsCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 24) {
                // Nested rings
                ZStack {
                    // Month (outer)
                    RingView(progress: monthCompletion, color: Color(red:0.55,green:0.75,blue:1.0), radius: 70, lineWidth: 8)
                    // Week (middle)
                    RingView(progress: weekCompletion,  color: Color(red:1.0,green:0.72,blue:0.35), radius: 54, lineWidth: 8)
                    // Today (inner)
                    RingView(progress: todayCompletion, color: Color(red:0.45,green:0.90,blue:0.65), radius: 38, lineWidth: 8)

                    // Center
                    VStack(spacing: 1) {
                        Text("\(Int(todayCompletion * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(adaptiveWhite())
                        Text("today")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(adaptiveSecondary())
                    }
                }
                .frame(width: 150, height: 150)

                // Labels
                VStack(alignment: .leading, spacing: 16) {
                    ringLabel(
                        color: Color(red:0.45,green:0.90,blue:0.65),
                        label: "Today",
                        value: todayCompletion,
                        count: "\(todayEvents.filter { store.isCompleted(templateID: $0.id, date: Date()) }.count)/\(todayEvents.count)"
                    )
                    ringLabel(
                        color: Color(red:1.0,green:0.72,blue:0.35),
                        label: "This Week",
                        value: weekCompletion,
                        count: nil
                    )
                    ringLabel(
                        color: Color(red:0.55,green:0.75,blue:1.0),
                        label: "This Month",
                        value: monthCompletion,
                        count: nil
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    func ringLabel(color: Color, label: String, value: Double, count: String?) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
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
                }
            }
        }
    }

    // MARK: - Mood Log Card
    var moodLogCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("How are you feeling?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if moodSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(red:0.45,green:0.90,blue:0.65))
                            .transition(.opacity.combined(with: .scale))
                    }
                }

                // Mood picker
                HStack(spacing: 8) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedMood == mood {
                                    selectedMood = nil
                                    showMoodNote = false
                                } else {
                                    selectedMood = mood
                                    showMoodNote = true
                                }
                                moodSaved = false
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.rawValue)
                                    .font(.system(size: 26))
                                Text(mood.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(selectedMood == mood ? mood.color : .white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedMood == mood ? mood.color.opacity(0.2) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedMood == mood ? mood.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                            )
                            .scaleEffect(selectedMood == mood ? 1.05 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Note field
                if showMoodNote {
                    VStack(spacing: 10) {
                        TextField("Add a note... (optional)", text: $moodNote, axis: .vertical)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )

                        Button {
                            withAnimation {
                                moodSaved = true
                                showMoodNote = false
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Text("Log mood")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedMood?.color ?? Color.white.opacity(0.2))
                                )
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Streak Card
    var streakCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(red:1.0,green:0.55,blue:0.20))
                    Text("Streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(adaptiveSecondary())
                }
                Text("\(currentStreak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(adaptiveWhite())
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 12))
                    .foregroundStyle(adaptiveSecondary())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Best Time Card
    var bestTimeCard: some View {
        GlassCard {
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

            // Glow dot tại đầu
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
// TÌM toàn bộ struct GlassCard, ĐỔI THÀNH:
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

struct SkyBodyView: View {
    let currentHour: Double
    let currentMinute: Double

    // 0.0 → 1.0 trong ngày (0h → 24h)
    var dayProgress: Double {
        (currentHour * 60 + currentMinute) / 1440
    }

    // Mặt trời mọc 6h, lặn 20h → 0→1 trong 14h đó
    var sunProgress: Double {
        let start = 6.0 / 24.0   // 0.25
        let end   = 20.0 / 24.0  // 0.833
        return max(0, min(1, (dayProgress - start) / (end - start)))
    }

    // Trăng mọc 20h, lặn 6h (hôm sau) → 0→1 trong 10h
    var moonProgress: Double {
        let p = dayProgress
        if p >= 20.0/24.0 {
            return (p - 20.0/24.0) / (4.0/24.0)  // 20h→24h: 0→0.6
        } else {
            return (p + 4.0/24.0) / (4.0/24.0 + 6.0/24.0)  // 0h→6h: tiếp tục
        }
    }

    var showSun: Bool { currentHour >= 6 && currentHour < 20 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Arc path: x từ -10% → 110%, y đỉnh arc ở 15% height
            if showSun {
                let x = w * (-0.05 + sunProgress * 1.10)
                // Parabola: y thấp ở 2 đầu, cao ở giữa
                let arcY = h * (0.55 - sin(sunProgress * .pi) * 0.38)

                ZStack {
                    // Glow
                   
                    Circle()
                        .fill(Color(red:1.0, green:0.92, blue:0.50).opacity(0.18))
                        .frame(width: 80, height: 80)
                        .blur(radius: 25)                                           
                        .position(x: x, y: arcY)

                    // Sun
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red:1.0,green:0.95,blue:0.50), Color(red:1.0,green:0.75,blue:0.20)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red:1.0,green:0.85,blue:0.30).opacity(0.8), radius: 12)
                        .position(x: x, y: arcY)
                }
                .animation(.linear(duration: 0.5), value: sunProgress)

            } else {
                let mp = max(0, min(1, moonProgress))
                let x  = w * (-0.05 + mp * 1.10)
                let arcY = h * (0.55 - sin(mp * .pi) * 0.38)

                ZStack {
                    // Moon glow
                    Circle()
                        .fill(Color(red:0.75, green:0.80, blue:1.0).opacity(0.25))
                        .frame(width: 100, height: 100)
                        .blur(radius: 35)
                        .position(x: x, y: arcY)

                    // Moon
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red:0.95,green:0.95,blue:1.0), Color(red:0.75,green:0.82,blue:1.0)],
                                startPoint: .top, endPoint: .bottom
                            )
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
