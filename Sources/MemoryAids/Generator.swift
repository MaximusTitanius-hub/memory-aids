import Foundation

/// Which AI writes the aids.
enum Engine: String, CaseIterable, Identifiable {
    case auto, apple, claude
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Automatic"
        case .apple: return "Apple on-device AI (free, offline)"
        case .claude: return "Claude (needs API key, richer results)"
        }
    }
}

/// Shared wording for both engines.
enum Prompts {
    static let colours = ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink", "brown", "gray"]

    static let system = """
    You are an expert learning designer who turns study material into vivid, accurate memory aids for a student. The material can be any subject.
    Rules:
    - Every fact must be correct and come from the material (you may add widely known, correct context).
    - Make images vivid, concrete, funny and specific to this material. Never generic.
    - Labels are short (under 8 words). Details are one or two sentences.
    - color is one of: \(colours.joined(separator: ", ")). Use group "" when a technique does not need groups.
    - Fill triangle with empty strings unless the technique is Formula triangles.
    - scene: the mental picture the student should imagine, written to "you", 2 to 4 sentences.
    - explanation: one or two sentences on how this aid helps remember the material.
    """

    static let svgRule = """
    - svg: a self-contained illustration of this aid in SVG. viewBox="0 0 480 300", flat cartoon style, bold colours, simple shapes, a few short text labels in font-family sans-serif. No scripts, no external images or fonts, no foreignObject. Under 5000 characters.
    """

    static func techniqueBlock(_ t: Technique) -> String {
        "Technique \(t.id), \(t.name): \(t.summary) \(t.guidance)"
    }
}

@MainActor
final class Generator: ObservableObject {
    @Published var isRunning = false
    @Published var status = ""
    @Published var progress: Double = 0
    @Published var warnings: [String] = []

    /// Turns material into a full study set.
    func run(material: String, pdfData: Data?, techniqueIds: [Int], engine: Engine) async throws -> StudySet {
        isRunning = true
        warnings = []
        progress = 0
        defer { isRunning = false }

        let techniques = techniqueIds.sorted().compactMap(Techniques.byId)
        let resolved = Generator.resolve(engine)
        switch resolved {
        case .claude:
            guard let key = Keychain.loadKey(), !key.isEmpty else { throw ClaudeError.missingKey }
            return try await runClaude(key: key, material: material, pdfData: pdfData, techniques: techniques)
        default:
            return try await runApple(material: material, techniques: techniques)
        }
    }

    /// Automatic: use Claude when a key is saved, otherwise Apple's on-device model.
    static func resolve(_ engine: Engine) -> Engine {
        switch engine {
        case .auto:
            if let key = Keychain.loadKey(), !key.isEmpty { return .claude }
            return .apple
        default:
            return engine
        }
    }

    // MARK: - Claude

    private func runClaude(key: String, material: String, pdfData: Data?, techniques: [Technique]) async throws -> StudySet {
        let client = ClaudeClient(apiKey: key)
        let source: [String: Any]
        if material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let pdfData {
            source = ["type": "document",
                      "source": ["type": "base64", "media_type": "application/pdf",
                                 "data": pdfData.base64EncodedString()]]
        } else {
            source = ["type": "text", "text": "<material>\n\(material)\n</material>"]
        }

        let batches = stride(from: 0, to: techniques.count, by: 4).map {
            Array(techniques[$0..<min($0 + 4, techniques.count)])
        }
        let totalSteps = Double(batches.count + 1)
        status = "Claude is writing your memory aids…"

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        var aids: [Aid] = []
        var title = "Study set"
        var cards: [Flashcard] = []
        var done = 0.0

        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for (index, batch) in batches.enumerated() {
                let prompt = "Create one learning aid for each of these techniques, in this order:\n\n"
                    + batch.map(Prompts.techniqueBlock).joined(separator: "\n\n")
                group.addTask {
                    do {
                        let data = try await client.structuredRequest(
                            system: Prompts.system + "\n" + Prompts.svgRule,
                            content: [source, ["type": "text", "text": prompt]],
                            schema: Schemas.aids)
                        return ("aids\(index)", .success(data))
                    } catch { return ("aids\(index)", .failure(error)) }
                }
            }
            group.addTask {
                do {
                    let data = try await client.structuredRequest(
                        system: Prompts.system,
                        content: [source, ["type": "text", "text": Schemas.cardsPrompt]],
                        schema: Schemas.cards, maxTokens: 16000)
                    return ("cards", .success(data))
                } catch { return ("cards", .failure(error)) }
            }

            for await (name, result) in group {
                done += 1
                progress = done / totalSteps
                switch result {
                case .failure(let error):
                    warnings.append((name == "cards" ? "Flashcards" : "Some aids") + ": " + error.localizedDescription)
                case .success(let data):
                    do {
                        if name == "cards" {
                            let parsed = try decoder.decode(APICards.self, from: data)
                            title = parsed.title
                            cards = parsed.cards.map { Flashcard(question: $0.question, answer: $0.answer, hint: $0.hint) }
                        } else {
                            let parsed = try decoder.decode(APIAids.self, from: data)
                            aids += parsed.aids.map {
                                Aid(techniqueId: $0.techniqueId, title: $0.title, explanation: $0.explanation,
                                    scene: $0.scene, items: $0.items, triangle: $0.triangle, svg: $0.svg)
                            }
                        }
                    } catch {
                        warnings.append("Couldn't read part of the answer: \(error.localizedDescription)")
                    }
                }
            }
        }

