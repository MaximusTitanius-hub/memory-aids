import SwiftUI
import AVFoundation
import WebKit

extension Color {
    static func named(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return Color(red: 0.93, green: 0.73, blue: 0.0)
        case "green": return .green
        case "teal": return .teal
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray", "grey": return .gray
        default: return .accentColor
        }
    }
}

/// Reads text aloud (useful for rhymes, songs and multisensory aids).
@MainActor
final class Speaker: ObservableObject {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate); return }
        synth.speak(AVSpeechUtterance(string: text))
    }
}

// MARK: - Aid card

struct AidCard: View {
    let aid: Aid

    var body: some View {
        let t = aid.technique
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: t?.symbol ?? "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor))
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.map { "\($0.id). \($0.name)" } ?? "Technique")
                        .font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
                    Text(aid.title).font(.title2.bold())
                }
                Spacer()
                Button {
                    Speaker.shared.speak(speakableText)
                } label: { Label("Read aloud", systemImage: "speaker.wave.2.fill") }
                    .buttonStyle(.borderless)
            }

            if !aid.explanation.isEmpty {
                Text(aid.explanation).foregroundStyle(.secondary)
            }

            if !aid.svg.isEmpty {
                SVGView(svg: aid.svg)
                    .frame(height: 300)
                    .frame(maxWidth: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
            }

            if !aid.scene.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: t?.id == 14 ? "music.note.list" : "eye.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(aid.scene).font(.title3).italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
            }

            AidVisual(aid: aid)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
    }

    private var speakableText: String {
        ([aid.title, aid.scene] + aid.items.map { "\($0.label). \($0.detail)" }).joined(separator: ". ")
    }
}

/// Picks the drawing that suits the technique.
struct AidVisual: View {
    let aid: Aid

    var body: some View {
        switch aid.technique?.layout ?? .list {
        case .mindMap: MindMapView(center: aid.title, items: aid.items)
        case .triangle:
            VStack(alignment: .leading, spacing: 16) {
                if !aid.triangle.isEmpty { FormulaTriangleView(spec: aid.triangle) }
                ItemList(items: aid.items)
            }
        case .colourCode: ColourCodeView(items: aid.items)
        case .palace: PalaceView(items: aid.items)
        case .story: StoryChainView(items: aid.items)
        case .collectibles: CollectibleCardsView(items: aid.items)
        case .chunks: ChunkView(items: aid.items)
        case .acronym: AcronymView(items: aid.items)
        case .list: ItemList(items: aid.items)
        }
    }
}

/// Groups items by `group`, keeping first-seen order.
func grouped(_ items: [AidItem]) -> [(name: String, items: [AidItem])] {
    var order: [String] = []
    var map: [String: [AidItem]] = [:]
    for item in items {
        let key = item.group.isEmpty ? item.label : item.group
        if map[key] == nil { order.append(key) }
        map[key, default: []].append(item)
    }
    return order.map { ($0, map[$0] ?? []) }
}

// MARK: - Layouts

struct ItemList: View {
    let items: [AidItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.named(item.color)).frame(width: 12, height: 12).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.label).font(.headline)
                            if !item.group.isEmpty {
                                Text(item.group).font(.caption)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.named(item.color).opacity(0.2)))
                            }
                        }
                        Text(item.detail).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
}

struct MindNode {
    var branch: CGPoint
    var leaves: [CGPoint]
    var color: Color
    var name: String
    var items: [AidItem]
}

struct MindMapView: View {
    let center: String
    let items: [AidItem]

