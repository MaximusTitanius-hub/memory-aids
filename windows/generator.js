// Turns study material into memory aids + flashcards using Claude or a local Ollama model.
const crypto = require('crypto');
const Anthropic = require('@anthropic-ai/sdk');
const P = require('./shared/prompts');

const OLLAMA_URL = 'http://127.0.0.1:11434';

function newCard(c) {
  return { id: crypto.randomUUID(), question: c.question, answer: c.answer, hint: c.hint || '', box: 0, due: Date.now(), reviews: 0 };
}

function newAid(a, techniqueId) {
  return {
    id: crypto.randomUUID(),
    techniqueId: techniqueId ?? a.technique_id,
    title: a.title || '',
    explanation: a.explanation || '',
    scene: a.scene || '',
    items: (a.items || []).map((i) => ({ label: i.label || '', detail: i.detail || '', group: i.group || '', color: (i.color || '').toLowerCase() })),
    triangle: a.triangle || { top: '', left: '', right: '', rule: '' },
    svg: a.svg || '',
  };
}

function parseJSON(text) {
  try { return JSON.parse(text); } catch {
    const start = text.indexOf('{'); const end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return JSON.parse(text.slice(start, end + 1));
    throw new Error('the AI answer was not valid JSON');
  }
}

function friendlyClaudeError(err) {
  if (err instanceof Anthropic.AuthenticationError) return 'Claude rejected the API key. Check it in Settings.';
  if (err instanceof Anthropic.RateLimitError) return 'Too many requests right now. Wait a minute and try again.';
  if (err instanceof Anthropic.APIConnectionError) return 'Could not reach Claude. Check your internet connection.';
  if (err instanceof Anthropic.APIError) return `Claude returned an error (${err.status}): ${err.message}`;
  return err.message || String(err);
}

// ---------- Claude ----------

async function claudeJSON(client, { system, content, schema, maxTokens = 32000 }) {
  const stream = client.beta.messages.stream({
    model: 'claude-opus-5-5',
    max_tokens: maxTokens,
    system,
    messages: [{ role: 'user', content }],
    output_config: { effort: 'medium', format: { type: 'json_schema', schema } },
    // If a safety check declines, the API retries on a fallback model automatically.
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
  });
  const message = await stream.finalMessage();
  if (message.stop_reason === 'refusal') throw new Error('Claude declined to process this material.');
  if (message.stop_reason === 'max_tokens') throw new Error('The answer was too long and got cut off. Try fewer techniques or shorter material.');
  const text = message.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  return parseJSON(text);
}

async function runClaude({ apiKey, material, pdfBase64, techniqueIds, onProgress }) {
  const client = new Anthropic({ apiKey, timeout: 15 * 60 * 1000 });
  const source = !material.trim() && pdfBase64
    ? { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 } }
    : { type: 'text', text: `<material>\n${material}\n</material>` };

  const techniques = techniqueIds.map(P.byId).filter(Boolean);
  const batches = [];
  for (let i = 0; i < techniques.length; i += 4) batches.push(techniques.slice(i, i + 4));
  const total = batches.length + 1;
  let done = 0;
  const warnings = [];
  const tick = () => { done += 1; onProgress(done / total, `Claude is writing your memory aids… (${done} of ${total} parts done)`); };
  onProgress(0, 'Claude is writing your memory aids…');

  const aidJobs = batches.map(async (batch) => {
    const prompt = 'Create one learning aid for each of these techniques, in this order:\n\n' + batch.map(P.techniqueBlock).join('\n\n');
    try {
      const out = await claudeJSON(client, { system: `${P.SYSTEM}\n${P.SVG_RULE}`, content: [source, { type: 'text', text: prompt }], schema: P.AIDS_SCHEMA });
      return (out.aids || []).map((a) => newAid(a));
    } catch (err) {
      warnings.push(`${batch.map((t) => t.name).join(', ')}: ${friendlyClaudeError(err)}`);
      return [];
    } finally { tick(); }
  });

  const cardJob = (async () => {
    try {
      return await claudeJSON(client, { system: P.SYSTEM, content: [source, { type: 'text', text: P.CARDS_PROMPT }], schema: P.CARDS_SCHEMA, maxTokens: 16000 });
    } catch (err) {
      warnings.push(`Flashcards: ${friendlyClaudeError(err)}`);
      return null;
    } finally { tick(); }
  })();

  const aids = (await Promise.all(aidJobs)).flat().sort((a, b) => a.techniqueId - b.techniqueId);
  const cards = await cardJob;
  if (!aids.length && !cards) throw new Error(warnings[0] || 'Nothing was generated.');
  return {
    title: cards?.title || 'Study set',
    aids,
    cards: (cards?.cards || []).map(newCard),
    warnings,
  };
}

