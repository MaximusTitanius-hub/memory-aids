#if canImport(FoundationModels)
import Foundation
import FoundationModels

// Apple's on-device model (macOS 26+, Apple silicon, Apple Intelligence turned on).
// It is free and offline, but has a small context window (about 4,000 tokens),
// so long material is first condensed into key facts, and each technique gets its own request.

@available(macOS 26.0, *)
@Generable
struct GenItem {
    @Guide(description: "Short label, under 8 words")
    var label: String
    @Guide(description: "One or two sentences")
    var detail: String
    @Guide(description: "One of: red, orange, yellow, green, teal, blue, purple, pink, brown, gray")
    var color: String
    @Guide(description: "Group or category name, or empty if not needed")
    var group: String
}

@available(macOS 26.0, *)
@Generable
struct GenTriangle {
    @Guide(description: "Variable at the top of the formula triangle, or empty")
    var top: String
    @Guide(description: "Bottom-left variable, or empty")
    var left: String
    @Guide(description: "Bottom-right variable, or empty")
    var right: String
    @Guide(description: "How to cover a letter to rearrange the formula, or empty")
    var rule: String
}

@available(macOS 26.0, *)
@Generable
struct GenAid {
    @Guide(description: "Catchy title for this memory aid")
    var title: String
    @Guide(description: "One or two sentences on how this aid helps remember the material")
    var explanation: String
    @Guide(description: "The vivid mental picture to imagine, written to 'you', 2 to 4 sentences")
    var scene: String
    @Guide(description: "Between 3 and 8 items")
    var items: [GenItem]
    var triangle: GenTriangle
}

@available(macOS 26.0, *)
@Generable
struct GenCard {
    @Guide(description: "A question that makes the student recall a fact from memory")
    var question: String
    @Guide(description: "Short, exact answer")
    var answer: String
    @Guide(description: "A short memory cue")
    var hint: String
}

@available(macOS 26.0, *)
@Generable
struct GenCards {
    @Guide(description: "Short name for this material, max 6 words")
    var title: String
    @Guide(description: "Between 8 and 15 flashcards")
    var cards: [GenCard]
}

@available(macOS 26.0, *)
@Generable
struct GenFacts {
    @Guide(description: "The key facts, formulas, definitions and sequences, each as one precise sentence")
    var facts: [String]
}

@available(macOS 26.0, *)
struct OnDeviceEngine {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private let chunkSize = 4500
    private let factsLimit = 5000

    func checkAvailable() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(let reason):
            let why: String
            switch reason {
            case .deviceNotEligible:
                why = "this Mac doesn't support Apple Intelligence. Add a Claude API key in Settings instead."
            case .appleIntelligenceNotEnabled:
                why = "Apple Intelligence is turned off. Turn it on in System Settings > Apple Intelligence & Siri."
            case .modelNotReady:
                why = "the model is still downloading. Try again in a few minutes."
            @unknown default:
                why = "\(reason)"
            }
            throw OnDeviceError.unavailable(why)
        }
    }

    /// Shrinks long material into a list of key facts that fits the small context window.
    func condense(_ text: String, progress: @escaping (Int, Int) -> Void) async throws -> String {
        if text.count <= factsLimit { return text }
        let chunks = OnDeviceSplit.split(text, size: chunkSize)
        var facts: [String] = []
        for (i, chunk) in chunks.enumerated() {
            progress(i + 1, chunks.count)
            let session = LanguageModelSession(instructions: "You extract the key facts a student must memorise from study material. Keep facts accurate and precise.")
            let response = try await session.respond(
                to: "List the key facts (at most 12) in this part of the material:\n\n\(chunk)",
                generating: GenFacts.self)
            facts += response.content.facts
        }
        var joined = facts.map { "- " + $0 }.joined(separator: "\n")
        if joined.count > factsLimit { joined = String(joined.prefix(factsLimit)) }
        return joined
    }

    func aid(for technique: Technique, facts: String) async throws -> Aid {
        let session = LanguageModelSession(instructions: Prompts.system)
        let prompt = """
        Material:
        \(facts)

        Create one memory aid for the material using this technique.
        \(Prompts.techniqueBlock(technique))
        """
        let g = try await session.respond(to: prompt, generating: GenAid.self).content
        return Aid(
            techniqueId: technique.id,
            title: g.title,
            explanation: g.explanation,
            scene: g.scene,
            items: g.items.map { AidItem(label: $0.label, detail: $0.detail, color: $0.color.lowercased(), group: $0.group) },
            triangle: TriangleSpec(top: g.triangle.top, left: g.triangle.left, right: g.triangle.right, rule: g.triangle.rule),
            svg: "")
    }

    func cards(facts: String) async throws -> (String, [Flashcard]) {
        let session = LanguageModelSession(instructions: "You write accurate active-recall flashcards for a student.")
        let g = try await session.respond(
            to: "Material:\n\(facts)\n\nWrite flashcards covering the most important facts.",
            generating: GenCards.self).content
        return (g.title, g.cards.map { Flashcard(question: $0.question, answer: $0.answer, hint: $0.hint) })
    }
}
#endif