    private func layout(_ size: CGSize) -> [MindNode] {
        let branches = grouped(items)
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        let r1 = min(size.width, size.height) * 0.27
        let r2 = min(size.width * 0.46, size.height * 0.46)
        let n = Double(max(branches.count, 1))
        var result: [MindNode] = []
        for (i, b) in branches.enumerated() {
            let angle = Double(i) / n * 2 * Double.pi - Double.pi / 2
            let bp = CGPoint(x: mid.x + CGFloat(cos(angle)) * r1 * 1.35,
                             y: mid.y + CGFloat(sin(angle)) * r1)
            let spread = (2 * Double.pi / n) * 0.7
            let count = Double(b.items.count)
            var leaves: [CGPoint] = []
            for j in 0..<b.items.count {
                let a: Double = count <= 1 ? angle : angle - spread / 2 + spread * Double(j) / (count - 1)
                leaves.append(CGPoint(x: mid.x + CGFloat(cos(a)) * r2 * 1.05,
                                      y: mid.y + CGFloat(sin(a)) * r2 * 0.92))
            }
            result.append(MindNode(branch: bp, leaves: leaves,
                                   color: Color.named(b.items.first?.color ?? ""),
                                   name: b.name, items: b.items))
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let nodes = layout(geo.size)
            ZStack {
                Path { p in
                    for node in nodes {
                        p.move(to: mid)
                        p.addQuadCurve(to: node.branch, control: CGPoint(x: (mid.x + node.branch.x) / 2, y: node.branch.y))
                    }
                }
                .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                ForEach(nodes.indices, id: \.self) { i in
                    MindBranchView(node: nodes[i])
                }

                Text(center)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 160)
                    .padding(14)
                    .background(Circle().fill(Color.accentColor.opacity(0.2)).frame(minWidth: 120, minHeight: 120))
                    .position(mid)
            }
        }
        .frame(height: 560)
    }
}

struct MindBranchView: View {
    let node: MindNode
    var body: some View {
        ZStack {
            Path { p in
                for leaf in node.leaves {
                    p.move(to: node.branch)
                    p.addLine(to: leaf)
                }
            }
            .stroke(node.color.opacity(0.7), lineWidth: 2)

            ForEach(node.leaves.indices, id: \.self) { j in
                Text(node.items[j].label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 130)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(node.color.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(node.color, lineWidth: 1))
                    .help(node.items[j].detail)
                    .position(node.leaves[j])
            }
            Text(node.name)
                .font(.callout.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 140)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(node.color))
                .position(node.branch)
        }
    }
}

struct FormulaTriangleView: View {
    let spec: TriangleSpec

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: w / 2, y: 0))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.orange.opacity(0.35), .pink.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: CGPoint(x: w / 2, y: 0))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                        p.move(to: CGPoint(x: w * 0.25, y: h * 0.5))
                        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.5))
                        p.move(to: CGPoint(x: w / 2, y: h * 0.5))
                        p.addLine(to: CGPoint(x: w / 2, y: h))
                    }
                    .stroke(Color.primary, lineWidth: 3)
                    Text(spec.top).font(.title.bold()).frame(maxWidth: w * 0.4)
                        .minimumScaleFactor(0.4).lineLimit(2).multilineTextAlignment(.center)
                        .position(x: w / 2, y: h * 0.32)
                    Text(spec.left).font(.title.bold()).frame(maxWidth: w * 0.3)
                        .minimumScaleFactor(0.4).lineLimit(2).multilineTextAlignment(.center)
                        .position(x: w * 0.3, y: h * 0.76)
                    Text(spec.right).font(.title.bold()).frame(maxWidth: w * 0.3)
                        .minimumScaleFactor(0.4).lineLimit(2).multilineTextAlignment(.center)
                        .position(x: w * 0.7, y: h * 0.76)
                }
            }
            .frame(width: 300, height: 250)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(spec.top) = \(spec.left) × \(spec.right)").font(.title3.monospaced().bold())
                Text("\(spec.left) = \(spec.top) ÷ \(spec.right)").font(.body.monospaced())
                Text("\(spec.right) = \(spec.top) ÷ \(spec.left)").font(.body.monospaced())
                if !spec.rule.isEmpty {
                    Text(spec.rule).foregroundStyle(.secondary).padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ColourCodeView: View {
    let items: [AidItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(grouped(items).enumerated()), id: \.offset) { _, group in
                let colour = Color.named(group.items.first?.color ?? "")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4).fill(colour).frame(width: 24, height: 24)
                        Text(group.name).font(.headline)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label).font(.callout.bold()).foregroundStyle(.white)
                                Text(item.detail).font(.caption).foregroundStyle(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(colour))
                        }
                    }
                }
            }
        }
    }
}

