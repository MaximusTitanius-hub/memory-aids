import SwiftUI

/// App-wide look: bold rounded type, a colour per technique, and a few playful touches.
enum Theme {
    static let brand = LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.91), Color(red: 0.91, green: 0.28, blue: 0.60)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let brandColor = Color(red: 0.42, green: 0.36, blue: 0.91)

    private static let palette: [Color] = [
        Color(red: 0.42, green: 0.36, blue: 0.91), // violet
        Color(red: 0.91, green: 0.28, blue: 0.60), // pink
        Color(red: 0.99, green: 0.55, blue: 0.13), // orange
        Color(red: 0.09, green: 0.64, blue: 0.60), // teal
        Color(red: 0.18, green: 0.53, blue: 0.87), // blue
        Color(red: 0.15, green: 0.68, blue: 0.38), // green
        Color(red: 0.84, green: 0.19, blue: 0.19), // red
        Color(red: 0.56, green: 0.27, blue: 0.68), // purple
    ]

    static func tint(_ techniqueId: Int) -> Color { palette[(techniqueId - 1 + palette.count) % palette.count] }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

extension Technique {
    var tint: Color { Theme.tint(id) }
}

/// A round, coloured badge with a technique's symbol.
struct TechniqueBadge: View {
    let technique: Technique?
    var size: CGFloat = 40
    var body: some View {
        let tint = technique?.tint ?? Theme.brandColor
        Image(systemName: technique?.symbol ?? "sparkles")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom)))
            .shadow(color: tint.opacity(0.35), radius: 4, y: 2)
    }
}

/// A card container used across the app.
struct Panel<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.07)))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

/// Confetti burst for finishing a study session.
struct ConfettiView: View {
    @State private var animate = false
    private struct Piece { let x: CGFloat; let delay: Double; let color: Color; let symbol: String }
    private let pieces: [Piece] = (0..<40).map { i in
        let symbols = ["star.fill", "circle.fill", "sparkle", "heart.fill", "triangle.fill"]
        let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple, .teal]
        return Piece(x: CGFloat.random(in: 0...1), delay: Double.random(in: 0...0.6),
                     color: colors[i % colors.count], symbol: symbols[i % symbols.count])
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces.indices, id: \.self) { i in
                    let p = pieces[i]
                    Image(systemName: p.symbol)
                        .font(.system(size: CGFloat(10 + (i % 4) * 4)))
                        .foregroundStyle(p.color)
                        .rotationEffect(.degrees(animate ? Double(i * 47) : 0))
                        .position(x: p.x * geo.size.width, y: animate ? geo.size.height + 40 : -30)
                        .animation(.easeIn(duration: 2.2).delay(p.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

/// Tracks a daily study streak (playful motivation).
enum Streak {
    private static let dayKey = "streakLastDay"
    private static let countKey = "streakCount"

    static var current: Int {
        let d = UserDefaults.standard
        guard let last = d.object(forKey: dayKey) as? Date else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return days <= 1 ? d.integer(forKey: countKey) : 0
    }

    static func recordStudy() {
        let d = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let last = d.object(forKey: dayKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: today).day ?? 0
            if days == 0 { return }
            d.set(days == 1 ? d.integer(forKey: countKey) + 1 : 1, forKey: countKey)
        } else {
            d.set(1, forKey: countKey)
        }
        d.set(today, forKey: dayKey)
    }
}
