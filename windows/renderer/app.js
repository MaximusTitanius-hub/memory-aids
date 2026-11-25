/* Memory Aids for Windows: the window's user interface. */
'use strict';

const api = window.api;
const state = {
  techniques: [], starterPack: [], sets: [], view: 'new', setId: null,
  draft: { material: '', pdfBase64: null, fileName: null, chosen: null },
  running: false, progress: 0, status: '', error: '', warnings: [],
  setTab: 'aids', filter: null,
  study: null,
};

// ---------- tiny DOM helper ----------
function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === null || v === undefined || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'html') continue; // never set raw HTML
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}
const svgNS = 'http://www.w3.org/2000/svg';
function s(tag, attrs = {}, ...children) {
  const el = document.createElementNS(svgNS, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  for (const c of children.flat()) if (c != null) el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  return el;
}
const COLOURS = ['red', 'orange', 'yellow', 'green', 'teal', 'blue', 'purple', 'pink', 'brown', 'gray'];
const colour = (name) => (COLOURS.includes((name || '').toLowerCase()) ? `var(--${name.toLowerCase()})` : 'var(--accent)');
const tech = (id) => state.techniques.find((t) => t.id === id);

// ---------- persistence ----------
async function saveSets() { await api.saveSets(state.sets); }
const dueCards = (set) => set.cards.filter((c) => c.due <= Date.now());
const totalDue = () => state.sets.reduce((n, set) => n + dueCards(set).length, 0);

// ---------- spaced repetition ----------
const INTERVALS = [1, 2, 4, 8, 16, 32, 64]; // days
const DAY = 86400000;
function reviewed(card, grade) {
  const c = { ...card, reviews: card.reviews + 1 };
  const now = Date.now();
  if (grade === 'again') { c.box = 0; c.due = now + 10 * 60000; }
  else if (grade === 'hard') { c.due = now + Math.max(1, INTERVALS[c.box] / 2) * DAY; }
  else if (grade === 'good') { c.box = Math.min(c.box + 1, INTERVALS.length - 1); c.due = now + INTERVALS[c.box] * DAY; }
  else { c.box = Math.min(c.box + 2, INTERVALS.length - 1); c.due = now + INTERVALS[c.box] * DAY; }
  return c;
}
function nextLabel(card, grade) {
  const ms = reviewed(card, grade).due - Date.now();
  if (ms < 3600000) return 'in 10 min';
  const d = Math.round(ms / DAY);
  return d === 1 ? 'in 1 day' : `in ${d} days`;
}

// ---------- navigation ----------
function go(view, setId = null) {
  state.view = view; state.setId = setId;
  if (view === 'set') { state.setTab = 'aids'; state.filter = null; }
  if (view === 'study' || view === 'set') state.study = null;
  render();
}

function renderSidebar() {
  document.querySelectorAll('.nav').forEach((b) => {
    b.classList.toggle('active', b.dataset.view === state.view);
  });
  const badge = document.getElementById('due-badge');
  const due = totalDue();
  badge.hidden = due === 0;
  badge.textContent = due;
  const list = document.getElementById('set-list');
  list.replaceChildren(...state.sets.map((set) => h('button', {
    class: `set-link ${state.view === 'set' && state.setId === set.id ? 'active' : ''}`,
    onclick: () => go('set', set.id),
    oncontextmenu: (e) => { e.preventDefault(); deleteSet(set); },
    title: 'Right-click to delete',
  }, h('span', {}, set.title), h('small', {}, `${set.aids.length} aids · ${set.cards.length} cards`))));
  if (!state.sets.length) list.append(h('p', { class: 'muted', style: { padding: '0 10px', fontSize: '13px' } }, 'Your study sets will appear here.'));
}

async function deleteSet(set) {
  if (!window.confirm(`Delete "${set.title}"? This can't be undone.`)) return;
  state.sets = state.sets.filter((x) => x.id !== set.id);
  await saveSets();
  go('new');
}

function render() {
  renderSidebar();
  const main = document.getElementById('main');
  let page;
  if (state.view === 'settings') page = settingsPage();
  else if (state.view === 'study') page = studyPage(null);
  else if (state.view === 'set' && state.sets.find((x) => x.id === state.setId)) page = setPage();
  else page = newPage();
  main.replaceChildren(page);
}

// ---------- New study set ----------
function newPage() {
  const d = state.draft;
  if (!d.chosen) d.chosen = new Set(state.starterPack);

  const text = h('textarea', {
    placeholder: d.pdfBase64 && !d.material
      ? 'This PDF has no selectable text (it may be a scan). Claude can still read it if you add an API key in Settings.'
      : 'Paste notes here, or drag a PDF onto this box…',
    oninput: (e) => { d.material = e.target.value; refreshCreate(); },
    ondragover: (e) => { e.preventDefault(); e.target.classList.add('drop'); },
    ondragleave: (e) => e.target.classList.remove('drop'),
    ondrop: async (e) => {
      e.preventDefault(); e.target.classList.remove('drop');
      const file = e.dataTransfer.files[0];
      if (file) await loadFile(() => api.importDropped(file));
    },
  });
  text.value = d.material;

  const words = d.material.trim() ? d.material.trim().split(/\s+/).length : 0;

  const grid = h('div', { class: 'tech-grid' }, state.techniques.map((t) => {
    const on = d.chosen.has(t.id);
    return h('button', {
      class: `tech ${on ? 'on' : ''}`,
      onclick: () => { if (on) d.chosen.delete(t.id); else d.chosen.add(t.id); render(); },
    }, h('span', { class: 'ico' }, t.icon), h('span', {}, h('b', {}, `${t.id}. ${t.name}`), h('small', {}, t.summary)), h('span', { class: 'tick' }, on ? '✔' : '○'));
  }));

  const createBtn = h('button', { class: 'btn primary', id: 'create', onclick: generate }, '✨ Create memory aids');
  const engineLabel = h('span', { class: 'muted' }, '');
  api.resolveEngine().then((e) => { engineLabel.textContent = `Using: ${e === 'claude' ? 'Claude' : 'free AI on this PC (Ollama)'}`; });

  const page = h('div', { class: 'page' },
    h('h1', {}, 'What do you need to remember?'),
    h('p', { class: 'muted' }, 'Paste or type your notes, or add a PDF. Then pick the memory techniques you want.'),
    h('h2', {}, '1. Your material', h('span', { class: 'spacer' }),
      d.fileName ? h('span', { class: 'muted', style: { fontSize: '14px', fontWeight: 400 } }, `📄 ${d.fileName}`) : null,
      h('button', { class: 'btn', onclick: () => loadFile(() => api.openFile()) }, 'Import PDF…'),
      (d.material || d.pdfBase64) ? h('button', { class: 'btn', onclick: () => { Object.assign(d, { material: '', pdfBase64: null, fileName: null }); render(); } }, 'Clear') : null),
    text,
    words ? h('small', { class: 'muted' }, `${words} words`) : null,
    h('h2', {}, '2. Memory techniques', h('span', { class: 'muted', style: { fontSize: '14px', fontWeight: 400 } }, `${d.chosen.size} chosen`), h('span', { class: 'spacer' }),
      h('button', { class: 'btn small', onclick: () => { d.chosen = new Set(state.starterPack); render(); } }, 'Starter pack'),
      h('button', { class: 'btn small', onclick: () => { d.chosen = new Set(state.techniques.map((t) => t.id)); render(); } }, 'All 20'),
      h('button', { class: 'btn small', onclick: () => { d.chosen = new Set(); render(); } }, 'None')),
    grid,
    h('h2', {}, '3. Create'),
    h('div', { class: 'row' }, createBtn, engineLabel, h('button', { class: 'btn small', onclick: () => go('settings') }, 'Change…')),
    state.running ? h('div', {},
      h('div', { class: 'progress' }, h('div', { id: 'bar', style: { width: `${Math.round(state.progress * 100)}%` } })),
      h('div', { class: 'muted', id: 'status' }, state.status),
      h('small', { class: 'muted' }, 'This can take a few minutes.')) : null,
    state.error ? h('p', { class: 'error' }, `⚠️ ${state.error}`) : null,
  );
  setTimeout(refreshCreate);
  return page;
}

function refreshCreate() {
  const btn = document.getElementById('create');
  if (!btn) return;
  const d = state.draft;
  btn.disabled = state.running || !d.chosen.size || (!d.material.trim() && !d.pdfBase64);
}

async function loadFile(getter) {
  state.error = '';
  try {
    const file = await getter();
    if (!file) return;
    Object.assign(state.draft, { material: file.text || '', pdfBase64: file.pdfBase64, fileName: file.name });
  } catch (err) {
    state.error = `Couldn't open that file: ${err.message}`;
  }
  render();
}

async function generate() {
  const d = state.draft;
  Object.assign(state, { running: true, progress: 0, status: 'Starting…', error: '' });
  render();
  const off = api.onProgress(({ pct, status }) => {
    state.progress = pct; state.status = status;
    const bar = document.getElementById('bar'); const st = document.getElementById('status');
    if (bar) bar.style.width = `${Math.round(pct * 100)}%`;
    if (st) st.textContent = status;
  });
  try {
    const result = await api.generate({ material: d.material, pdfBase64: d.pdfBase64, techniqueIds: [...d.chosen].sort((a, b) => a - b) });
    const set = {
      id: crypto.randomUUID(), title: result.title, createdAt: Date.now(),
      sourceText: d.material || '(PDF sent directly to Claude)', aids: result.aids, cards: result.cards,
      warnings: result.warnings || [],
    };
    state.sets.unshift(set);
    await saveSets();
    Object.assign(d, { material: '', pdfBase64: null, fileName: null });
    state.running = false;
    go('set', set.id);
  } catch (err) {
    state.running = false;
    state.error = err.message;
    render();
  } finally { off(); }
}

// ---------- A study set ----------
function setPage() {
  const set = state.sets.find((x) => x.id === state.setId);
  const tabs = [['aids', 'Memory aids'], ['cards', 'Flashcards'], ['study', 'Study'], ['source', 'Original notes']];
  let body;
  if (state.setTab === 'cards') body = h('div', { class: 'flip-grid' }, set.cards.map(flipCard));
  else if (state.setTab === 'study') body = studyPage(set.id, true);
  else if (state.setTab === 'source') body = h('p', { style: { whiteSpace: 'pre-wrap', userSelect: 'text' } }, set.sourceText);
  else {
    const shown = set.aids.filter((a) => state.filter === null || a.techniqueId === state.filter);
    body = h('div', {},
      h('div', { class: 'chips' },
        h('button', { class: `chip ${state.filter === null ? 'on' : ''}`, onclick: () => { state.filter = null; render(); } }, 'All'),
        set.aids.map((a) => h('button', { class: `chip ${state.filter === a.techniqueId ? 'on' : ''}`, onclick: () => { state.filter = a.techniqueId; render(); } }, tech(a.techniqueId)?.name || '?'))),
      shown.map(aidCard),
      set.aids.length ? null : h('p', { class: 'muted' }, 'No aids were created for this set.'));
  }
  return h('div', { class: 'page' },
    h('div', { class: 'row' },
      h('div', {}, h('h1', {}, set.title), h('div', { class: 'muted' }, `${set.aids.length} memory aids · ${set.cards.length} flashcards · ${dueCards(set).length} due for review`)),
      h('span', { class: 'spacer' }),
      h('div', { class: 'tabs' }, tabs.map(([k, label]) => h('button', { class: state.setTab === k ? 'on' : '', onclick: () => { state.setTab = k; state.study = null; render(); } }, label))),
      h('button', { class: 'btn small', onclick: () => deleteSet(set), title: 'Delete this study set' }, '🗑')),
    (set.warnings && set.warnings.length && state.setTab === 'aids') ? h('div', { class: 'notice' }, `Some parts didn't work: ${set.warnings.join(' · ')}`) : null,
    h('div', { style: { marginTop: '18px' } }, body));
}

function flipCard(card) {
  let back = false;
  const el = h('div', { class: 'flip' });
  const draw = () => {
    el.className = `flip ${back ? 'back' : ''}`;
    el.replaceChildren(
      h('small', {}, back ? 'ANSWER' : 'QUESTION'),
      h('p', {}, back ? card.answer : card.question),
      back && card.hint ? h('div', { class: 'hint' }, `💡 ${card.hint}`) : null,
      h('small', { style: { fontWeight: 400 } }, back ? 'Click to hide' : 'Click to reveal'));
  };
  el.addEventListener('click', () => { back = !back; draw(); });
  draw();
  return el;
}

function speak(text) {
  if (speechSynthesis.speaking) { speechSynthesis.cancel(); return; }
  speechSynthesis.speak(new SpeechSynthesisUtterance(text));
}

function aidCard(aid) {
  const t = tech(aid.techniqueId);
  const svgImg = aid.svg && aid.svg.includes('<svg')
    ? h('img', { class: 'illus', alt: aid.title, src: `data:image/svg+xml;base64,${btoa(unescape(encodeURIComponent(aid.svg)))}` })
    : null;
  return h('article', { class: 'aid' },
    h('div', { class: 'aid-head' },
      h('div', { class: 'ico' }, t?.icon || '✨'),
      h('div', {}, h('small', {}, t ? `${t.id}. ${t.name}` : 'Technique'), h('h3', {}, aid.title)),
      h('span', { class: 'spacer' }),
      h('button', { class: 'btn small', onclick: () => speak([aid.title, aid.scene, ...aid.items.map((i) => `${i.label}. ${i.detail}`)].join('. ')) }, '🔊 Read aloud')),
    aid.explanation ? h('p', { class: 'muted' }, aid.explanation) : null,
    svgImg,
    aid.scene ? h('div', { class: 'scene' }, `${t?.id === 14 ? '🎵' : '👁'}  ${aid.scene}`) : null,
    visual(aid, t?.layout || 'list'));
}

// ---------- technique drawings ----------
function grouped(items) {
  const map = new Map();
  for (const item of items) {
    const key = item.group || item.label;
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }
  return [...map.entries()].map(([name, list]) => ({ name, items: list }));
}

function visual(aid, layout) {
  const items = aid.items || [];
  switch (layout) {
    case 'mindMap': return mindMap(aid.title, items);
    case 'triangle': return h('div', {}, aid.triangle && (aid.triangle.top || aid.triangle.left) ? triangle(aid.triangle) : null, itemList(items));
    case 'colourCode': return h('div', {}, grouped(items).map((g) => h('div', { class: 'colour-group' },
      h('b', {}, h('span', { class: 'dot', style: { display: 'inline-block', background: colour(g.items[0].color), marginRight: '8px', width: '16px', height: '16px', borderRadius: '4px' } }), g.name),
      h('div', { class: 'swatches' }, g.items.map((i) => h('div', { class: 'swatch', style: { background: colour(i.color) } }, h('b', {}, i.label), h('small', {}, i.detail)))))));
    case 'palace': {
      const icons = ['🚪', '🛋️', '🍳', '📺', '🪜', '🛁', '🛏️', '🌳', '🚗', '🪴'];
      return h('div', { class: 'palace' }, items.map((i, n) => h('div', { class: 'room' },
        h('div', {}, h('span', { class: 'num', style: { background: 'var(--brown)' } }, n + 1), `${icons[n % icons.length]} `, h('b', {}, i.label)),
        h('p', { style: { margin: '6px 0 0' } }, i.detail))));
    }
    case 'story': return h('div', {}, items.map((i, n) => h('div', { class: 'story-step' },
      h('div', { class: 'rail' }, h('span', { class: 'num', style: { background: colour(i.color) } }, n + 1), n < items.length - 1 ? h('div', { class: 'line' }) : null),
      h('div', { class: 'body' }, h('div', {}, i.detail), h('small', { style: { color: colour(i.color), fontWeight: 700 } }, `Remembers: ${i.label}`)))));
    case 'collectibles': {
      const stars = (r) => ({ legendary: 4, epic: 3, rare: 2 }[(r || '').toLowerCase()] || 1);
      return h('div', { class: 'cards' }, items.map((i) => h('div', {
        class: `collect ${stars(i.group) >= 3 ? 'epic' : ''}`,
        style: { background: `linear-gradient(${colour(i.color)}, color-mix(in srgb, ${colour(i.color)} 65%, transparent))` },
      }, h('div', { class: 'top' }, h('span', {}, i.group || 'Common'), h('span', {}, '★'.repeat(stars(i.group)))),
      h('div', { class: 'face', style: { color: colour(i.color) } }, i.label.slice(0, 2)),
      h('b', {}, i.label), h('p', { style: { fontSize: '13px' } }, i.detail))));
    }
    case 'chunks': return h('div', { class: 'chunks' }, grouped(items).map((g, n) => h('div', { class: 'chunk', style: { borderColor: colour(g.items[0].color), background: `color-mix(in srgb, ${colour(g.items[0].color)} 10%, transparent)` } },
      h('b', { style: { color: colour(g.items[0].color) } }, `Chunk ${n + 1}: ${g.name}`),
      g.items.map((i) => h('div', { style: { marginTop: '6px' } }, h('b', {}, `• ${i.label}`), i.detail ? h('div', { class: 'muted', style: { fontSize: '13px' } }, i.detail) : null)))));
    case 'acronym': return h('div', {},
      h('div', { class: 'letters' }, items.map((i, n) => h('div', { class: 'letter', style: { background: colour(COLOURS[n % COLOURS.length]) } }, (i.label[0] || '').toUpperCase()))),
      items.map((i, n) => h('div', {}, h('b', { style: { color: colour(COLOURS[n % COLOURS.length]) } }, i.label), h('span', { class: 'muted' }, `  →  ${i.detail}`))));
    default: return itemList(items);
  }
}

function itemList(items) {
  return h('div', { class: 'items' }, items.map((i) => h('div', { class: 'item' },
    h('span', { class: 'dot', style: { background: colour(i.color) } }),
    h('div', {}, h('b', {}, i.label, i.group ? h('span', { class: 'tag', style: { background: `color-mix(in srgb, ${colour(i.color)} 22%, transparent)` } }, i.group) : null),
      h('div', { class: 'muted' }, i.detail)))));
}

function wrapText(text, max) {
  const words = String(text).split(/\s+/); const lines = []; let line = '';
  for (const w of words) {
    if ((line + ' ' + w).trim().length > max && line) { lines.push(line); line = w; } else line = (line + ' ' + w).trim();
  }
  if (line) lines.push(line);
  return lines.slice(0, 3);
}
function svgLabel(x, y, text, max, attrs) {
  const lines = wrapText(text, max);
  const start = y - ((lines.length - 1) * 15) / 2;
  return s('text', { x, 'text-anchor': 'middle', 'dominant-baseline': 'middle', ...attrs },
    lines.map((l, n) => s('tspan', { x, y: start + n * 15 }, l)));
}

function mindMap(center, items) {
  const W = 960; const H = 600; const cx = W / 2; const cy = H / 2;
  const branches = grouped(items); const n = Math.max(branches.length, 1);
  const svg = s('svg', { viewBox: `0 0 ${W} ${H}`, class: 'mindmap', 'font-family': 'Segoe UI, sans-serif' });
  const nodes = [];
  branches.forEach((b, i) => {
    const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
    const bx = cx + Math.cos(angle) * 210; const by = cy + Math.sin(angle) * 150;
    const col = colour(b.items[0].color);
    svg.append(s('path', { d: `M${cx},${cy} Q${(cx + bx) / 2},${by} ${bx},${by}`, stroke: 'var(--muted)', 'stroke-width': 5, fill: 'none', 'stroke-linecap': 'round', opacity: 0.5 }));
    const spread = ((Math.PI * 2) / n) * 0.75;
    b.items.forEach((it, j) => {
      const count = b.items.length;
      const a = count <= 1 ? angle : angle - spread / 2 + (spread * j) / (count - 1);
      const lx = cx + Math.cos(a) * 390; const ly = cy + Math.sin(a) * 255;
      svg.append(s('line', { x1: bx, y1: by, x2: lx, y2: ly, stroke: col, 'stroke-width': 2, opacity: 0.7 }));
      nodes.push(() => {
        const g = s('g', {}, s('title', {}, it.detail));
        g.append(s('rect', { x: lx - 72, y: ly - 24, width: 144, height: 48, rx: 9, fill: 'var(--panel)', stroke: col, 'stroke-width': 1.5 }));
        g.append(svgLabel(lx, ly, it.label, 20, { 'font-size': 12, fill: 'var(--text)' }));
        return g;
      });
    });
    nodes.push(() => s('g', {}, s('rect', { x: bx - 82, y: by - 20, width: 164, height: 40, rx: 20, fill: col }), svgLabel(bx, by, b.name, 22, { 'font-size': 14, 'font-weight': 700, fill: '#fff' })));
  });
  nodes.forEach((f) => svg.append(f()));
  svg.append(s('circle', { cx, cy, r: 78, fill: 'var(--panel)' }));
  svg.append(s('circle', { cx, cy, r: 78, fill: 'var(--accent)', opacity: 0.18, stroke: 'var(--accent)', 'stroke-width': 2 }));
  svg.append(svgLabel(cx, cy, center, 16, { 'font-size': 16, 'font-weight': 700, fill: 'var(--text)' }));
  return svg;
}

function triangle(t) {
  const svg = s('svg', { viewBox: '0 0 320 270', width: 320, height: 270, 'font-family': 'Segoe UI, sans-serif' },
    s('defs', {}, s('linearGradient', { id: 'tg', x1: 0, y1: 0, x2: 0, y2: 1 }, s('stop', { offset: 0, 'stop-color': '#f39c12', 'stop-opacity': 0.4 }), s('stop', { offset: 1, 'stop-color': '#e84393', 'stop-opacity': 0.4 }))),
    s('polygon', { points: '160,8 312,262 8,262', fill: 'url(#tg)', stroke: 'var(--text)', 'stroke-width': 3, 'stroke-linejoin': 'round' }),
    s('line', { x1: 84, y1: 135, x2: 236, y2: 135, stroke: 'var(--text)', 'stroke-width': 3 }),
    s('line', { x1: 160, y1: 135, x2: 160, y2: 262, stroke: 'var(--text)', 'stroke-width': 3 }),
    svgLabel(160, 92, t.top, 10, { 'font-size': 26, 'font-weight': 800, fill: 'var(--text)' }),
    svgLabel(100, 205, t.left, 8, { 'font-size': 24, 'font-weight': 800, fill: 'var(--text)' }),
    svgLabel(220, 205, t.right, 8, { 'font-size': 24, 'font-weight': 800, fill: 'var(--text)' }));
  return h('div', { class: 'triangle-wrap' }, svg, h('div', { class: 'formulas' },
    h('div', { style: { fontWeight: 700 } }, `${t.top} = ${t.left} × ${t.right}`),
    h('div', {}, `${t.left} = ${t.top} ÷ ${t.right}`),
    h('div', {}, `${t.right} = ${t.top} ÷ ${t.left}`),
    t.rule ? h('p', { class: 'muted' }, t.rule) : null));
}

// ---------- Study (active recall + spaced repetition) ----------
function startStudy(setId, all = false) {
  const queue = [];
  for (const set of state.sets) {
    if (setId && set.id !== setId) continue;
    for (const c of set.cards) if (all || c.due <= Date.now()) queue.push({ setId: set.id, cardId: c.id });
  }
  queue.sort(() => Math.random() - 0.5);
  state.study = { setId, queue, done: 0, revealed: false, attempt: '', started: queue.length > 0 };
}

function studyPage(setId, embedded = false) {
  if (!state.study || state.study.setId !== setId) startStudy(setId);
  const st = state.study;
  const wrap = (...kids) => (embedded ? h('div', {}, ...kids) : h('div', { class: 'page' }, ...kids));
  const first = st.queue[0];
  const set = first && state.sets.find((x) => x.id === first.setId);
  const card = set && set.cards.find((c) => c.id === first.cardId);

  if (card) {
    const attempt = h('textarea', { placeholder: 'Type your answer from memory…', oninput: (e) => { st.attempt = e.target.value; } });
    attempt.value = st.attempt;
    return wrap(
      h('div', { class: 'row', style: { maxWidth: '760px', marginBottom: '14px' } }, h('h2', { style: { margin: 0 } }, 'Recall from memory'), h('span', { class: 'spacer' }), h('span', { class: 'muted' }, `${st.done} done · ${st.queue.length} to go`)),
      h('div', { class: 'study-card' },
        setId ? null : h('small', { class: 'muted', style: { fontWeight: 700, textTransform: 'uppercase' } }, set.title),
        h('div', { class: 'q' }, card.question),
        h('p', { class: 'muted' }, 'Type or say your answer before revealing. Trying to remember is what makes it stick.'),
        attempt,
        st.revealed
          ? h('div', {},
            h('div', { class: 'answer' }, h('small', { class: 'muted' }, 'Answer'), h('div', { style: { fontSize: '19px', fontWeight: 700 } }, card.answer), card.hint ? h('div', { class: 'hint' }, `💡 ${card.hint}`) : null),
            h('b', {}, 'How well did you remember it?'),
            h('div', { class: 'grades', style: { marginTop: '8px' } }, [['again', 'Forgot', 'var(--red)'], ['hard', 'Hard', 'var(--orange)'], ['good', 'Good', 'var(--green)'], ['easy', 'Easy', 'var(--blue)']].map(([g, label, col]) => h('button', {
              style: { borderColor: col },
              onclick: async () => {
                set.cards = set.cards.map((c) => (c.id === card.id ? reviewed(c, g) : c));
                await saveSets();
                const item = st.queue.shift();
                if (g === 'again') st.queue.push(item);
                Object.assign(st, { done: st.done + 1, revealed: false, attempt: '' });
                render();
              },
            }, h('b', { style: { color: col } }, label), h('small', {}, nextLabel(card, g))))))
          : h('div', { class: 'row', style: { marginTop: '12px' } }, h('span', { class: 'spacer' }), h('button', { class: 'btn primary', onclick: () => { st.revealed = true; render(); } }, 'Show answer'))));
  }

  if (st.started) {
    return wrap(h('div', { class: 'center' }, h('div', { class: 'big' }, '🎉'), h('h1', {}, 'Session complete'),
      h('p', { class: 'muted' }, `You reviewed ${st.done} cards. They'll come back at growing intervals so they stick.`),
      h('button', { class: 'btn', onclick: () => { state.study = null; st.started = false; startStudy(setId); state.study.started = false; render(); } }, 'Done')));
  }

  const pool = state.sets.filter((x) => !setId || x.id === setId).flatMap((x) => x.cards);
  const next = pool.map((c) => c.due).sort((a, b) => a - b)[0];
  const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' });
  let nextText = 'Create a study set to get flashcards.';
  if (next) {
    const hours = (next - Date.now()) / 3600000;
    nextText = `Your next review is ${hours < 24 ? rtf.format(Math.max(1, Math.round(hours)), 'hour') : rtf.format(Math.round(hours / 24), 'day')}.`;
  }
  return wrap(h('div', { class: 'center' }, h('div', { class: 'big' }, '✅'), h('h1', {}, 'Nothing due right now'), h('p', { class: 'muted' }, nextText),
    h('button', { class: 'btn', disabled: pool.length ? null : true, onclick: () => { startStudy(setId, true); render(); } }, 'Practise all cards anyway')));
}

// ---------- Settings ----------
function settingsPage() {
  const page = h('div', { class: 'page settings' }, h('h1', {}, 'Settings'), h('p', { class: 'muted' }, 'Loading…'));
  (async () => {
    const st = await api.getSettings();
    const ollama = await api.ollamaStatus();
    const radio = (value, title, desc) => h('label', { class: 'radio' },
      h('input', { type: 'radio', name: 'engine', value, checked: st.engine === value ? true : null, onchange: async () => { await api.setSettings({ engine: value }); } }),
      h('span', {}, h('b', {}, title), h('br'), h('small', { class: 'muted' }, desc)));

    const keyInput = h('input', { type: 'password', placeholder: st.hasKey ? 'A key is saved. Paste a new one to replace it.' : 'sk-ant-…' });
    const keyStatus = h('span', { class: st.hasKey ? 'status-ok' : 'muted' }, st.hasKey ? 'Key saved' : 'No key saved');
    const modelInput = h('input', { type: 'text', value: st.ollamaModel, style: { maxWidth: '260px' } });
    const pullStatus = h('span', { class: 'muted' });
    const pullBar = h('div', { class: 'progress', hidden: true }, h('div'));

    const ollamaLine = !ollama.running
      ? h('p', { class: 'status-bad' }, '✖ Ollama is not running or not installed yet.')
      : ollama.hasModel
        ? h('p', { class: 'status-ok' }, `✔ Ready. Ollama is running and "${st.ollamaModel}" is downloaded.`)
        : h('p', { class: 'status-bad' }, `Ollama is running, but the AI model "${st.ollamaModel}" isn't downloaded yet. Click "Download AI model" below.`);

    page.replaceChildren(
      h('h1', {}, 'Settings'),
      h('section', {}, h('h2', { style: { marginTop: 0 } }, 'Which AI creates your memory aids'),
        radio('auto', 'Automatic', 'Uses Claude if you have saved a key below, otherwise the free AI on this PC.'),
        radio('ollama', 'Free AI on this PC (Ollama)', 'Free and works offline. Needs Ollama installed and about 3 GB of disk space.'),
        radio('claude', 'Claude', 'Richer aids, a drawn picture for each one, and it can read scanned PDFs. Needs an API key.')),
      h('section', {}, h('h2', { style: { marginTop: 0 } }, 'Free AI on this PC (Ollama)'),
        ollamaLine,
        h('ol', { class: 'steps' },
          h('li', {}, 'Install Ollama: ', h('a', { href: 'https://ollama.com/download/windows', target: '_blank' }, 'ollama.com/download/windows'), '. Run the installer and keep clicking Next.'),
          h('li', {}, 'Come back here and click ', h('b', {}, 'Download AI model'), ' (about 3 GB, one time only).'),
          h('li', {}, 'That\'s it. Ollama starts by itself when Windows starts.')),
        h('div', { class: 'row' },
          h('button', {
            class: 'btn', disabled: ollama.running ? null : true,
            onclick: async (e) => {
              e.target.disabled = true; pullBar.hidden = false; pullStatus.textContent = 'Starting download…';
              const off = api.onPullProgress(({ pct, status }) => {
                pullStatus.textContent = pct != null ? `${status} ${Math.round(pct * 100)}%` : status;
                if (pct != null) pullBar.firstChild.style.width = `${Math.round(pct * 100)}%`;
              });
              try { await api.ollamaPull(); pullStatus.textContent = 'Downloaded. You are ready to go!'; pullStatus.className = 'status-ok'; } catch (err) { pullStatus.textContent = err.message; pullStatus.className = 'status-bad'; } finally { off(); e.target.disabled = false; }
            },
          }, '⬇ Download AI model'),
          h('button', { class: 'btn', onclick: () => render() }, 'Check again'),
          pullStatus),
        pullBar,
        h('details', {}, h('summary', { class: 'muted' }, 'Advanced: choose a different model'),
          h('p', { class: 'muted' }, 'gemma3:4b suits most PCs. If your PC has 16 GB of memory or more, try qwen3:8b for better results.'),
          h('div', { class: 'row' }, modelInput, h('button', { class: 'btn', onclick: async () => { await api.setSettings({ ollamaModel: modelInput.value.trim() || 'gemma3:4b' }); render(); } }, 'Save model')))),
      h('section', {}, h('h2', { style: { marginTop: 0 } }, 'Claude API key (optional)'),
        keyInput,
        h('div', { class: 'row', style: { marginTop: '8px' } },
          h('button', { class: 'btn', onclick: async () => { const ok = await api.saveKey(keyInput.value); keyInput.value = ''; keyStatus.textContent = ok ? 'Key saved' : 'No key saved'; keyStatus.className = ok ? 'status-ok' : 'muted'; } }, 'Save key'),
          h('button', { class: 'btn', onclick: async () => { await api.saveKey(''); keyStatus.textContent = 'Key removed'; keyStatus.className = 'muted'; } }, 'Remove key'),
          keyStatus),
        h('p', { class: 'muted' }, 'Get a key at ', h('a', { href: 'https://console.anthropic.com/settings/keys', target: '_blank' }, 'console.anthropic.com'), ' (pay as you go, usually a few pence per study set). It is stored encrypted on this PC.')));
  })();
  return page;
}

// ---------- start ----------
document.querySelectorAll('.nav').forEach((b) => b.addEventListener('click', () => go(b.dataset.view)));
(async () => {
  const t = await api.techniques();
  state.techniques = t.techniques;
  state.starterPack = t.starterPack;
  state.sets = await api.loadSets();
  render();
})();