// ---------- Ollama (free, runs on this PC) ----------

async function ollamaStatus(model) {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/tags`);
    if (!res.ok) return { running: false, hasModel: false };
    const data = await res.json();
    const names = (data.models || []).map((m) => m.name);
    const hasModel = names.some((n) => n === model || n === `${model}:latest` || n.split(':')[0] === model);
    return { running: true, hasModel, models: names };
  } catch {
    return { running: false, hasModel: false };
  }
}

async function ollamaPull(model, onProgress) {
  const res = await fetch(`${OLLAMA_URL}/api/pull`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ model, stream: true }),
  });
  if (!res.ok || !res.body) throw new Error(`Ollama couldn't download ${model} (${res.status}).`);
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      const msg = JSON.parse(line);
      if (msg.error) throw new Error(msg.error);
      const pct = msg.total ? msg.completed / msg.total : null;
      onProgress(pct, msg.status || '');
    }
  }
}

async function ollamaJSON(model, { system, prompt, schema }) {
  const res = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model, stream: false, format: schema,
      options: { num_ctx: 8192, temperature: 0.7 },
      messages: [{ role: 'system', content: system }, { role: 'user', content: prompt }],
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Ollama error (${res.status}): ${body.slice(0, 200)}`);
  }
  const data = await res.json();
  return parseJSON(data.message?.content || '');
}

function splitText(text, size) {
  const chunks = [];
  let current = '';
  for (const para of text.split('\n')) {
    if (current.length + para.length > size && current) { chunks.push(current); current = ''; }
    if (para.length > size) {
      for (let i = 0; i < para.length; i += size) chunks.push(para.slice(i, i + size));
    } else current += para + '\n';
  }
  if (current.trim()) chunks.push(current);
  return chunks;
}

async function runOllama({ model, material, techniqueIds, onProgress }) {
  const status = await ollamaStatus(model);
  if (!status.running) throw new Error('The free AI helper (Ollama) isn\'t running. Install it from ollama.com, or open it from the Start menu, then try again. See Settings for help.');
  if (!status.hasModel) throw new Error(`The AI model "${model}" isn't downloaded yet. Open Settings and click "Download AI model".`);

  const text = material.trim();
  if (!text) throw new Error('No text found. If your PDF is a scan (photos of pages), add a Claude API key in Settings, which can read scanned PDFs.');

  const techniques = techniqueIds.map(P.byId).filter(Boolean);
  const total = techniques.length + 2;
  const warnings = [];

  // Long material is condensed into key facts first so it fits the small model.
  let facts = text;
  if (text.length > 12000) {
    const chunks = splitText(text, 10000);
    const all = [];
    for (let i = 0; i < chunks.length; i += 1) {
      onProgress(0.5 / total, `Reading your material (part ${i + 1} of ${chunks.length})…`);
      const out = await ollamaJSON(model, {
        system: 'You extract the key facts a student must memorise from study material. Keep facts accurate and precise.',
        prompt: `List the key facts (at most 15) in this part of the material:\n\n${chunks[i]}`,
        schema: P.FACTS_SCHEMA,
      });
      all.push(...(out.facts || []));
    }
    facts = all.map((f) => `- ${f}`).join('\n').slice(0, 12000);
  }
  onProgress(1 / total, 'Starting…');

  const aids = [];
  for (let i = 0; i < techniques.length; i += 1) {
    const t = techniques[i];
    onProgress((i + 1) / total, `Creating ${t.name} (${i + 1} of ${techniques.length})…`);
    try {
      const out = await ollamaJSON(model, {
        system: P.SYSTEM,
        prompt: `Material:\n${facts}\n\nCreate one memory aid for the material using this technique.\n${P.techniqueBlock(t)}`,
        schema: P.SINGLE_AID_SCHEMA,
      });
      aids.push(newAid(out, t.id));
    } catch (err) {
      warnings.push(`${t.name}: ${err.message}`);
    }
  }

  onProgress((total - 1) / total, 'Writing flashcards…');
  let cards = null;
  try {
    cards = await ollamaJSON(model, { system: P.SYSTEM, prompt: `Material:\n${facts}\n\n${P.CARDS_PROMPT}`, schema: P.CARDS_SCHEMA });
  } catch (err) {
    warnings.push(`Flashcards: ${err.message}`);
  }
  onProgress(1, 'Done');
  if (!aids.length && !cards) throw new Error(warnings[0] || 'Nothing was generated.');
  return { title: cards?.title || 'Study set', aids, cards: (cards?.cards || []).map(newCard), warnings };
}

module.exports = { runClaude, runOllama, ollamaStatus, ollamaPull };
