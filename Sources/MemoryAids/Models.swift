import Foundation

struct AidItem: Codable, Hashable {
    var label: String
    var detail: String
    var color: String
    var group: String
}

struct TriangleSpec: Codable, Hashable {
    var top: String
    var left: String
    var right: String
    var rule: String

    var isEmpty: Bool { top.isEmpty && left.isEmpty && right.isEmpty }
}

/// One generated learning aid, using one technique.
struct Aid: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var techniqueId: Int
    var title: String
    var explanation: String
    var scene: String
    var items: [AidItem]
    var triangle: TriangleSpec
    var svg: String

    var technique: Technique? { Techniques.byId(techniqueId) }
}

/// A question/answer card scheduled with a simple Leitner-style spaced repetition system.
struct Flashcard: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var question: String
    var answer: String
    var hint: String
    var box: Int = 0
    var due: Date = Date()
    var reviews: Int = 0

    /// Days until the next review for each box.
    static let intervals: [Double] = [1, 2, 4, 8, 16, 32, 64]

    enum Grade: String, CaseIterable {
        case again = "Forgot", hard = "Hard", good = "Good", easy = "Easy"
    }

    mutating func review(_ grade: Grade, now: Date = Date()) {
        reviews += 1
        let day: Double = 24 * 60 * 60
        switch grade {
        case .again:
            box = 0
            due = now.addingTimeInterval(10 * 60)
        case .hard:
            due = now.addingTimeInterval(max(1, Flashcard.intervals[box] / 2) * day)
        case .good:
            box = min(box + 1, Flashcard.intervals.count - 1)
            due = now.addingTimeInterval(Flashcard.intervals[box] * day)
        case .easy:
            box = min(box + 2, Flashcard.intervals.count - 1)
            due = now.addingTimeInterval(Flashcard.intervals[box] * day)
        }
    }

    var isDue: Bool { due <= Date() }
}

struct StudySet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()
    var sourceText: String
    var aids: [Aid]
    var cards: [Flashcard]

    var dueCount: Int { cards.filter(\.isDue).count }
}
