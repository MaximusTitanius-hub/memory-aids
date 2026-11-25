import SwiftUI

struct SetDetailView: View {
    @EnvironmentObject var store: Store
    let setId: UUID

    init(setId: UUID) { self.setId = setId }

    enum Tab: String, CaseIterable { case aids = "Memory aids", cards = "Flashcards", study = "Study", source = "Original notes" }
    @State private var tab: Tab = .aids
    @State private var filter: Int? = nil

    var body: some View {
        if let set = store.binding(for: setId) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.title).font(.system(size: 28, weight: .heavy, design: .rounded))
                        Text("\(set.aids.count) memory aids · \(set.cards.count) flashcards · \(set.dueCount) due for review")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 440)
                }
                .padding(20)
                Divider()

                switch tab {
                case .aids: aidsView(set)
                case .cards: cardsView(set)
                case .study: StudyView(setId: set.id)
                case .source:
                    ScrollView {
                        Text(set.sourceText).textSelection(.enabled)
                            .frame(maxWidth: 800, alignment: .leading).padding(24)
                    }
                }
            }
            .id(setId)
        }
    }

    private func aidsView(_ set: StudySet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", selected: filter == nil) { filter = nil }
                        ForEach(set.aids) { aid in
                            if let t = aid.technique {
                                chip(t.name, selected: filter == t.id) { filter = t.id }
                            }
                        }
                    }
                }
                ForEach(set.aids.filter { filter == nil || $0.techniqueId == filter }) { aid in
                    AidCard(aid: aid)
                }
                if set.aids.isEmpty {
                    Text("No aids were created for this set.").foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.callout)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.12)))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func cardsView(_ set: StudySet) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                ForEach(set.cards) { card in
                    FlipCard(card: card)
                }
            }
            .padding(20)
        }
    }
}

/// Click to flip between question and answer.
struct FlipCard: View {
    let card: Flashcard
    @State private var flipped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(flipped ? "ANSWER" : "QUESTION").font(.caption.bold()).foregroundStyle(.secondary)
            Text(flipped ? card.answer : card.question).font(.title3)
                .fixedSize(horizontal: false, vertical: true)
            if flipped && !card.hint.isEmpty {
                Label(card.hint, systemImage: "lightbulb.fill").font(.callout).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Text(flipped ? "Click to hide" : "Click to reveal").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(flipped ? Color.green.opacity(0.12) : Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { flipped.toggle() } }
    }
}
