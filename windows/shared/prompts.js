// Prompt text and JSON schemas shared by the Claude and Ollama engines.
const { TECHNIQUES } = require('./techniques');

const COLOURS = ['red', 'orange', 'yellow', 'green', 'teal', 'blue', 'purple', 'pink', 'brown', 'gray'];

const SYSTEM = `You are an expert learning designer who turns study material into vivid, accurate memory aids for a student. The material can be any subject.
Rules:
- Every fact must be correct and come from the material (you may add widely known, correct context).
- Make images vivid, concrete, funny and specific to this material. Never generic.
- Labels are short (under 8 words). Details are one or two sentences.
- color is one of: ${COLOURS.join(', ')}. Use group "" when a technique does not need groups.
- Fill triangle with empty strings unless the technique is Formula triangles.
- scene: the mental picture the student should imagine, written to "you", 2 to 4 sentences.
- explanation: one or two sentences on how this aid helps remember the material.`;

const SVG_RULE = `- svg: a self-contained illustration of this aid in SVG. viewBox="0 0 480 300", flat cartoon style, bold colours, simple shapes, a few short text labels in font-family sans-serif. No scripts, no external images or fonts, no foreignObject. Under 5000 characters.`;

const CARDS_PROMPT = `Write 12 to 25 flashcards for active recall that cover the most important facts, formulas, definitions and sequences in the material. Questions should make the student reconstruct the answer from memory, not just recognise it. Answers are short and exact. hint is a short memory cue (a vivid image or mnemonic). title is a short name for this material (max 6 words).`;

function techniqueBlock(t) {
  return `Technique ${t.id}, ${t.name}: ${t.summary} ${t.guidance}`;
}

function object(props) {
  return { type: 'object', additionalProperties: false, required: Object.keys(props).sort(), properties: props };
}
const str = { type: 'string' };

const ITEM = object({ label: str, detail: str, group: str, color: { type: 'string', enum: COLOURS } });
const TRIANGLE = object({ top: str, left: str, right: str, rule: str });

function aidSchema(withSvg) {
  const props = {
    technique_id: { type: 'integer' },
    title: str, explanation: str, scene: str,
    items: { type: 'array', items: ITEM },
    triangle: TRIANGLE,
  };
  if (withSvg) props.svg = str;
  return object(props);
}

const AIDS_SCHEMA = object({ aids: { type: 'array', items: aidSchema(true) } });
const SINGLE_AID_SCHEMA = aidSchema(false);
const CARDS_SCHEMA = object({
  title: str,
  cards: { type: 'array', items: object({ question: str, answer: str, hint: str }) },
});
const FACTS_SCHEMA = object({ facts: { type: 'array', items: str } });

function byId(id) { return TECHNIQUES.find((t) => t.id === id); }

module.exports = {
  COLOURS, SYSTEM, SVG_RULE, CARDS_PROMPT, techniqueBlock,
  AIDS_SCHEMA, SINGLE_AID_SCHEMA, CARDS_SCHEMA, FACTS_SCHEMA, byId,
};