        if aids.isEmpty && cards.isEmpty {
            throw ClaudeError.badResponse(warnings.first ?? "nothing was generated")
        }
        aids.sort { $0.techniqueId < $1.techniqueId }
        let text = material.isEmpty ? "(PDF sent directly to Claude)" : material
        return StudySet(title: title, sourceText: text, aids: aids, cards: cards)
    }

    // MARK: - Apple on-device

    private func runApple(material: String, techniques: [Technique]) async throws -> StudySet {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let engine = OnDeviceEngine()
            try engine.checkAvailable()
            let text = material.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw OnDeviceError.noText
            }
            let totalSteps = Double(techniques.count + 2)

            status = "Reading your material…"
            let facts = try await engine.condense(text) { [weak self] part, total in
                Task { @MainActor in self?.status = "Reading your material (part \(part) of \(total))…" }
            }
            progress = 1 / totalSteps

            var aids: [Aid] = []
            for (i, t) in techniques.enumerated() {
                status = "Creating \(t.name) (\(i + 1) of \(techniques.count))…"
                do {
                    aids.append(try await engine.aid(for: t, facts: facts))
                } catch {
                    warnings.append("\(t.name): \(error.localizedDescription)")
                }
                progress = Double(i + 2) / totalSteps
            }

            status = "Writing flashcards…"
            var title = "Study set"
            var cards: [Flashcard] = []
            do {
                (title, cards) = try await engine.cards(facts: facts)
            } catch {
                warnings.append("Flashcards: \(error.localizedDescription)")
            }
            progress = 1
            if aids.isEmpty && cards.isEmpty {
                throw OnDeviceError.nothing(warnings.first ?? "")
            }
            return StudySet(title: title, sourceText: material, aids: aids, cards: cards)
        }
        #endif
        throw OnDeviceError.unsupported
    }
}

// MARK: - JSON schemas and response shapes for Claude

enum Schemas {
    private static func object(_ props: [String: Any]) -> [String: Any] {
        ["type": "object", "additionalProperties": false,
         "required": Array(props.keys).sorted(), "properties": props]
    }
    private static let string: [String: Any] = ["type": "string"]

    static let item = object([
        "label": string, "detail": string, "group": string,
        "color": ["type": "string", "enum": Prompts.colours],
    ])
    static let triangle = object(["top": string, "left": string, "right": string, "rule": string])
    static let aid = object([
        "technique_id": ["type": "integer"],
        "title": string, "explanation": string, "scene": string,
        "items": ["type": "array", "items": item],
        "triangle": triangle,
        "svg": string,
    ])
    static let aids = object(["aids": ["type": "array", "items": aid]])
    static let cards = object([
        "title": string,
        "cards": ["type": "array", "items": object(["question": string, "answer": string, "hint": string])],
    ])

    static let cardsPrompt = """
    Write 12 to 25 flashcards for active recall that cover the most important facts, formulas, definitions and sequences in the material. \
    Questions should make the student reconstruct the answer from memory, not just recognise it. Answers are short and exact. \
    hint is a short memory cue (a vivid image or mnemonic). title is a short name for this material (max 6 words).
    """
}

struct APIAid: Decodable {
    var techniqueId: Int
    var title: String
    var explanation: String
    var scene: String
    var items: [AidItem]
    var triangle: TriangleSpec
    var svg: String
}
struct APIAids: Decodable { var aids: [APIAid] }
struct APICard: Decodable { var question: String; var answer: String; var hint: String }
struct APICards: Decodable { var title: String; var cards: [APICard] }

enum OnDeviceError: LocalizedError {
    case unsupported, noText, unavailable(String), nothing(String)
    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Apple's on-device AI needs a Mac with an Apple chip (M1 or later) running macOS 26 or later. You can add a Claude API key in Settings instead."
        case .noText:
            return "No text found. If your PDF is a scan (photos of pages), add a Claude API key in Settings, which can read scanned PDFs."
        case .unavailable(let why):
            return "Apple's on-device AI isn't available: \(why)"
        case .nothing(let why):
            return "Nothing could be generated. \(why)"
        }
    }
}
