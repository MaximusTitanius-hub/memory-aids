import SwiftUI

/// Active recall + spaced repetition session.
/// Shows each due card, asks the student to answer from memory, then reschedules it.
struct StudyView: View {
    @EnvironmentObject var store: Store
    let setId: UUID?   // nil = every set

    init(setId: UUID?) { self.setId = setId }

    @State private var queue: [(setId: UUID, cardId: UUID)] = []
    @State private var attempt = ""
    @State private var revealed = false
    @State private var reviewedCount = 0
    @State private var started = false

    private var current: (set: StudySet, card: Flashcard)? {
        guard let first = queue.first,
              let set = store.binding(for: first.setId),
              let card = set.cards.first(where: { $0.id == first.cardId }) else { return nil }
        return (set, card)
    }

    var body: some View {
        VStack(spacing: 20) {
            if let current {
                header
                cardView(current.set, current.card)
            } else if started {
                finished
            } else {
                intro
            }
        }
        .padding(28)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if started && current == nil && reviewedCount > 0 { ConfettiView() }
        }
        .onAppear(perform: buildQueue)
    }

    private var dueCards: [(setId: UUID, cardId: UUID)] {
        store.sets
            .filter { setId == nil || $0.id == setId }
            .flatMap { set in set.cards.filter(\.isDue).map { (setId: set.id, cardId: $0.id) } }
    }

    private func buildQueue() {
        queue = dueCards.shuffled()
        started = !queue.isEmpty
        reviewedCount = 0
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                stat("flame.fill", "\(Streak.current)", Streak.current == 1 ? "day streak" : "day streak", .orange)
                stat("checkmark.seal.fill", "\(reviewedCount)", "done", .green)
                stat("tray.full.fill", "\(queue.count)", "to go", Theme.brandColor)
                stat("trophy.fill", "\(masteredCount)", "mastered", .yellow)
            }
            ProgressView(value: Double(reviewedCount), total: Double(max(reviewedCount + queue.count, 1)))
                .tint(Theme.brandColor)
        }
    }

    private var masteredCount: Int {
        store.sets.filter { setId == nil || $0.id == setId }.flatMap(\.cards).filter { $0.box >= 3 }.count
    }

    private func stat(_ symbol: String, _ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.rounded(.title3, weight: .heavy))
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.1)))
    }

    private func cardView(_ set: StudySet, _ card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if setId == nil {
                Text(set.title).font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            }
            Text(card.question).font(.rounded(.title2, weight: .semibold)).fixedSize(horizontal: false, vertical: true)

            Text("Type or say your answer before revealing. Trying to remember is what makes it stick.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $attempt)
                .font(.body)
                .frame(height: 90)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

            if revealed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Answer").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(card.answer).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                    if !card.hint.isEmpty {
                        Label(card.hint, systemImage: "lightbulb.fill").foregroundStyle(.orange)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))

                Text("How well did you remember it?").font(.headline)
                HStack {
                    ForEach(Flashcard.Grade.allCases, id: \.self) { grade in
                        Button {
                            submit(card: card, set: set, grade)
                        } label: {
                            VStack {
                                Text(grade.rawValue).font(.headline)
                                Text(nextLabel(card, grade)).font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(gradeColor(grade))
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Button("Show answer") { revealed = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.space, modifiers: [])
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func submit(card: Flashcard, set: StudySet, _ grade: Flashcard.Grade) {
        store.review(setId: set.id, cardId: card.id, grade: grade)
        Streak.recordStudy()
        let item = queue.removeFirst()
        if grade == .again { queue.append(item) } // see it again this session
        reviewedCount += 1
        attempt = ""
        revealed = false
    }

    private func nextLabel(_ card: Flashcard, _ grade: Flashcard.Grade) -> String {
        var copy = card
        copy.review(grade)
        let seconds = copy.due.timeIntervalSinceNow
        if seconds < 3600 { return "in 10 min" }
        let days = Int((seconds / 86400).rounded())
        return days == 1 ? "in 1 day" : "in \(days) days"
    }

    private func gradeColor(_ grade: Flashcard.Grade) -> Color {
        switch grade {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }

    private var intro: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text("All caught up!").font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(nextDueText).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Practise all cards anyway") {
                queue = store.sets
                    .filter { setId == nil || $0.id == setId }
                    .flatMap { set in set.cards.map { (setId: set.id, cardId: $0.id) } }
                    .shuffled()
                started = !queue.isEmpty
            }
            .disabled(store.sets.allSatisfy { $0.cards.isEmpty })
        }
    }

    private var finished: some View {
        VStack(spacing: 14) {
            Image(systemName: "party.popper.fill").font(.system(size: 64)).foregroundStyle(.orange)
            Text("Session complete! 🎉").font(.system(size: 30, weight: .heavy, design: .rounded))
            if Streak.current > 0 {
                Label("\(Streak.current)-day streak. Keep it going!", systemImage: "flame.fill")
                    .font(.rounded(.headline)).foregroundStyle(.orange)
            }
            Text("You reviewed \(reviewedCount) cards. They'll come back at growing intervals so they stick.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Done") { started = false }
        }
    }

    private var nextDueText: String {
        let next = store.sets
            .filter { setId == nil || $0.id == setId }
            .flatMap(\.cards).map(\.due).min()
        guard let next else { return "Create a study set to get flashcards." }
        let f = RelativeDateTimeFormatter()
        return "Your next review is " + f.localizedString(for: next, relativeTo: Date()) + "."
    }
}
