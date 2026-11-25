// The 20 memory techniques (kept in sync with the Mac app's Techniques.swift).
const TECHNIQUES = [
  {
    "id": 1,
    "name": "Exaggeration",
    "summary": "Blow ideas up to enormous, impossible scale.",
    "icon": "🏙️",
    "layout": "list",
    "guidance": "Create one or more wildly exaggerated mental images for the key facts. Each item: label = the fact, detail = the exaggerated image."
  },
  {
    "id": 2,
    "name": "Absurdity",
    "summary": "Make the image ridiculous so it sticks.",
    "icon": "🤪",
    "layout": "list",
    "guidance": "Create absurd, funny scenes that encode the key facts. Each item: label = the fact, detail = the absurd scene."
  },
  {
    "id": 3,
    "name": "Animation",
    "summary": "Put the concept in motion.",
    "icon": "🏃",
    "layout": "list",
    "guidance": "Describe the concept as a moving scene where parts act out the process step by step. Each item: label = the moving part or step, detail = what it does in the animation."
  },
  {
    "id": 4,
    "name": "Personification",
    "summary": "Turn concepts into characters with personalities.",
    "icon": "🎭",
    "layout": "list",
    "guidance": "Turn each key concept or element into a character whose personality reflects its real properties. Each item: label = character name, detail = personality and how it reflects the real property."
  },
  {
    "id": 5,
    "name": "Emotional association",
    "summary": "Attach surprise, excitement or humour.",
    "icon": "😲",
    "layout": "list",
    "guidance": "Link each key principle to a strong emotion (surprise, excitement, humour, disgust) through a short vivid moment. Each item: label = the principle, detail = the emotional moment. group = the emotion."
  },
  {
    "id": 6,
    "name": "Memory palace",
    "summary": "Place facts in rooms of a familiar house.",
    "icon": "🏠",
    "layout": "palace",
    "guidance": "Build a walk through a typical family house (front door, hallway, kitchen, living room, stairs, bathroom, bedroom, garden). Each item: label = the location, detail = the vivid image placed there and the fact it encodes. Keep items in walking order."
  },
  {
    "id": 7,
    "name": "Story chaining",
    "summary": "Link facts into one continuous adventure.",
    "icon": "🔗",
    "layout": "story",
    "guidance": "Write one continuous, ridiculous adventure linking the facts in order. Each item is one story beat in order: label = the fact being encoded, detail = what happens in the story."
  },
  {
    "id": 8,
    "name": "Colour coding",
    "summary": "Give each category a consistent colour.",
    "icon": "🎨",
    "layout": "colourCode",
    "guidance": "Assign one consistent colour per category (for example forces, energy, electricity, chemical families). Each item: label = a term, detail = why it belongs, group = the category, color = the category's colour (same colour for every item in a category)."
  },
  {
    "id": 9,
    "name": "Symbol association",
    "summary": "Link symbols and abbreviations to objects.",
    "icon": "🔣",
    "layout": "list",
    "guidance": "Associate each symbol, abbreviation or formula with a concrete object that sounds or looks like it (e.g. Fe = a giant iron FEnce). Each item: label = the symbol, detail = the object and the link."
  },
  {
    "id": 10,
    "name": "Acronyms and mnemonics",
    "summary": "Memorable sentences for sequences.",
    "icon": "🔤",
    "layout": "acronym",
    "guidance": "Create an acronym or mnemonic sentence for any sequence or list. Put the full mnemonic sentence in the scene field. Each item: label = the word of the mnemonic, detail = what its first letter stands for, in order."
  },
  {
    "id": 11,
    "name": "Formula triangles",
    "summary": "Arrange three related variables visually.",
    "icon": "🔺",
    "layout": "triangle",
    "guidance": "Find a formula of the form A = B x C (or A = B / C) in the material and fill the triangle: top = the variable that equals the product, left and right = the two multiplied variables, rule = how to cover a letter to rearrange. If the material has several such formulas, pick the most important one for the triangle and list the others as items (label = formula, detail = what each symbol means and its units). If there is no such formula, make a triangle from the three most connected ideas."
  },
  {
    "id": 12,
    "name": "Size distortion",
    "summary": "Make tiny things huge and huge things tiny.",
    "icon": "🔍",
    "layout": "list",
    "guidance": "Swap the sizes of things: make microscopic things enormous and enormous things tiny so the scene is memorable. Each item: label = the fact, detail = the size-distorted image."
  },
  {
    "id": 13,
    "name": "Multisensory association",
    "summary": "Add sounds, textures, movement and smells.",
    "icon": "👂",
    "layout": "list",
    "guidance": "Associate each concept with a sound, a texture, a movement and a smell. Each item: label = the concept, detail = the sensory association, group = the sense (Sound, Touch, Movement, Smell, Taste, Sight)."
  },
  {
    "id": 14,
    "name": "Rhymes and songs",
    "summary": "Turn facts into lyrics.",
    "icon": "🎵",
    "layout": "list",
    "guidance": "Write short, catchy rhyming lyrics (to a well-known tune such as a nursery rhyme, named in the explanation) that contain the facts accurately. Put the full lyrics with line breaks in the scene field. Each item: label = a line of the song, detail = the fact it encodes."
  },
  {
    "id": 15,
    "name": "Mind mapping",
    "summary": "Connect ideas through visual branches.",
    "icon": "🕸️",
    "layout": "mindMap",
    "guidance": "Build a mind map. The title is the central idea. Use 3 to 6 main branches; each item is a leaf: group = its main branch name, label = the short leaf text (max 5 words), detail = a one sentence note, color = one colour per main branch."
  },
  {
    "id": 16,
    "name": "Dual coding",
    "summary": "Pair the words with a meaningful picture.",
    "icon": "🖼️",
    "layout": "list",
    "guidance": "Pair each key formula or fact with a simple meaningful illustration (the SVG should show it). Each item: label = the formula or fact in words, detail = the picture that represents it and why."
  },
  {
    "id": 17,
    "name": "Gamification",
    "summary": "Collectible character cards with powers.",
    "icon": "🃏",
    "layout": "collectibles",
    "guidance": "Turn each key concept or element into a collectible trading card. Each item: label = the card name, detail = 'Ability: ... Weakness: ...' based on real properties, group = rarity (Common, Rare, Epic, Legendary), color = the card's colour."
  },
  {
    "id": 18,
    "name": "Chunking",
    "summary": "Split big lists into small logical groups.",
    "icon": "🧩",
    "layout": "chunks",
    "guidance": "Split the material into small logical chunks of 3 to 5 items each. Each item: group = the chunk name, label = the member, detail = a short note, color = one colour per chunk."
  },
  {
    "id": 19,
    "name": "Active recall",
    "summary": "Rebuild it from memory without notes.",
    "icon": "🧠",
    "layout": "list",
    "guidance": "Write recall challenges that make the learner reconstruct formulas, diagrams and lists from memory. Each item: label = the challenge (a question or 'draw/write from memory' task), detail = the correct answer."
  },
  {
    "id": 20,
    "name": "Spaced repetition",
    "summary": "Revisit at growing intervals.",
    "icon": "📅",
    "layout": "list",
    "guidance": "Create a revision schedule for this material (Day 1, Day 2, Day 4, Day 8, Day 16, Day 32). Each item: label = the day, detail = what to review and how (which aids to use). The app also builds flashcards that it schedules automatically."
  }
];

const STARTER_PACK = [4, 6, 8, 9, 10, 11, 15, 17];

if (typeof module !== 'undefined') module.exports = { TECHNIQUES, STARTER_PACK };
