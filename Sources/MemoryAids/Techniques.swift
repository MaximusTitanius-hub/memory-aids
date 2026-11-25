import Foundation

/// One of the 20 memory techniques the app can turn study material into.
struct Technique: Identifiable, Hashable {
    let id: Int
    let name: String
    let summary: String
    let symbol: String      // SF Symbol shown next to the technique
    let guidance: String    // Instructions to Claude for filling in the aid

    /// How the app draws the aid's `items` list.
    var layout: AidLayout {
        switch id {
        case 6: return .palace
        case 7: return .story
        case 8: return .colourCode
        case 10: return .acronym
        case 11: return .triangle
        case 15: return .mindMap
        case 17: return .collectibles
        case 18: return .chunks
        default: return .list
        }
    }
}

enum AidLayout {
    case list, palace, story, colourCode, acronym, triangle, mindMap, collectibles, chunks
}

enum Techniques {
    static let all: [Technique] = [
        Technique(id: 1, name: "Exaggeration",
                  summary: "Blow ideas up to enormous, impossible scale.",
                  symbol: "arrow.up.left.and.arrow.down.right",
                  guidance: "Create one or more wildly exaggerated mental images for the key facts. Each item: label = the fact, detail = the exaggerated image."),
        Technique(id: 2, name: "Absurdity",
                  summary: "Make the image ridiculous so it sticks.",
                  symbol: "face.dashed",
                  guidance: "Create absurd, funny scenes that encode the key facts. Each item: label = the fact, detail = the absurd scene."),
        Technique(id: 3, name: "Animation",
                  summary: "Put the concept in motion.",
                  symbol: "figure.run",
                  guidance: "Describe the concept as a moving scene where parts act out the process step by step. Each item: label = the moving part or step, detail = what it does in the animation."),
        Technique(id: 4, name: "Personification",
                  summary: "Turn concepts into characters with personalities.",
                  symbol: "person.2.fill",
                  guidance: "Turn each key concept or element into a character whose personality reflects its real properties. Each item: label = character name, detail = personality and how it reflects the real property."),
        Technique(id: 5, name: "Emotional association",
                  summary: "Attach surprise, excitement or humour.",
                  symbol: "heart.fill",
                  guidance: "Link each key principle to a strong emotion (surprise, excitement, humour, disgust) through a short vivid moment. Each item: label = the principle, detail = the emotional moment. group = the emotion."),
        Technique(id: 6, name: "Memory palace",
                  summary: "Place facts in rooms of a familiar house.",
                  symbol: "house.fill",
                  guidance: "Build a walk through a typical family house (front door, hallway, kitchen, living room, stairs, bathroom, bedroom, garden). Each item: label = the location, detail = the vivid image placed there and the fact it encodes. Keep items in walking order."),
        Technique(id: 7, name: "Story chaining",
                  summary: "Link facts into one continuous adventure.",
                  symbol: "link",
                  guidance: "Write one continuous, ridiculous adventure linking the facts in order. Each item is one story beat in order: label = the fact being encoded, detail = what happens in the story."),
        Technique(id: 8, name: "Colour coding",
                  summary: "Give each category a consistent colour.",
                  symbol: "paintpalette.fill",
                  guidance: "Assign one consistent colour per category (for example forces, energy, electricity, chemical families). Each item: label = a term, detail = why it belongs, group = the category, color = the category's colour (same colour for every item in a category)."),
        Technique(id: 9, name: "Symbol association",
                  summary: "Link symbols and abbreviations to objects.",
                  symbol: "seal.fill",
                  guidance: "Associate each symbol, abbreviation or formula with a concrete object that sounds or looks like it (e.g. Fe = a giant iron FEnce). Each item: label = the symbol, detail = the object and the link."),
        Technique(id: 10, name: "Acronyms and mnemonics",
                  summary: "Memorable sentences for sequences.",
                  symbol: "textformat.abc",
                  guidance: "Create an acronym or mnemonic sentence for any sequence or list. Put the full mnemonic sentence in the scene field. Each item: label = the word of the mnemonic, detail = what its first letter stands for, in order."),
        Technique(id: 11, name: "Formula triangles",
                  summary: "Arrange three related variables visually.",
                  symbol: "triangle.fill",
                  guidance: "Find a formula of the form A = B x C (or A = B / C) in the material and fill the triangle: top = the variable that equals the product, left and right = the two multiplied variables, rule = how to cover a letter to rearrange. If the material has several such formulas, pick the most important one for the triangle and list the others as items (label = formula, detail = what each symbol means and its units). If there is no such formula, make a triangle from the three most connected ideas."),
        Technique(id: 12, name: "Size distortion",
                  summary: "Make tiny things huge and huge things tiny.",
                  symbol: "circle.circle",
                  guidance: "Swap the sizes of things: make microscopic things enormous and enormous things tiny so the scene is memorable. Each item: label = the fact, detail = the size-distorted image."),
        Technique(id: 13, name: "Multisensory association",
                  summary: "Add sounds, textures, movement and smells.",
                  symbol: "hand.raised.fingers.spread.fill",
                  guidance: "Associate each concept with a sound, a texture, a movement and a smell. Each item: label = the concept, detail = the sensory association, group = the sense (Sound, Touch, Movement, Smell, Taste, Sight)."),
        Technique(id: 14, name: "Rhymes and songs",
                  summary: "Turn facts into lyrics.",
                  symbol: "music.note",
                  guidance: "Write short, catchy rhyming lyrics (to a well-known tune such as a nursery rhyme, named in the explanation) that contain the facts accurately. Put the full lyrics with line breaks in the scene field. Each item: label = a line of the song, detail = the fact it encodes."),
        Technique(id: 15, name: "Mind mapping",
                  summary: "Connect ideas through visual branches.",
                  symbol: "point.3.connected.trianglepath.dotted",
                  guidance: "Build a mind map. The title is the central idea. Use 3 to 6 main branches; each item is a leaf: group = its main branch name, label = the short leaf text (max 5 words), detail = a one sentence note, color = one colour per main branch."),
        Technique(id: 16, name: "Dual coding",
                  summary: "Pair the words with a meaningful picture.",
                  symbol: "photo.on.rectangle.angled",
                  guidance: "Pair each key formula or fact with a simple meaningful illustration (the SVG should show it). Each item: label = the formula or fact in words, detail = the picture that represents it and why."),
        Technique(id: 17, name: "Gamification",
                  summary: "Collectible character cards with powers.",
                  symbol: "gamecontroller.fill",
                  guidance: "Turn each key concept or element into a collectible trading card. Each item: label = the card name, detail = 'Ability: ... Weakness: ...' based on real properties, group = rarity (Common, Rare, Epic, Legendary), color = the card's colour."),
        Technique(id: 18, name: "Chunking",
                  summary: "Split big lists into small logical groups.",
                  symbol: "square.grid.3x3.fill",
                  guidance: "Split the material into small logical chunks of 3 to 5 items each. Each item: group = the chunk name, label = the member, detail = a short note, color = one colour per chunk."),
        Technique(id: 19, name: "Active recall",
                  summary: "Rebuild it from memory without notes.",
                  symbol: "brain.head.profile",
                  guidance: "Write recall challenges that make the learner reconstruct formulas, diagrams and lists from memory. Each item: label = the challenge (a question or 'draw/write from memory' task), detail = the correct answer."),
        Technique(id: 20, name: "Spaced repetition",
                  summary: "Revisit at growing intervals.",
                  symbol: "calendar.badge.clock",
                  guidance: "Create a revision schedule for this material (Day 1, Day 2, Day 4, Day 8, Day 16, Day 32). Each item: label = the day, detail = what to review and how (which aids to use). The app also builds flashcards that it schedules automatically."),
    ]

    static func byId(_ id: Int) -> Technique? { all.first { $0.id == id } }

    /// A good default selection for science study.
    static let starterPack: Set<Int> = [4, 6, 8, 9, 10, 11, 15, 17]
}