struct PalaceView: View {
    let items: [AidItem]
    private let icons = ["door.left.hand.open", "lamp.floor.fill", "refrigerator.fill", "sofa.fill",
                         "stairs", "shower.fill", "bed.double.fill", "tree.fill", "car.fill", "tv.fill"]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 0)], spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(i + 1)").font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Circle().fill(Color.brown))
                        Image(systemName: icons[i % icons.count]).foregroundStyle(.brown)
                        Text(item.label).font(.headline)
                    }
                    Text(item.detail).font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                .background(Color.brown.opacity(i % 2 == 0 ? 0.08 : 0.14))
                .border(Color.brown.opacity(0.5), width: 1.5)
            }
        }
        .overlay(Rectangle().stroke(Color.brown, lineWidth: 4))
    }
}

struct StoryChainView: View {
    let items: [AidItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Text("\(i + 1)").font(.headline).foregroundStyle(.white)
                            .frame(width: 32, height: 32).background(Circle().fill(Color.named(item.color)))
                        if i < items.count - 1 {
                            Rectangle().fill(Color.secondary.opacity(0.4)).frame(width: 3).frame(minHeight: 30)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.detail).font(.body).fixedSize(horizontal: false, vertical: true)
                        Text("Remembers: " + item.label).font(.caption.bold()).foregroundStyle(Color.named(item.color))
                    }
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

struct CollectibleCardsView: View {
    let items: [AidItem]
    private func stars(_ rarity: String) -> Int {
        switch rarity.lowercased() {
        case "legendary": return 4
        case "epic": return 3
        case "rare": return 2
        default: return 1
        }
    }
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let colour = Color.named(item.color)
                VStack(spacing: 8) {
                    HStack {
                        Text(item.group.isEmpty ? "Common" : item.group).font(.caption2.bold()).textCase(.uppercase)
                        Spacer()
                        HStack(spacing: 1) {
                            ForEach(0..<stars(item.group), id: \.self) { _ in Image(systemName: "star.fill") }
                        }.font(.caption2)
                    }
                    .foregroundStyle(.white)
                    Text(String(item.label.prefix(2)))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(colour)
                        .frame(width: 90, height: 90)
                        .background(Circle().fill(.white))
                    Text(item.label).font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                    Text(item.detail).font(.caption).foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 260)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [colour, colour.opacity(0.65)], startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(stars(item.group) >= 3 ? 1 : 0), lineWidth: 3))
                .shadow(radius: 3, y: 2)
            }
        }
    }
}

struct ChunkView: View {
    let items: [AidItem]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(Array(grouped(items).enumerated()), id: \.offset) { i, group in
                let colour = Color.named(group.items.first?.color ?? "")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chunk \(i + 1): \(group.name)").font(.headline).foregroundStyle(colour)
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text("• " + item.label).font(.callout.bold())
                            if !item.detail.isEmpty {
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 10).fill(colour.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(colour, lineWidth: 2))
            }
        }
    }
}

struct AcronymView: View {
    let items: [AidItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Text(String(item.label.prefix(1)).uppercased())
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 60)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color.named(Prompts.colours[i % Prompts.colours.count])))
                }
            }
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.label).font(.headline)
                        .foregroundStyle(Color.named(Prompts.colours[i % Prompts.colours.count]))
                    Text("→ " + item.detail).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - SVG illustration

/// Shows an SVG drawing. JavaScript and network loading are blocked.
struct SVGView: NSViewRepresentable {
    let svg: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let cleaned = svg.replacingOccurrences(of: "<script", with: "<!--", options: .caseInsensitive)
        let html = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:">
        <style>html,body{margin:0;height:100%;background:#fff;display:flex;align-items:center;justify-content:center;overflow:hidden}
        svg{width:100%;height:100%}</style></head><body>\(cleaned)</body></html>
        """
        view.loadHTMLString(html, baseURL: nil)
    }
}
